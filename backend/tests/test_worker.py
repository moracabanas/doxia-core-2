# /// script
# requires-python = ">=3.12"
# dependencies = [
#   "asyncpg",
#   "pytest",
#   "pytest-asyncio",
# ]
# ///

"""
Tests for PGMQ Worker
"""

import asyncio
import sys
import uuid
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).parent.parent))

from worker import QueueMessage, Worker


@pytest.fixture
def sample_message():
    return QueueMessage(
        document_id=uuid.uuid4(),
        trace_id=uuid.uuid4(),
        connector_id=uuid.uuid4(),
        organization_id=uuid.uuid4(),
        external_id="test-doc-001",
    )


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
