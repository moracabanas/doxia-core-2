-- Enable PGMQ extension for message queue
CREATE EXTENSION IF NOT EXISTS pgmq;

-- Create the document processing queue
SELECT pgmq.create('doc_processing_queue');
