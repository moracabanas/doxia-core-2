-- RLS Policies for Auth - Updated for multi-tenant isolation
-- Phase 4: Ensure strict tenant isolation using members table

-- ============================================
-- HELPER FUNCTION: is_org_member
-- Returns true if current user is a member of the given organization
-- ============================================
CREATE OR REPLACE FUNCTION public.is_org_member(p_org_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM members
        WHERE organization_id = p_org_id
        AND user_id = auth.uid()
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- REPLACE organizations POLICIES
-- Everyone can see organizations they belong to
-- ============================================
DROP POLICY IF EXISTS rls_select_organizations ON organizations;
CREATE POLICY rls_select_organizations ON organizations
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM members
            WHERE members.organization_id = organizations.id
            AND members.user_id = auth.uid()
        )
    );

-- ============================================
-- REPLACE connectors POLICIES
-- ============================================
DROP POLICY IF EXISTS rls_select_connectors ON connectors;
CREATE POLICY rls_select_connectors ON connectors
    FOR SELECT USING (is_org_member(organization_id));

DROP POLICY IF EXISTS rls_insert_connectors ON connectors;
CREATE POLICY rls_insert_connectors ON connectors
    FOR INSERT WITH CHECK (is_org_member(organization_id));

DROP POLICY IF EXISTS rls_update_connectors ON connectors;
CREATE POLICY rls_update_connectors ON connectors
    FOR UPDATE USING (is_org_member(organization_id));

DROP POLICY IF EXISTS rls_delete_connectors ON connectors;
CREATE POLICY rls_delete_connectors ON connectors
    FOR DELETE USING (is_org_member(organization_id));

-- ============================================
-- REPLACE documents POLICIES
-- ============================================
DROP POLICY IF EXISTS rls_select_documents ON documents;
CREATE POLICY rls_select_documents ON documents
    FOR SELECT USING (is_org_member(organization_id));

DROP POLICY IF EXISTS rls_insert_documents ON documents;
CREATE POLICY rls_insert_documents ON documents
    FOR INSERT WITH CHECK (is_org_member(organization_id));

DROP POLICY IF EXISTS rls_update_documents ON documents;
CREATE POLICY rls_update_documents ON documents
    FOR UPDATE USING (is_org_member(organization_id));

DROP POLICY IF EXISTS rls_delete_documents ON documents;
CREATE POLICY rls_delete_documents ON documents
    FOR DELETE USING (is_org_member(organization_id));

-- ============================================
-- REPLACE audit_logs POLICIES
-- ============================================
DROP POLICY IF EXISTS rls_select_audit_logs ON audit_logs;
CREATE POLICY rls_select_audit_logs ON audit_logs
    FOR SELECT USING (is_org_member(organization_id));

DROP POLICY IF EXISTS rls_insert_audit_logs ON audit_logs;
CREATE POLICY rls_insert_audit_logs ON audit_logs
    FOR INSERT WITH CHECK (is_org_member(organization_id));

DROP POLICY IF EXISTS rls_update_audit_logs ON audit_logs;
CREATE POLICY rls_update_audit_logs ON audit_logs
    FOR UPDATE USING (is_org_member(organization_id));

-- ============================================
-- REPLACE document_embeddings POLICIES
-- ============================================
DROP POLICY IF EXISTS rls_select_embeddings ON document_embeddings;
CREATE POLICY rls_select_embeddings ON document_embeddings
    FOR SELECT USING (is_org_member(organization_id));

DROP POLICY IF EXISTS rls_insert_embeddings ON document_embeddings;
CREATE POLICY rls_insert_embeddings ON document_embeddings
    FOR INSERT WITH CHECK (is_org_member(organization_id));
