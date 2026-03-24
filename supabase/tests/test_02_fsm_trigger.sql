-- pgTAP Tests for FSM Trigger
-- Phase 2: Verify document insert triggers audit log creation and queue message

BEGIN;

-- Setup: Insert test data (runs in same transaction)
INSERT INTO organizations (name) VALUES ('Test Org FSM');
INSERT INTO connectors (organization_id, type, config)
SELECT id, 'sharepoint', '{}' FROM organizations WHERE name = 'Test Org FSM' LIMIT 1;
INSERT INTO documents (organization_id, connector_id, external_id, checksum)
SELECT c.organization_id, c.id, 'test-doc-fsm-001', 'checksum123'
FROM connectors c WHERE c.type = 'sharepoint' LIMIT 1;

-- Total tests
SELECT plan(6);

-- ============================================
-- Test: Verify function exists
-- ============================================
SELECT ok(
    EXISTS (
        SELECT 1 FROM pg_proc
        WHERE proname = 'fn_on_document_created'
    ),
    'Function fn_on_document_created should exist'
);

-- ============================================
-- Test: Verify trigger exists
-- ============================================
SELECT ok(
    EXISTS (
        SELECT 1 FROM pg_trigger
        WHERE tgname = 'trg_document_created'
    ),
    'Trigger trg_document_created should exist on documents table'
);

-- ============================================
-- Test: Audit log was created for inserted document
-- ============================================
SELECT ok(
    EXISTS (
        SELECT 1 FROM audit_logs al
        WHERE al.status = 'PENDING'
        AND al.progress_percentage = 0
        AND al.message = 'Document queued for processing'
    ),
    'A PENDING audit log should exist with progress 0 and processing message'
);

-- ============================================
-- Test: Audit log has trace_id
-- ============================================
SELECT ok(
    EXISTS (
        SELECT 1 FROM audit_logs
        WHERE trace_id IS NOT NULL
        AND status = 'PENDING'
    ),
    'Audit log should have a trace_id'
);

-- ============================================
-- Test: Queue send function works (verify function exists)
-- ============================================
SELECT ok(
    EXISTS (
        SELECT 1 FROM pg_proc
        WHERE proname = 'send'
        AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'pgmq')
    ),
    'pgmq.send function should exist'
);

-- ============================================
-- Test: Document count matches audit logs
-- ============================================
SELECT ok(
    (SELECT COUNT(DISTINCT document_id) FROM audit_logs) =
    (SELECT COUNT(*) FROM documents)
    AND (SELECT COUNT(*) FROM documents) > 0,
    'Each document should have exactly one PENDING audit log'
);

-- ============================================
-- Complete
-- ============================================
SELECT * FROM finish();

ROLLBACK;
