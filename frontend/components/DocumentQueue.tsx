"use client";

import { useEffect, useState } from "react";
import { supabase } from "@/lib/supabase";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Progress } from "@/components/ui/progress";
import { Skeleton } from "@/components/ui/skeleton";
import { motion, AnimatePresence } from "framer-motion";
import { FileText } from "lucide-react";

type AuditLog = {
  id: string;
  document_id: string;
  trace_id: string;
  status: string;
  progress_percentage: number;
  message: string | null;
  created_at: string;
};

type DocumentEntry = {
  document_id: string;
  trace_id: string;
  status: string;
  progress_percentage: number;
  message: string | null;
  updated_at: string;
};

const STATUS_COLORS: Record<string, string> = {
  PENDING: "bg-yellow-500",
  QUEUED: "bg-blue-500",
  PROCESSING: "bg-purple-500",
  INDEXED: "bg-green-500",
  ERROR: "bg-red-500",
};

export function DocumentQueue() {
  const [documents, setDocuments] = useState<DocumentEntry[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchInitialData = async () => {
      const { data, error } = await supabase
        .from("audit_logs")
        .select("document_id, trace_id, status, progress_percentage, message, created_at")
        .order("created_at", { ascending: false })
        .limit(50);

      if (error) {
        console.error("Error fetching audit logs:", error);
        setLoading(false);
        return;
      }

      const logs = data as AuditLog[];
      const latestByDoc = new Map<string, DocumentEntry>();
      
      logs.forEach((log) => {
        const existing = latestByDoc.get(log.document_id);
        if (!existing || new Date(log.created_at) > new Date(existing.updated_at)) {
          latestByDoc.set(log.document_id, {
            document_id: log.document_id,
            trace_id: log.trace_id,
            status: log.status,
            progress_percentage: log.progress_percentage,
            message: log.message,
            updated_at: log.created_at,
          });
        }
      });

      setDocuments(Array.from(latestByDoc.values()));
      setLoading(false);
    };

    fetchInitialData();

    const channel = supabase
      .channel("audit_logs_realtime")
      .on(
        "postgres_changes",
        {
          event: "UPDATE",
          schema: "public",
          table: "audit_logs",
        },
        (payload) => {
          const log = payload.new as AuditLog;
          setDocuments((prev) => {
            const existing = prev.find((d) => d.document_id === log.document_id);
            if (existing) {
              return prev.map((d) =>
                d.document_id === log.document_id
                  ? {
                      ...d,
                      status: log.status,
                      progress_percentage: log.progress_percentage,
                      message: log.message,
                      updated_at: log.created_at,
                    }
                  : d
              );
            }
            return [
              {
                document_id: log.document_id,
                trace_id: log.trace_id,
                status: log.status,
                progress_percentage: log.progress_percentage,
                message: log.message,
                updated_at: log.created_at,
              },
              ...prev,
            ];
          });
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, []);

  if (loading) {
    return (
      <div className="space-y-4">
        {[...Array(3)].map((_, i) => (
          <Card key={i}>
            <CardHeader className="pb-3">
              <Skeleton className="h-4 w-32" />
            </CardHeader>
            <CardContent>
              <Skeleton className="h-4 w-full mb-2" />
              <Skeleton className="h-2 w-full" />
            </CardContent>
          </Card>
        ))}
      </div>
    );
  }

  return (
    <div className="space-y-4">
      <div className="flex items-center gap-2 mb-6">
        <FileText className="h-6 w-6" />
        <h2 className="text-2xl font-bold">Document Queue</h2>
        <Badge variant="secondary">{documents.length}</Badge>
      </div>
      <AnimatePresence mode="popLayout">
        {documents.map((doc) => (
          <motion.div
            key={doc.document_id}
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, scale: 0.95 }}
            transition={{ duration: 0.3 }}
          >
            <Card>
              <CardHeader className="pb-3">
                <div className="flex items-center justify-between">
                  <CardTitle className="text-sm font-mono truncate max-w-md">
                    {doc.document_id.slice(0, 8)}...
                  </CardTitle>
                  <Badge
                    className={`${
                      STATUS_COLORS[doc.status] || "bg-gray-500"
                    } text-white`}
                  >
                    {doc.status}
                  </Badge>
                </div>
              </CardHeader>
              <CardContent className="space-y-2">
                <div className="flex items-center justify-between text-sm text-muted-foreground">
                  <span>Progress</span>
                  <span>{doc.progress_percentage}%</span>
                </div>
                <Progress value={doc.progress_percentage} />
                {doc.message && (
                  <p className="text-xs text-muted-foreground mt-2">{doc.message}</p>
                )}
                <p className="text-xs text-muted-foreground">
                  Trace: {doc.trace_id}
                </p>
              </CardContent>
            </Card>
          </motion.div>
        ))}
      </AnimatePresence>
      {documents.length === 0 && (
        <Card>
          <CardContent className="py-12 text-center text-muted-foreground">
            No documents in queue. Waiting for worker to process documents...
          </CardContent>
        </Card>
      )}
    </div>
  );
}
