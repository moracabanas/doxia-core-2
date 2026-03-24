import { supabase } from "@/lib/supabase";

export type AuditLog = {
  id: string;
  document_id: string;
  organization_id: string;
  trace_id: string;
  status: "PENDING" | "QUEUED" | "PROCESSING" | "INDEXED" | "ERROR";
  progress_percentage: number;
  message: string | null;
  eta: string | null;
  created_at: string;
};

export type DocumentWithAudit = {
  document_id: string;
  trace_id: string;
  status: string;
  progress: number;
  message: string;
  created_at: string;
};
