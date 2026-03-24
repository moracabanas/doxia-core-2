# /// script
# requires-python = ">=3.12"
# dependencies = [
#   "asyncpg",
# ]
# ///

"""
Doxia Core - PGMQ Worker
Consumes messages from doc_processing_queue and processes documents.
"""

import asyncio
import json
import logging
import uuid
from dataclasses import dataclass
from typing import Optional

import asyncpg

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


@dataclass
class QueueMessage:
    document_id: uuid.UUID
    trace_id: uuid.UUID
    connector_id: uuid.UUID
    organization_id: uuid.UUID
    external_id: str


class Worker:
    def __init__(self, dsn: str):
        self.dsn = dsn
        self.pool: Optional[asyncpg.Pool] = None
        self.running = False

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

    async def process_message(self, msg: QueueMessage, msg_id: int) -> None:
        logger.info(
            f"Processing document {msg.document_id} (trace: {msg.trace_id})"
        )

        await self.update_audit_log(
            msg.document_id,
            msg.trace_id,
            "PROCESSING",
            10,
            "Starting document processing",
        )

        await asyncio.sleep(2)

        await self.update_audit_log(
            msg.document_id,
            msg.trace_id,
            "PROCESSING",
            50,
            "Generating embeddings",
        )

        await asyncio.sleep(1)

        await self.update_audit_log(
            msg.document_id,
            msg.trace_id,
            "INDEXED",
            100,
            "Document indexed successfully",
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
