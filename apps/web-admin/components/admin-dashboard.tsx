"use client";

import { useEffect, useState } from "react";
import { Bot, Clock3, MessageCircle, Ticket } from "lucide-react";
import { ApiClientError, apiClient } from "@/lib/api-client";
import { dashboardStats } from "@/lib/mock-data";
import type { DashboardStats } from "@/lib/types";
import { useAuth } from "./auth-provider";
import { PageHeader, Panel, Stat } from "./ui";
import { SuperAdminSection } from "./super-admin-section";

function adminError(error: unknown) {
  if (error instanceof ApiClientError && error.status === 403) {
    return "You do not have permission to view dashboard analytics.";
  }
  return "Dashboard data is unavailable. Showing local preview data.";
}

export function AdminDashboard() {
  const { accessToken, isMock } = useAuth();
  const [stats, setStats] = useState<DashboardStats>(dashboardStats);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (isMock || !accessToken) return;
    let active = true;
    async function loadStats() {
      try {
        const response = await apiClient.dashboardStats(accessToken ?? undefined);
        if (active) setStats(response);
      } catch (loadError) {
        if (active) setError(adminError(loadError));
      }
    }
    void loadStats();
    return () => {
      active = false;
    };
  }, [accessToken, isMock]);

  const maxTrend = Math.max(...stats.sevenDayMessageTrend.map((item) => item.count), 1);

  return (
    <SuperAdminSection>
      <PageHeader
        title="Dashboard"
        description="Monitor automation rate, urgent queues, and response-time health for the support team."
      />
      {error ? <div className="border-b border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800">{error}</div> : null}
      <div className="space-y-4 p-4">
        <div className="grid gap-3 md:grid-cols-4">
          <Stat icon={MessageCircle} label="Messages today" value={String(stats.totalMessagesToday)} delta="Live queue" />
          <Stat icon={Bot} label="AI handling rate" value={`${stats.aiHandlingRate}%`} delta="Auto answered" />
          <Stat icon={Clock3} label="Avg response" value={`${stats.averageResponseTimeSeconds.toFixed(1)}s`} delta="Human + AI" />
          <Stat icon={Ticket} label="Open tickets" value={String(stats.openTicketCount)} delta="Needs review" />
        </div>
        <div className="grid gap-4 lg:grid-cols-[1fr_380px]">
          <Panel title="7-day message trend">
            <div className="flex h-72 items-end gap-3 border-l border-b border-line px-3 pb-3">
              {stats.sevenDayMessageTrend.map((item) => (
                <div className="flex h-full flex-1 flex-col justify-end gap-2" key={item.day}>
                  <div
                    className="min-h-2 bg-brand"
                    style={{ height: `${Math.max(8, (item.count / maxTrend) * 220)}px` }}
                    title={`${item.count} messages`}
                  />
                  <div className="text-center text-xs text-slate-500">{item.day}</div>
                </div>
              ))}
            </div>
          </Panel>
          <Panel title="Top 5 questions">
            <div className="space-y-3">
              {stats.topQuestions.map((question, index) => (
                <div className="border-b border-line pb-3 last:border-0 last:pb-0" key={question.question}>
                  <div className="flex items-start gap-3">
                    <div className="flex size-7 shrink-0 items-center justify-center bg-slate-100 text-xs font-semibold text-slate-600">
                      {index + 1}
                    </div>
                    <div className="min-w-0 flex-1">
                      <div className="text-sm font-medium text-ink">{question.question}</div>
                      <div className="mt-1 text-xs text-slate-500">{question.count} messages</div>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          </Panel>
        </div>
      </div>
    </SuperAdminSection>
  );
}
