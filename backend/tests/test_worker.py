# /// script
# requires-python = ">=3.12"
# dependencies = [
#   "asyncpg",
#   "langchain-core",
#   "langchain-openai",
#   "pgvector",
#   "pytest",
#   "pytest-asyncio",
# ]
# ///

"""
Tests for PGMQ Worker
"""

import asyncio
import json
import sys
import uuid
from contextlib import asynccontextmanager
from pathlib import Path
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

sys.path.insert(0, str(Path(__file__).parent.parent))

from worker import MockEmbeddingGenerator, QueueMessage, Worker, MOCK_CHUNKS_COUNT


@pytest.fixture
def sample_message():
    return QueueMessage(
        document_id=uuid.uuid4(),
        trace_id=uuid.uuid4(),
        connector_id=uuid.uuid4(),
        organization_id=uuid.uuid4(),
        external_id="test-doc-001",
    )


@pytest.fixture
def sample_message_with_ids():
    doc_id = uuid.uuid4()
    trace_id = uuid.uuid4()
    connector_id = uuid.uuid4()
    org_id = uuid.uuid4()
    return (
        QueueMessage(
            document_id=doc_id,
            trace_id=trace_id,
            connector_id=connector_id,
            organization_id=org_id,
            external_id="test-doc-002",
        ),
        doc_id,
        trace_id,
        connector_id,
        org_id,
    )


class MockAsyncContextManager:
    def __init__(self, obj):
        self.obj = obj

    async def __aenter__(self):
        return self.obj

    async def __aexit__(self, *args):
        pass


def test_queue_message_dataclass(sample_message):
    assert isinstance(sample_message.document_id, uuid.UUID)
    assert isinstance(sample_message.trace_id, uuid.UUID)
    assert isinstance(sample_message.external_id, str)
    assert sample_message.external_id == "test-doc-001"


def test_worker_initialization():
    dsn = "postgresql://postgres:postgres@localhost:54322/postgres"
    worker = Worker(dsn)
    assert worker.dsn == dsn
    assert worker.pool is None
    assert worker.running is False


def test_worker_stop():
    worker = Worker("postgresql://localhost/test")
    worker.running = True
    worker.stop()
    assert worker.running is False


def test_mock_embedding_generator():
    generator = MockEmbeddingGenerator()
    embedding = generator.generate("test text")
    assert len(embedding) == 1536
    assert all(-1 <= v <= 1 for v in embedding)


def test_mock_embedding_generator_async():
    generator = MockEmbeddingGenerator()
    embedding = asyncio.run(generator.generate_async("test text"))
    assert len(embedding) == 1536
    assert all(-1 <= v <= 1 for v in embedding)


def test_build_storage_ref():
    worker = Worker("postgresql://localhost/test")
    connector_id = uuid.uuid4()
    external_id = "doc-123"

    storage_ref = worker._build_storage_ref(
        connector_id=connector_id,
        external_id=external_id,
        chunk_index=0,
        page=1,
        offset_start=0,
        offset_end=500,
    )

    assert storage_ref["connector_id"] == str(connector_id)
    assert storage_ref["external_id"] == external_id
    assert storage_ref["page"] == 1
    assert storage_ref["chunk_index"] == 0
    assert storage_ref["offset_start"] == 0
    assert storage_ref["offset_end"] == 500
    assert "checksum" in storage_ref


@pytest.mark.asyncio
async def test_generate_chunks():
    worker = Worker("postgresql://localhost/test")
    chunks = await worker._generate_chunks("test-doc")

    assert len(chunks) == MOCK_CHUNKS_COUNT
    for i, chunk in enumerate(chunks):
        assert chunk["chunk_index"] == i
        assert chunk["page"] == 1
        assert chunk["offset_start"] == i * 500
        assert chunk["offset_end"] == (i + 1) * 500


@pytest.mark.asyncio
async def test_insert_embeddings_creates_records(sample_message_with_ids):
    msg, doc_id, _, connector_id, org_id = sample_message_with_ids

    mock_conn = AsyncMock()
    mock_conn.execute = AsyncMock()

    mock_pool = MagicMock()
    mock_pool.acquire = MagicMock(return_value=MockAsyncContextManager(mock_conn))

    worker = Worker("postgresql://localhost/test")
    worker.pool = mock_pool

    inserted = await worker._insert_embeddings(
        document_id=doc_id,
        organization_id=org_id,
        connector_id=connector_id,
        external_id=msg.external_id,
    )

    assert inserted == MOCK_CHUNKS_COUNT
    assert mock_conn.execute.call_count == MOCK_CHUNKS_COUNT

    for call in mock_conn.execute.call_args_list:
        args = call[0]
        assert args[0] == (
            "\n"
            "                    INSERT INTO document_embeddings\n"
            "                    (document_id, organization_id, embedding, storage_ref)\n"
            "                    VALUES ($1, $2, $3, $4)\n"
            "                    "
        )
        assert args[1] == doc_id
        assert args[2] == org_id
        storage_ref = json.loads(args[4])
        assert storage_ref["connector_id"] == str(connector_id)
        assert storage_ref["external_id"] == msg.external_id
        assert "chunk_index" in storage_ref
        assert "checksum" in storage_ref


@pytest.mark.asyncio
async def test_insert_embeddings_storage_ref_jsonb_format(sample_message_with_ids):
    msg, doc_id, _, connector_id, org_id = sample_message_with_ids

    captured_refs = []

    async def capture_execute(query, *args):
        if "INSERT INTO document_embeddings" in query:
            captured_refs.append(json.loads(args[3]))

    mock_conn = AsyncMock()
    mock_conn.execute = capture_execute

    mock_pool = MagicMock()
    mock_pool.acquire = MagicMock(return_value=MockAsyncContextManager(mock_conn))

    worker = Worker("postgresql://localhost/test")
    worker.pool = mock_pool

    await worker._insert_embeddings(
        document_id=doc_id,
        organization_id=org_id,
        connector_id=connector_id,
        external_id=msg.external_id,
    )

    assert len(captured_refs) == MOCK_CHUNKS_COUNT

    required_keys = {
        "connector_id",
        "external_id",
        "page",
        "chunk_index",
        "offset_start",
        "offset_end",
        "checksum",
    }
    for ref in captured_refs:
        assert set(ref.keys()) == required_keys
        assert ref["connector_id"] == str(connector_id)
        assert ref["external_id"] == msg.external_id
        assert isinstance(ref["page"], int)
        assert isinstance(ref["chunk_index"], int)
        assert isinstance(ref["offset_start"], int)
        assert isinstance(ref["offset_end"], int)


@pytest.mark.asyncio
async def test_process_message_updates_audit_and_inserts(sample_message_with_ids):
    msg, doc_id, trace_id, connector_id, org_id = sample_message_with_ids
    msg_id = 42

    audit_updates = []

    async def capture_execute(query, *args):
        if "UPDATE audit_logs" in query:
            audit_updates.append(
                {
                    "status": args[0],
                    "progress": args[1],
                    "message": args[2],
                    "document_id": args[3],
                    "trace_id": args[4],
                }
            )

    mock_conn = AsyncMock()
    mock_conn.execute = capture_execute

    mock_pool = MagicMock()
    mock_pool.acquire = MagicMock(return_value=MockAsyncContextManager(mock_conn))

    worker = Worker("postgresql://localhost/test")
    worker.pool = mock_pool

    with patch.object(worker, "delete_message", new_callable=AsyncMock) as mock_delete:
        await worker.process_message(msg, msg_id)

    assert len(audit_updates) == 3

    assert audit_updates[0]["status"] == "PROCESSING"
    assert audit_updates[0]["progress"] == 10

    assert audit_updates[1]["status"] == "PROCESSING"
    assert audit_updates[1]["progress"] == 50

    assert audit_updates[2]["status"] == "INDEXED"
    assert audit_updates[2]["progress"] == 100
    assert "chunks" in audit_updates[2]["message"]
