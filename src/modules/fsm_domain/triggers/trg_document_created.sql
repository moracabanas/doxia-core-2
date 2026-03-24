-- Trigger: trg_document_created
-- Fires AFTER INSERT on documents table

DROP TRIGGER IF EXISTS trg_document_created ON documents;

CREATE TRIGGER trg_document_created
    AFTER INSERT ON documents
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_on_document_created();
