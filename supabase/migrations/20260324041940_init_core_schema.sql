-- Doxia Core: Core Schema
-- Phase 1: DDL and FSM base tables

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================
-- HELPER FUNCTION: current_user_org_id
-- Returns the organization_id of the current user from JWT
-- ============================================
CREATE OR REPLACE FUNCTION current_user_org_id() RETURNS UUID AS $$
BEGIN
    RETURN NULLIF(current_setting('request.jwt.claim.org_id', true), '')::UUID;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- ORGANIZATIONS
-- ============================================
CREATE TABLE organizations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- RLS for organizations (public for now - org creation is special)
ALTER TABLE organizations ENABLE ROW LEVEL SECURITY;

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

-- RLS for connectors
ALTER TABLE connectors ENABLE ROW LEVEL SECURITY;
CREATE POLICY rls_select_connectors ON connectors FOR SELECT USING (organization_id = current_user_org_id());
CREATE POLICY rls_insert_connectors ON connectors FOR INSERT WITH CHECK (organization_id = current_user_org_id());
CREATE POLICY rls_update_connectors ON connectors FOR UPDATE USING (organization_id = current_user_org_id());
CREATE POLICY rls_delete_connectors ON connectors FOR DELETE USING (organization_id = current_user_org_id());

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

-- RLS for documents
ALTER TABLE documents ENABLE ROW LEVEL SECURITY;
CREATE POLICY rls_select_documents ON documents FOR SELECT USING (organization_id = current_user_org_id());
CREATE POLICY rls_insert_documents ON documents FOR INSERT WITH CHECK (organization_id = current_user_org_id());
CREATE POLICY rls_update_documents ON documents FOR UPDATE USING (organization_id = current_user_org_id());
CREATE POLICY rls_delete_documents ON documents FOR DELETE USING (organization_id = current_user_org_id());

-- ============================================
-- AUDIT_LOGS (FSM telemetry)
-- ============================================
CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id UUID NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    trace_id UUID NOT NULL,
    status VARCHAR(50) NOT NULL,
    progress_percentage INT NOT NULL DEFAULT 0 CHECK (progress_percentage >= 0 AND progress_percentage <= 100),
    message TEXT,
    eta TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_audit_logs_document_id ON audit_logs(document_id);
CREATE INDEX idx_audit_logs_trace_id ON audit_logs(trace_id);
CREATE INDEX idx_audit_logs_organization_id ON audit_logs(organization_id);

-- RLS for audit_logs
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;
CREATE POLICY rls_select_audit_logs ON audit_logs FOR SELECT USING (organization_id = current_user_org_id());
CREATE POLICY rls_insert_audit_logs ON audit_logs FOR INSERT WITH CHECK (organization_id = current_user_org_id());
CREATE POLICY rls_update_audit_logs ON audit_logs FOR UPDATE USING (organization_id = current_user_org_id());

-- ============================================
-- COMMENTS
-- ============================================
COMMENT ON TABLE organizations IS 'Tenant-scoped organizations for multi-tenancy';
COMMENT ON TABLE connectors IS 'Document source connectors (sharepoint, paperless, boe)';
COMMENT ON TABLE documents IS 'Document metadata with pointer-based storage';
COMMENT ON TABLE audit_logs IS 'FSM state transitions and progress tracking';
COMMENT ON COLUMN audit_logs.progress_percentage IS '0-100 progress indicator';
COMMENT ON COLUMN audit_logs.trace_id IS 'UUID per document/transaction for telemetry';
COMMENT ON FUNCTION current_user_org_id() IS 'Returns org_id from JWT claim for RLS policies';
