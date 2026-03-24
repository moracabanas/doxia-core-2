-- RLS Policies using is_org_member function
-- These replace the old policies that used current_user_org_id()

-- organizations
DROP POLICY IF EXISTS rls_select_organizations ON organizations;
CREATE POLICY rls_select_organizations ON organizations
    FOR SELECT USING (is_org_member(id));

-- connectors
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

-- documents
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

-- audit_logs
DROP POLICY IF EXISTS rls_select_audit_logs ON audit_logs;
CREATE POLICY rls_select_audit_logs ON audit_logs
    FOR SELECT USING (is_org_member(organization_id));

DROP POLICY IF EXISTS rls_insert_audit_logs ON audit_logs;
CREATE POLICY rls_insert_audit_logs ON audit_logs
    FOR INSERT WITH CHECK (is_org_member(organization_id));

DROP POLICY IF EXISTS rls_update_audit_logs ON audit_logs;
CREATE POLICY rls_update_audit_logs ON audit_logs
    FOR UPDATE USING (is_org_member(organization_id));

-- document_embeddings
DROP POLICY IF EXISTS rls_select_embeddings ON document_embeddings;
CREATE POLICY rls_select_embeddings ON document_embeddings
    FOR SELECT USING (is_org_member(organization_id));

DROP POLICY IF EXISTS rls_insert_embeddings ON document_embeddings;
CREATE POLICY rls_insert_embeddings ON document_embeddings
    FOR INSERT WITH CHECK (is_org_member(organization_id));
