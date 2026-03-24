-- pgTAP Tests for Doxia Core Schema
-- Phase 1: Verify core tables exist and have correct structure + RLS

BEGIN;

-- Total number of tests (47 total)
SELECT plan(47);

-- ============================================
-- Test: organizations table
-- ============================================
SELECT ok(
    EXISTS (
        SELECT FROM pg_tables
        WHERE schemaname = 'public'
        AND tablename = 'organizations'
    ),
    'organizations table should exist'
);

SELECT ok(
    EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'organizations'
        AND column_name = 'id'
        AND data_type = 'uuid'
    ),
    'organizations.id should be UUID'
);

SELECT ok(
    EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'organizations'
        AND column_name = 'name'
        AND data_type = 'character varying'
    ),
    'organizations.name should be VARCHAR'
);

SELECT ok(
    EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'organizations'
        AND column_name = 'created_at'
        AND data_type = 'timestamp with time zone'
    ),
    'organizations.created_at should be TIMESTAMPTZ'
);

SELECT ok(
    EXISTS (
        SELECT 1 FROM pg_tables
        WHERE tablename = 'organizations'
        AND rowsecurity = true
    ),
    'organizations should have RLS enabled'
);

-- ============================================
-- Test: connectors table
-- ============================================
SELECT ok(
    EXISTS (
        SELECT FROM pg_tables
        WHERE schemaname = 'public'
        AND tablename = 'connectors'
    ),
    'connectors table should exist'
);

SELECT ok(
    EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'connectors'
        AND column_name = 'id'
        AND data_type = 'uuid'
    ),
    'connectors.id should be UUID'
);

SELECT ok(
    EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'connectors'
        AND column_name = 'organization_id'
        AND data_type = 'uuid'
    ),
    'connectors.organization_id should be UUID'
);

SELECT ok(
    EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'connectors'
        AND column_name = 'type'
        AND data_type = 'character varying'
    ),
    'connectors.type should be VARCHAR'
);

SELECT ok(
    EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'connectors'
        AND column_name = 'config'
        AND data_type = 'jsonb'
    ),
    'connectors.config should be JSONB'
);

SELECT ok(
    EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'connectors'
        AND column_name = 'created_at'
        AND data_type = 'timestamp with time zone'
    ),
    'connectors.created_at should be TIMESTAMPTZ'
);

SELECT ok(
    EXISTS (
        SELECT 1 FROM pg_tables
        WHERE tablename = 'connectors'
        AND rowsecurity = true
    ),
    'connectors should have RLS enabled'
);

SELECT ok(
    EXISTS (
        SELECT 1 FROM pg_policies
        WHERE tablename = 'connectors'
        AND policyname = 'rls_select_connectors'
    ),
    'connectors should have rls_select_connectors policy'
);

SELECT ok(
    EXISTS (
        SELECT 1 FROM pg_policies
        WHERE tablename = 'connectors'
        AND policyname = 'rls_insert_connectors'
    ),
    'connectors should have rls_insert_connectors policy'
);

-- ============================================
-- Test: documents table
-- ============================================
SELECT ok(
    EXISTS (
        SELECT FROM pg_tables
        WHERE schemaname = 'public'
        AND tablename = 'documents'
    ),
    'documents table should exist'
);

SELECT ok(
    EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'documents'
        AND column_name = 'id'
        AND data_type = 'uuid'
    ),
    'documents.id should be UUID'
);

SELECT ok(
    EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'documents'
        AND column_name = 'organization_id'
        AND data_type = 'uuid'
    ),
    'documents.organization_id should be UUID'
);

SELECT ok(
    EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'documents'
        AND column_name = 'connector_id'
        AND data_type = 'uuid'
    ),
    'documents.connector_id should be UUID'
);

SELECT ok(
    EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'documents'
        AND column_name = 'external_id'
        AND data_type = 'character varying'
    ),
    'documents.external_id should be VARCHAR'
);

SELECT ok(
    EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'documents'
        AND column_name = 'checksum'
        AND data_type = 'character varying'
    ),
    'documents.checksum should be VARCHAR'
);

SELECT ok(
    EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'documents'
        AND column_name = 'created_at'
        AND data_type = 'timestamp with time zone'
    ),
    'documents.created_at should be TIMESTAMPTZ'
);

SELECT ok(
    EXISTS (
        SELECT 1 FROM pg_tables
        WHERE tablename = 'documents'
        AND rowsecurity = true
    ),
    'documents should have RLS enabled'
);

SELECT ok(
    EXISTS (
        SELECT 1 FROM pg_policies
        WHERE tablename = 'documents'
        AND policyname = 'rls_select_documents'
    ),
    'documents should have rls_select_documents policy'
);

-- ============================================
-- Test: audit_logs table
-- ============================================
SELECT ok(
    EXISTS (
        SELECT FROM pg_tables
        WHERE schemaname = 'public'
        AND tablename = 'audit_logs'
    ),
    'audit_logs table should exist'
);

SELECT ok(
    EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'audit_logs'
        AND column_name = 'id'
        AND data_type = 'uuid'
    ),
    'audit_logs.id should be UUID'
);

SELECT ok(
    EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'audit_logs'
        AND column_name = 'document_id'
        AND data_type = 'uuid'
    ),
    'audit_logs.document_id should be UUID'
);

SELECT ok(
    EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'audit_logs'
        AND column_name = 'organization_id'
        AND data_type = 'uuid'
    ),
    'audit_logs.organization_id should be UUID'
);

SELECT ok(
    EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'audit_logs'
        AND column_name = 'trace_id'
        AND data_type = 'uuid'
    ),
    'audit_logs.trace_id should be UUID'
);

SELECT ok(
    EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'audit_logs'
        AND column_name = 'status'
        AND data_type = 'character varying'
    ),
    'audit_logs.status should be VARCHAR'
);

SELECT ok(
    EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'audit_logs'
        AND column_name = 'progress_percentage'
        AND data_type = 'integer'
    ),
    'audit_logs.progress_percentage should be INT'
);

SELECT ok(
    EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'audit_logs'
        AND column_name = 'message'
        AND data_type = 'text'
    ),
    'audit_logs.message should be TEXT'
);

SELECT ok(
    EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'audit_logs'
        AND column_name = 'eta'
        AND data_type = 'timestamp with time zone'
    ),
    'audit_logs.eta should be TIMESTAMPTZ'
);

SELECT ok(
    EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'audit_logs'
        AND column_name = 'created_at'
        AND data_type = 'timestamp with time zone'
    ),
    'audit_logs.created_at should be TIMESTAMPTZ'
);

SELECT ok(
    EXISTS (
        SELECT 1 FROM pg_tables
        WHERE tablename = 'audit_logs'
        AND rowsecurity = true
    ),
    'audit_logs should have RLS enabled'
);

SELECT ok(
    EXISTS (
        SELECT 1 FROM pg_policies
        WHERE tablename = 'audit_logs'
        AND policyname = 'rls_select_audit_logs'
    ),
    'audit_logs should have rls_select_audit_logs policy'
);

-- ============================================
-- Test: Foreign keys
-- ============================================
SELECT ok(
    EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'connectors_organization_id_fkey'
        AND constraint_type = 'FOREIGN KEY'
    ),
    'connectors.organization_id FK should exist'
);

SELECT ok(
    EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'documents_organization_id_fkey'
        AND constraint_type = 'FOREIGN KEY'
    ),
    'documents.organization_id FK should exist'
);

SELECT ok(
    EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'documents_connector_id_fkey'
        AND constraint_type = 'FOREIGN KEY'
    ),
    'documents.connector_id FK should exist'
);

SELECT ok(
    EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'audit_logs_document_id_fkey'
        AND constraint_type = 'FOREIGN KEY'
    ),
    'audit_logs.document_id FK should exist'
);

SELECT ok(
    EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'audit_logs_organization_id_fkey'
        AND constraint_type = 'FOREIGN KEY'
    ),
    'audit_logs.organization_id FK should exist'
);

-- ============================================
-- Test: Indexes
-- ============================================
SELECT ok(
    EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE indexname = 'idx_connectors_organization_id'
    ),
    'idx_connectors_organization_id should exist'
);

SELECT ok(
    EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE indexname = 'idx_documents_organization_id'
    ),
    'idx_documents_organization_id should exist'
);

SELECT ok(
    EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE indexname = 'idx_documents_connector_id'
    ),
    'idx_documents_connector_id should exist'
);

SELECT ok(
    EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE indexname = 'idx_documents_external_id'
    ),
    'idx_documents_external_id should exist'
);

SELECT ok(
    EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE indexname = 'idx_audit_logs_document_id'
    ),
    'idx_audit_logs_document_id should exist'
);

SELECT ok(
    EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE indexname = 'idx_audit_logs_trace_id'
    ),
    'idx_audit_logs_trace_id should exist'
);

SELECT ok(
    EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE indexname = 'idx_audit_logs_organization_id'
    ),
    'idx_audit_logs_organization_id should exist'
);

-- ============================================
-- Complete
-- ============================================
SELECT * FROM finish();

ROLLBACK;
