-- Doxia Core: Core Schema
-- Phase 1: DDL and FSM base tables

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================
-- ORGANIZATIONS
-- ============================================
CREATE TABLE organizations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================
-- CONNECTORS
-- ============================================
CREATE TABLE connectors (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    type VARCHAR(50) NOT NULL,
    config JSONB NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_connectors_organization_id ON connectors(organization_id);

-- ============================================
-- DOCUMENTS
-- ============================================
CREATE TABLE documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    connector_id UUID NOT NULL REFERENCES connectors(id) ON DELETE CASCADE,
    external_id VARCHAR(500) NOT NULL,
    checksum VARCHAR(64),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_documents_organization_id ON documents(organization_id);
CREATE INDEX idx_documents_connector_id ON documents(connector_id);
CREATE INDEX idx_documents_external_id ON documents(external_id);

-- ============================================
-- AUDIT_LOGS (FSM telemetry)
-- ============================================
CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id UUID NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
    trace_id UUID NOT NULL,
    status VARCHAR(50) NOT NULL,
    progress_percentage INT NOT NULL DEFAULT 0 CHECK (progress_percentage >= 0 AND progress_percentage <= 100),
    message TEXT,
    eta TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_audit_logs_document_id ON audit_logs(document_id);
CREATE INDEX idx_audit_logs_trace_id ON audit_logs(trace_id);

-- ============================================
-- COMMENTS
-- ============================================
COMMENT ON TABLE organizations IS 'Tenant-scoped organizations for multi-tenancy';
COMMENT ON TABLE connectors IS 'Document source connectors (sharepoint, paperless, boe)';
COMMENT ON TABLE documents IS 'Document metadata with pointer-based storage';
COMMENT ON TABLE audit_logs IS 'FSM state transitions and progress tracking';
COMMENT ON COLUMN audit_logs.progress_percentage IS '0-100 progress indicator';
COMMENT ON COLUMN audit_logs.trace_id IS 'UUID per document/transaction for telemetry';
