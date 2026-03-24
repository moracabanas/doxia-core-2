"use client";

import { useEffect, useState } from "react";
import { supabase } from "@/lib/supabase";
import type { AuditLog } from "@/lib/types";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Progress } from "@/components/ui/progress";
import { Skeleton } from "@/components/ui/skeleton";
import { motion, AnimatePresence } from "framer-motion";
import { FileText, Clock, CheckCircle2, AlertCircle } from "lucide-react";

const statusConfig = {
  PENDING: { color: "bg-yellow-500", icon: Clock },
  QUEUED: { color: "bg-blue-500", icon: Clock },
  PROCESSING: { color: "bg-blue-600 animate-pulse", icon: FileText },
  INDEXED: { color: "bg-green-500", icon: CheckCircle2 },
  ERROR: { color: "bg-red-500", icon: AlertCircle },
};

export function DocumentQueue() {
  const [auditLogs, setAuditLogs] = useState<AuditLog[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchInitialData = async () => {
      const { data, error } = await supabase
        .from("audit_logs")
        .select("*")
        .order("created_at", { ascending: false })
        .limit(20);

      if (!error && data) {
        setAuditLogs(data);
      }
      setLoading(false);
    };

    fetchInitialData();

    const channel = supabase
      .channel("audit_logs_realtime")
      .on(
        "postgres_changes",
        {
          event: "*",
          schema: "public",
          table: "audit_logs",
        },
        (payload) => {
          if (payload.eventType === "INSERT" || payload.eventType === "UPDATE") {
            const newLog = payload.new as AuditLog;
            setAuditLogs((prev) => {
              const existing = prev.find((log) => log.id === newLog.id);
              if (existing) {
                return prev.map((log) => (log.id === newLog.id ? newLog : log));
              }
              return [newLog, ...prev].slice(0, 20);
            });
          }
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
        {[1, 2, 3].map((i) => (
          <Skeleton key={i} className="h-32 w-full" />
        ))}
      </div>
    );
  }

  return (
    <div className="space-y-4">
      <AnimatePresence mode="popLayout">
        {auditLogs.map((log) => {
          const config = statusConfig[log.status as keyof typeof statusConfig] || statusConfig.PENDING;
          const StatusIcon = config.icon;

          return (
            <motion.div
              key={log.id}
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, scale: 0.95 }}
              transition={{ duration: 0.3 }}
            >
              <Card className="overflow-hidden">
                <CardHeader className="pb-2">
                  <div className="flex items-center justify-between">
                    <CardTitle className="text-sm font-mono flex items-center gap-2">
                      <StatusIcon className="h-4 w-4" />
                      {log.trace_id.slice(0, 8)}...
                    </CardTitle>
                    <Badge
                      variant="outline"
                      className={`${config.color} text-white border-0`}
                    >
                      {log.status}
                    </Badge>
                  </div>
                </CardHeader>
                <CardContent>
                  <div className="space-y-2">
                    <div className="flex justify-between text-sm text-muted-foreground">
                      <span>{log.message || "Processing..."}</span>
                      <span>{log.progress_percentage}%</span>
                    </div>
                    <Progress value={log.progress_percentage} className="h-2" />
                    <p className="text-xs text-muted-foreground">
                      {new Date(log.created_at).toLocaleString()}
                    </p>
                  </div>
                </CardContent>
              </Card>
            </motion.div>
          );
        })}
      </AnimatePresence>

      {auditLogs.length === 0 && (
        <div className="text-center py-12 text-muted-foreground">
          <FileText className="h-12 w-12 mx-auto mb-4 opacity-50" />
          <p>No documents in queue</p>
          <p className="text-sm">Insert a document to see it here</p>
        </div>
      )}
    </div>
  );
}
