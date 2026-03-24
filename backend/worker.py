# /// script
# requires-python = ">=3.12"
# dependencies = [
#   "asyncpg",
#   "langchain-core",
#   "langchain-openai",
#   "pgvector",
# ]
# ///

"""
Doxia Core - PGMQ Worker
Consumes messages from doc_processing_queue and processes documents.
Implements Pointer-based RAG: stores vectors and storage_ref pointers, NO text content.
"""

import asyncio
import json
import logging
import random
import uuid
from dataclasses import dataclass
from typing import Any, Optional

import asyncpg
from pgvector.asyncpg import Vector

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

EMBEDDING_DIMENSION = 1536
MOCK_CHUNKS_COUNT = 3


@dataclass
class QueueMessage:
    document_id: uuid.UUID
    trace_id: uuid.UUID
    connector_id: uuid.UUID
    organization_id: uuid.UUID
    external_id: str


class MockEmbeddingGenerator:
    """Mock embedding generator that returns random vectors.
    Replace with real OpenAI/Ollama embeddings in production.
    """

    def generate(self, text: str) -> list[float]:
        return [random.uniform(-1, 1) for _ in range(EMBEDDING_DIMENSION)]

    async def generate_async(self, text: str) -> list[float]:
        await asyncio.sleep(0.1)
        return self.generate(text)


class Worker:
    def __init__(self, dsn: str):
        self.dsn = dsn
        self.pool: Optional[asyncpg.Pool] = None
        self.running = False
        self.embedding_generator = MockEmbeddingGenerator()

    async def connect(self) -> None:
        self.pool = await asyncpg.create_pool(self.dsn, min_size=1, max_size=2)
        logger.info("Connected to database")

    async def disconnect(self) -> None:
        if self.pool:
            await self.pool.close()
            logger.info("Disconnected from database")

    async def update_audit_log(
        self,
        document_id: uuid.UUID,
        trace_id: uuid.UUID,
        status: str,
        progress: int,
        message: str,
    ) -> None:
        async with self.pool.acquire() as conn:
            await conn.execute(
                """
                UPDATE audit_logs
                SET status = $1,
                    progress_percentage = $2,
                    message = $3
                WHERE document_id = $4 AND trace_id = $5
                """,
                status,
                progress,
                message,
                document_id,
                trace_id,
            )

    async def read_queue(self) -> Optional[tuple[QueueMessage, int]]:
        async with self.pool.acquire() as conn:
            row = await conn.fetchrow(
                "SELECT * FROM pgmq_read('doc_processing_queue', 1, 1)"
            )
            if not row:
                return None

            payload = row["payload"]
            msg = QueueMessage(
                document_id=uuid.UUID(payload["document_id"]),
                trace_id=uuid.UUID(payload["trace_id"]),
                connector_id=uuid.UUID(payload["connector_id"]),
                organization_id=uuid.UUID(payload["organization_id"]),
                external_id=payload["external_id"],
            )
            return msg, row["msg_id"]

    async def delete_message(self, msg_id: int) -> None:
        async with self.pool.acquire() as conn:
            await conn.execute(
                "SELECT pgmq_delete('doc_processing_queue', $1)",
                msg_id,
            )

    def _build_storage_ref(
        self,
        connector_id: uuid.UUID,
        external_id: str,
        chunk_index: int,
        page: int = 1,
        offset_start: int = 0,
        offset_end: int = 500,
    ) -> dict[str, Any]:
        """Build a storage_ref JSONB pointer per Pointer-based RAG philosophy."""
        return {
            "connector_id": str(connector_id),
            "external_id": external_id,
            "page": page,
            "chunk_index": chunk_index,
            "offset_start": offset_start,
            "offset_end": offset_end,
            "checksum": str(uuid.uuid4()),
        }

    async def _generate_chunks(self, external_id: str) -> list[dict[str, Any]]:
        """Simulate docling-serve returning chunks.
        Returns virtual chunks WITHOUT text content.
        """
        chunks = []
        chunk_size = 500
        for i in range(MOCK_CHUNKS_COUNT):
            chunks.append(
                {
                    "chunk_index": i,
                    "page": 1,
                    "offset_start": i * chunk_size,
                    "offset_end": (i + 1) * chunk_size,
                }
            )
        return chunks

    async def _insert_embeddings(
        self,
        document_id: uuid.UUID,
        organization_id: uuid.UUID,
        connector_id: uuid.UUID,
        external_id: str,
    ) -> int:
        """Generate mock embeddings and insert into document_embeddings.
        Returns the number of embeddings inserted.
        """
        chunks = await self._generate_chunks(external_id)
        inserted = 0

        async with self.pool.acquire() as conn:
            for chunk in chunks:
                embedding = self.embedding_generator.generate(
                    f"chunk {chunk['chunk_index']} of {external_id}"
                )

                storage_ref = self._build_storage_ref(
                    connector_id=connector_id,
                    external_id=external_id,
                    chunk_index=chunk["chunk_index"],
                    page=chunk["page"],
                    offset_start=chunk["offset_start"],
                    offset_end=chunk["offset_end"],
                )

                await conn.execute(
                    """
                    INSERT INTO document_embeddings
                    (document_id, organization_id, embedding, storage_ref)
                    VALUES ($1, $2, $3, $4)
                    """,
                    document_id,
                    organization_id,
                    Vector(embedding),
                    json.dumps(storage_ref),
                )
                inserted += 1

        return inserted

    async def process_message(self, msg: QueueMessage, msg_id: int) -> None:
        logger.info(f"Processing document {msg.document_id} (trace: {msg.trace_id})")

        await self.update_audit_log(
            msg.document_id,
            msg.trace_id,
            "PROCESSING",
            10,
            "Starting document processing",
        )

        await self.update_audit_log(
            msg.document_id,
            msg.trace_id,
            "PROCESSING",
            50,
            "Generating embeddings",
        )

        inserted = await self._insert_embeddings(
            document_id=msg.document_id,
            organization_id=msg.organization_id,
            connector_id=msg.connector_id,
            external_id=msg.external_id,
        )

        logger.info(f"Inserted {inserted} embeddings for document {msg.document_id}")

        await self.update_audit_log(
            msg.document_id,
            msg.trace_id,
            "INDEXED",
            100,
            f"Document indexed successfully with {inserted} chunks",
        )

        await self.delete_message(msg_id)
        logger.info(f"Completed document {msg.document_id}")

    async def run_once(self) -> bool:
        result = await self.read_queue()
        if result:
            msg, msg_id = result
            await self.process_message(msg, msg_id)
            return True
        return False

    async def run(self) -> None:
        await self.connect()
        self.running = True
        logger.info("Worker started - polling queue...")

        while self.running:
            try:
                processed = await self.run_once()
                if not processed:
                    await asyncio.sleep(1)
            except Exception as e:
                logger.error(f"Error processing message: {e}")
                await asyncio.sleep(5)

        await self.disconnect()

    def stop(self) -> None:
        self.running = False


async def main():
    dsn = "postgresql://postgres:postgres@localhost:54322/postgres"
    worker = Worker(dsn)

    try:
        await worker.run()
    except KeyboardInterrupt:
        worker.stop()


if __name__ == "__main__":
    asyncio.run(main())
