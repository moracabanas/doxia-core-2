-- Enable pgvector extension for vector similarity search
CREATE EXTENSION IF NOT EXISTS vector;

-- ============================================
-- DOCUMENT_EMBEDDINGS
-- Pointer-based RAG: stores ONLY vectors and storage references
-- NO text content stored - only pointers to original source
-- ============================================
CREATE TABLE document_embeddings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id UUID NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    embedding vector(1536) NOT NULL,
    storage_ref JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes for efficient vector search and filtering
CREATE INDEX idx_embeddings_document_id ON document_embeddings(document_id);
CREATE INDEX idx_embeddings_organization_id ON document_embeddings(organization_id);
CREATE INDEX idx_embeddings_embedding ON document_embeddings USING hnsw (embedding vector_cosine_ops);

-- RLS for document_embeddings
ALTER TABLE document_embeddings ENABLE ROW LEVEL SECURITY;
CREATE POLICY rls_select_embeddings ON document_embeddings FOR SELECT USING (organization_id = current_user_org_id());
CREATE POLICY rls_insert_embeddings ON document_embeddings FOR INSERT WITH CHECK (organization_id = current_user_org_id());

-- Comments
COMMENT ON TABLE document_embeddings IS 'Vector embeddings with storage_ref pointers - NO text content stored';
COMMENT ON COLUMN document_embeddings.storage_ref IS '{connector_id, external_id, page, offset_start, offset_end, checksum}';
COMMENT ON COLUMN document_embeddings.embedding IS '1536-dimension vector from embedding model';
