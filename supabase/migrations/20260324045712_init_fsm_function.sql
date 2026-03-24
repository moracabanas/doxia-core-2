-- FSM Function: Trigger on document insert
-- Creates audit log entry and enqueues work for document processing

-- Function: fn_on_document_created
CREATE OR REPLACE FUNCTION public.fn_on_document_created()
RETURNS TRIGGER AS $$
DECLARE
    v_trace_id UUID;
BEGIN
    -- Generate new trace_id for this document processing cycle
    v_trace_id := gen_random_uuid();

    -- Insert initial audit log entry with PENDING status
    INSERT INTO audit_logs (document_id, organization_id, trace_id, status, progress_percentage, message)
    VALUES (
        NEW.id,
        NEW.organization_id,
        v_trace_id,
        'PENDING',
        0,
        'Document queued for processing'
    );

    -- Send message to processing queue
    PERFORM pgmq.send(
        'doc_processing_queue',
        jsonb_build_object(
            'document_id', NEW.id,
            'trace_id', v_trace_id,
            'connector_id', NEW.connector_id,
            'organization_id', NEW.organization_id,
            'external_id', NEW.external_id
        )
    );

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger: trg_document_created
DROP TRIGGER IF EXISTS trg_document_created ON documents;

CREATE TRIGGER trg_document_created
    AFTER INSERT ON documents
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_on_document_created();
