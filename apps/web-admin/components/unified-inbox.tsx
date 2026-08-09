"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import {
  CheckCircle2,
  Clock3,
  Loader2,
  MessageSquare,
  RefreshCw,
  RotateCcw,
  Search,
  Send,
  UserCheck,
  WifiOff
} from "lucide-react";
import { ApiClientError, apiClient } from "@/lib/api-client";
import { canViewSection, supabase } from "@/lib/auth";
import { conversationMessages, tickets as mockTickets } from "@/lib/mock-data";
import type {
  ChannelType,
  ConversationMessage,
  IntentType,
  TicketFilters,
  TicketStatus,
  TicketSummary
} from "@/lib/types";
import { useAuth } from "./auth-provider";
import { PageHeader, StatusBadge } from "./ui";

type RealtimeState = "placeholder" | "connecting" | "connected" | "disconnected" | "retrying";

const initialFilters: TicketFilters = {
  source: "all",
  status: "all",
  ownership: "all",
  search: ""
};

const sourceLabels: Record<ChannelType, string> = {
  web: "Web",
  facebook: "Facebook",
  email: "Email"
};

function asString(value: unknown, fallback = "") {
  return typeof value === "string" && value ? value : fallback;
}

function normalizeTicket(value: Partial<TicketSummary> & Record<string, unknown>): TicketSummary {
  const source = value.source === "facebook" || value.source === "email" ? value.source : "web";
  const statusValues: TicketStatus[] = ["open", "in_progress", "pending", "resolved"];
  const intentValues: IntentType[] = ["question", "complaint", "spam"];
  const updatedAt = asString(value.updatedAt ?? value.updated_at, new Date().toISOString());

  return {
    id: asString(value.id, "unknown-ticket"),
    customerId: asString(value.customerId ?? value.customer_id),
    customerName: asString(value.customerName ?? value.customer_name, "Unknown customer"),
    source,
    status: statusValues.includes(value.status as TicketStatus) ? (value.status as TicketStatus) : "open",
    intent: intentValues.includes(value.intent as IntentType) ? (value.intent as IntentType) : "question",
    summary: asString(value.summary, "No summary yet"),
    lastMessagePreview: asString(value.lastMessagePreview ?? value.last_message_preview ?? value.summary),
    createdAt: asString(value.createdAt ?? value.created_at, updatedAt),
    updatedAt,
    assignedTo: asString(value.assignedTo ?? value.assigned_to)
  };
}

function normalizeMessage(value: Partial<ConversationMessage> & Record<string, unknown>): ConversationMessage {
  const senderType =
    value.senderType === "bot" || value.senderType === "human" || value.senderType === "customer"
      ? value.senderType
      : value.sender_type === "bot" || value.sender_type === "human" || value.sender_type === "customer"
        ? value.sender_type
        : "customer";

  return {
    id: asString(value.id, crypto.randomUUID()),
    ticketId: asString(value.ticketId ?? value.ticket_id),
    senderType,
    senderId: asString(value.senderId ?? value.sender_id),
    content: asString(value.content),
    createdAt: asString(value.createdAt ?? value.created_at, new Date().toISOString())
  };
}

function formatTime(value?: string) {
  if (!value) return "Unknown";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return value;
  return new Intl.DateTimeFormat("en", {
    month: "short",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit"
  }).format(date);
}

function filterMockTickets(items: TicketSummary[], filters: TicketFilters, currentUserId: string) {
  const query = filters.search.trim().toLowerCase();
  return items.filter((ticket) => {
    const matchesSource = filters.source === "all" || ticket.source === filters.source;
    const matchesStatus = filters.status === "all" || ticket.status === filters.status;
    const matchesOwnership =
      filters.ownership === "all" ||
      (filters.ownership === "assigned_to_me" && ticket.assignedTo === currentUserId) ||
      (filters.ownership === "open" && !ticket.assignedTo);
    const haystack = [
      ticket.id,
      ticket.customerId,
      ticket.customerName,
      ticket.summary,
      ticket.lastMessagePreview
    ]
      .filter(Boolean)
      .join(" ")
      .toLowerCase();
    return matchesSource && matchesStatus && matchesOwnership && (!query || haystack.includes(query));
  });
}

function SourceBadge({ source }: { source: ChannelType }) {
  const palette =
    source === "web"
      ? "border-sky-200 bg-sky-50 text-sky-800"
      : source === "facebook"
        ? "border-blue-200 bg-blue-50 text-blue-800"
        : "border-violet-200 bg-violet-50 text-violet-800";

  return (
    <span className={`inline-flex items-center border px-2 py-0.5 text-xs font-medium ${palette}`}>
      {sourceLabels[source]}
    </span>
  );
}

function errorMessage(error: unknown) {
  if (error instanceof ApiClientError) {
    if (error.status === 401) return "Your session expired. Sign in again to continue.";
    if (error.status === 403) return "You do not have permission to access this ticket.";
    if (error.status === 502) return "Message was saved, but outbound delivery failed.";
    return `Request failed with status ${error.status ?? "unknown"}.`;
  }
  if (error instanceof Error) return error.message;
  return "Something went wrong.";
}

export function UnifiedInbox() {
  const { user, accessToken, isMock } = useAuth();
  const [filters, setFilters] = useState<TicketFilters>(initialFilters);
  const [tickets, setTickets] = useState<TicketSummary[]>(() => mockTickets.map((ticket) => normalizeTicket(ticket)));
  const [messagesByTicket, setMessagesByTicket] = useState<Record<string, ConversationMessage[]>>(
    () => conversationMessages
  );
  const [selectedTicketId, setSelectedTicketId] = useState(mockTickets[0]?.id ?? "");
  const [isLoadingTickets, setIsLoadingTickets] = useState(false);
  const [isLoadingMessages, setIsLoadingMessages] = useState(false);
  const [actionId, setActionId] = useState<string | null>(null);
  const [composer, setComposer] = useState("");
  const [sendState, setSendState] = useState<"idle" | "sending" | "error">("idle");
  const [error, setError] = useState<string | null>(null);
  const [realtimeState, setRealtimeState] = useState<RealtimeState>(supabase ? "connecting" : "placeholder");
  const [realtimeRetryKey, setRealtimeRetryKey] = useState(0);

  const currentUserId = user?.id ?? "";
  const useMockData = isMock || !accessToken;

  const visibleTickets = useMemo(
    () => filterMockTickets(tickets, filters, currentUserId),
    [currentUserId, filters, tickets]
  );
  const selectedTicket = useMemo(
    () => tickets.find((ticket) => ticket.id === selectedTicketId) ?? visibleTickets[0] ?? tickets[0],
    [selectedTicketId, tickets, visibleTickets]
  );
  const selectedMessages = selectedTicket ? messagesByTicket[selectedTicket.id] ?? [] : [];

  const loadTickets = useCallback(async () => {
    if (!user) return;
    if (useMockData) {
      setTickets(filterMockTickets(mockTickets.map((ticket) => normalizeTicket(ticket)), filters, user.id));
      return;
    }
    setIsLoadingTickets(true);
    setError(null);
    try {
      const query = apiClient.buildTicketQuery(filters, user.id);
      const response = await apiClient.listTickets(query, accessToken ?? undefined);
      const normalized = response.items.map((ticket) =>
        normalizeTicket(ticket as Partial<TicketSummary> & Record<string, unknown>)
      );
      setTickets(normalized);
      if (normalized.length && !normalized.some((ticket) => ticket.id === selectedTicketId)) {
        setSelectedTicketId(normalized[0].id);
      }
    } catch (loadError) {
      setError(errorMessage(loadError));
    } finally {
      setIsLoadingTickets(false);
    }
  }, [accessToken, filters, selectedTicketId, useMockData, user]);

  const loadMessages = useCallback(
    async (ticketId: string) => {
      if (!ticketId || useMockData) return;
      setIsLoadingMessages(true);
      setError(null);
      try {
        const response = await apiClient.listMessages(ticketId, accessToken ?? undefined);
        setMessagesByTicket((current) => ({
          ...current,
          [ticketId]: response.items.map((message) =>
            normalizeMessage(message as Partial<ConversationMessage> & Record<string, unknown>)
          )
        }));
      } catch (loadError) {
        setError(errorMessage(loadError));
      } finally {
        setIsLoadingMessages(false);
      }
    },
    [accessToken, useMockData]
  );

  useEffect(() => {
    void loadTickets();
  }, [loadTickets]);

  useEffect(() => {
    if (selectedTicket?.id) {
      void loadMessages(selectedTicket.id);
    }
  }, [loadMessages, selectedTicket?.id]);

  useEffect(() => {
    if (!selectedTicket && visibleTickets[0]) {
      setSelectedTicketId(visibleTickets[0].id);
    }
  }, [selectedTicket, visibleTickets]);

  useEffect(() => {
    const realtimeClient = supabase;
    if (!realtimeClient) {
      setRealtimeState("placeholder");
      return;
    }
    setRealtimeState(realtimeRetryKey === 0 ? "connecting" : "retrying");
    const channel = realtimeClient
      .channel("web-admin-unified-inbox")
      .on("postgres_changes", { event: "*", schema: "public", table: "tickets" }, () => {
        void loadTickets();
      })
      .on("postgres_changes", { event: "*", schema: "public", table: "messages" }, (payload) => {
        const ticketId = String((payload.new as { ticket_id?: string })?.ticket_id ?? selectedTicket?.id ?? "");
        if (ticketId) void loadMessages(ticketId);
      })
      .subscribe((status) => {
        if (status === "SUBSCRIBED") setRealtimeState("connected");
        if (status === "CHANNEL_ERROR" || status === "TIMED_OUT" || status === "CLOSED") {
          setRealtimeState("disconnected");
        }
      });

    return () => {
      void realtimeClient.removeChannel(channel);
    };
  }, [loadMessages, loadTickets, realtimeRetryKey, selectedTicket?.id]);

  async function updateSelectedTicket(
    operation: string,
    applyMock: (ticket: TicketSummary) => TicketSummary,
    applyRemote: (ticket: TicketSummary) => Promise<TicketSummary>
  ) {
    if (!selectedTicket) return;
    setActionId(operation);
    setError(null);
    try {
      const updated = useMockData
        ? applyMock(selectedTicket)
        : normalizeTicket((await applyRemote(selectedTicket)) as Partial<TicketSummary> & Record<string, unknown>);
      setTickets((current) => current.map((ticket) => (ticket.id === updated.id ? updated : ticket)));
    } catch (actionError) {
      setError(errorMessage(actionError));
    } finally {
      setActionId(null);
    }
  }

  async function sendReply() {
    if (!selectedTicket || !composer.trim()) return;
    const content = composer.trim();
    setSendState("sending");
    setError(null);
    try {
      if (useMockData) {
        if (content.toLowerCase().includes("fail")) {
          throw new ApiClientError("Mock outbound failure", 502);
        }
        const message: ConversationMessage = {
          id: `mock-${Date.now()}`,
          ticketId: selectedTicket.id,
          senderType: "human",
          senderId: currentUserId,
          content,
          createdAt: new Date().toISOString()
        };
        setMessagesByTicket((current) => ({
          ...current,
          [selectedTicket.id]: [...(current[selectedTicket.id] ?? []), message]
        }));
        setTickets((current) =>
          current.map((ticket) =>
            ticket.id === selectedTicket.id
              ? { ...ticket, lastMessagePreview: content, updatedAt: message.createdAt }
              : ticket
          )
        );
      } else {
        const response = await apiClient.sendTicketMessage(selectedTicket.id, content, accessToken ?? undefined);
        const message = normalizeMessage(response.message as Partial<ConversationMessage> & Record<string, unknown>);
        setMessagesByTicket((current) => ({
          ...current,
          [selectedTicket.id]: [...(current[selectedTicket.id] ?? []), message]
        }));
      }
      setComposer("");
      setSendState("idle");
    } catch (sendError) {
      setSendState("error");
      setError(errorMessage(sendError));
    }
  }

  const canManageTickets = user ? canViewSection(user.role, "inbox") : false;

  return (
    <>
      <PageHeader
        title="Unified Inbox"
        description="Triage AI-handled conversations, urgent tickets, and human replies across Web, Facebook, and Email."
        actions={
          <button
            className="inline-flex h-9 items-center gap-2 border border-line bg-white px-3 text-sm font-medium text-slate-700 focus-ring"
            onClick={() => void loadTickets()}
            type="button"
          >
            {isLoadingTickets ? <Loader2 className="animate-spin" size={16} /> : <RefreshCw size={16} />}
            Refresh
          </button>
        }
      />

      <div className="border-b border-line bg-white px-4 py-3">
        {realtimeState === "placeholder" ? (
          <div className="text-sm text-slate-600">
            Realtime placeholder: set `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_ANON_KEY` to enable
            Supabase Realtime updates.
          </div>
        ) : realtimeState === "connected" ? (
          <div className="text-sm text-emerald-700">Realtime connected.</div>
        ) : (
          <div className="flex flex-wrap items-center gap-3 text-sm text-amber-800">
            <span className="inline-flex items-center gap-2">
              <WifiOff size={16} />
              Realtime {realtimeState === "disconnected" ? "disconnected" : "connecting"}.
            </span>
            <button
              className="inline-flex h-8 items-center gap-2 border border-amber-300 bg-amber-50 px-3 font-medium focus-ring"
              onClick={() => setRealtimeRetryKey((key) => key + 1)}
              type="button"
            >
              {realtimeState === "retrying" ? <Loader2 className="animate-spin" size={15} /> : <RefreshCw size={15} />}
              Retry
            </button>
          </div>
        )}
      </div>

      <div className="grid min-h-[calc(100vh-137px)] grid-cols-1 lg:grid-cols-[390px_minmax(0,1fr)]">
        <aside className="border-r border-line bg-white">
          <div className="space-y-3 border-b border-line p-4">
            <label className="relative block">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" size={16} />
              <input
                className="h-10 w-full border border-line pl-9 pr-3 text-sm focus-ring"
                onChange={(event) => setFilters((current) => ({ ...current, search: event.target.value }))}
                placeholder="Search tickets"
                value={filters.search}
              />
            </label>
            <div className="grid grid-cols-3 gap-2">
              <select
                className="h-9 border border-line bg-white px-2 text-sm focus-ring"
                onChange={(event) => setFilters((current) => ({ ...current, source: event.target.value as TicketFilters["source"] }))}
                value={filters.source}
              >
                <option value="all">All sources</option>
                <option value="web">Web</option>
                <option value="facebook">Facebook</option>
                <option value="email">Email</option>
              </select>
              <select
                className="h-9 border border-line bg-white px-2 text-sm focus-ring"
                onChange={(event) => setFilters((current) => ({ ...current, status: event.target.value as TicketFilters["status"] }))}
                value={filters.status}
              >
                <option value="all">All status</option>
                <option value="open">Open</option>
                <option value="in_progress">In progress</option>
                <option value="pending">Pending</option>
                <option value="resolved">Resolved</option>
              </select>
              <select
                className="h-9 border border-line bg-white px-2 text-sm focus-ring"
                onChange={(event) =>
                  setFilters((current) => ({ ...current, ownership: event.target.value as TicketFilters["ownership"] }))
                }
                value={filters.ownership}
              >
                <option value="all">All owners</option>
                <option value="open">Open queue</option>
                <option value="assigned_to_me">Mine</option>
              </select>
            </div>
          </div>

          <div className="max-h-[calc(100vh-260px)] overflow-y-auto">
            {visibleTickets.length ? (
              visibleTickets.map((ticket) => {
                const active = selectedTicket?.id === ticket.id;
                return (
                  <button
                    className={`w-full border-b border-line p-4 text-left focus-ring ${
                      active ? "bg-teal-50" : "bg-white hover:bg-slate-50"
                    }`}
                    key={ticket.id}
                    onClick={() => setSelectedTicketId(ticket.id)}
                    type="button"
                  >
                    <div className="flex items-start justify-between gap-3">
                      <div className="min-w-0">
                        <div className="truncate text-sm font-semibold text-ink">{ticket.customerName}</div>
                        <div className="mt-0.5 truncate text-xs text-slate-500">{ticket.customerId || ticket.id}</div>
                      </div>
                      <div className="shrink-0 text-xs text-slate-500">{formatTime(ticket.updatedAt)}</div>
                    </div>
                    <div className="mt-3 flex flex-wrap items-center gap-2">
                      <SourceBadge source={ticket.source} />
                      <StatusBadge value={ticket.status} />
                      <StatusBadge value={ticket.intent} />
                    </div>
                    <p className="mt-3 line-clamp-2 text-sm text-slate-700">
                      {ticket.lastMessagePreview || ticket.summary}
                    </p>
                  </button>
                );
              })
            ) : (
              <div className="p-6 text-sm text-slate-500">No tickets match these filters.</div>
            )}
          </div>
        </aside>

        <section className="flex min-h-[680px] flex-col bg-surface">
          {selectedTicket ? (
            <>
              <div className="border-b border-line bg-white p-4">
                <div className="flex flex-col gap-3 xl:flex-row xl:items-center xl:justify-between">
                  <div>
                    <div className="flex flex-wrap items-center gap-2">
                      <h2 className="text-lg font-semibold text-ink">{selectedTicket.customerName}</h2>
                      <SourceBadge source={selectedTicket.source} />
                      <StatusBadge value={selectedTicket.status} />
                      <StatusBadge value={selectedTicket.intent} />
                    </div>
                    <div className="mt-1 text-sm text-slate-500">
                      {selectedTicket.id} · {selectedTicket.customerId || "Unknown customer id"} · Updated{" "}
                      {formatTime(selectedTicket.updatedAt)}
                    </div>
                  </div>
                  <div className="flex flex-wrap items-center gap-2">
                    <button
                      className="inline-flex h-9 items-center gap-2 border border-line bg-white px-3 text-sm font-medium text-slate-700 focus-ring disabled:cursor-not-allowed disabled:opacity-50"
                      disabled={!canManageTickets || actionId !== null}
                      onClick={() =>
                        void updateSelectedTicket(
                          "assign",
                          (ticket) => ({ ...ticket, assignedTo: currentUserId, status: "in_progress" }),
                          (ticket) => apiClient.assignTicket(ticket.id, currentUserId, accessToken ?? undefined)
                        )
                      }
                      type="button"
                    >
                      {actionId === "assign" ? <Loader2 className="animate-spin" size={16} /> : <UserCheck size={16} />}
                      Assign to me
                    </button>
                    <button
                      className="inline-flex h-9 items-center gap-2 border border-line bg-white px-3 text-sm font-medium text-slate-700 focus-ring disabled:cursor-not-allowed disabled:opacity-50"
                      disabled={!canManageTickets || actionId !== null || selectedTicket.status === "resolved"}
                      onClick={() =>
                        void updateSelectedTicket(
                          "in_progress",
                          (ticket) => ({ ...ticket, status: "in_progress" }),
                          (ticket) => apiClient.updateTicket(ticket.id, { status: "in_progress" }, accessToken ?? undefined)
                        )
                      }
                      type="button"
                    >
                      {actionId === "in_progress" ? <Loader2 className="animate-spin" size={16} /> : <Clock3 size={16} />}
                      Mark in progress
                    </button>
                    {selectedTicket.status === "resolved" ? (
                      <button
                        className="inline-flex h-9 items-center gap-2 bg-brand px-3 text-sm font-semibold text-white focus-ring disabled:cursor-not-allowed disabled:bg-slate-400"
                        disabled={!canManageTickets || actionId !== null}
                        onClick={() =>
                          void updateSelectedTicket(
                            "reopen",
                            (ticket) => ({ ...ticket, status: "open" }),
                            (ticket) => apiClient.reopenTicket(ticket.id, accessToken ?? undefined)
                          )
                        }
                        type="button"
                      >
                        {actionId === "reopen" ? <Loader2 className="animate-spin" size={16} /> : <RotateCcw size={16} />}
                        Reopen
                      </button>
                    ) : (
                      <button
                        className="inline-flex h-9 items-center gap-2 bg-brand px-3 text-sm font-semibold text-white focus-ring disabled:cursor-not-allowed disabled:bg-slate-400"
                        disabled={!canManageTickets || actionId !== null}
                        onClick={() =>
                          void updateSelectedTicket(
                            "resolve",
                            (ticket) => ({ ...ticket, status: "resolved" }),
                            (ticket) => apiClient.resolveTicket(ticket.id, accessToken ?? undefined)
                          )
                        }
                        type="button"
                      >
                        {actionId === "resolve" ? <Loader2 className="animate-spin" size={16} /> : <CheckCircle2 size={16} />}
                        Resolve
                      </button>
                    )}
                  </div>
                </div>
              </div>

              {error ? (
                <div className="border-b border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-800">{error}</div>
              ) : null}

              <div className="flex-1 space-y-4 overflow-y-auto p-4">
                {isLoadingMessages ? (
                  <div className="flex items-center gap-2 text-sm text-slate-500">
                    <Loader2 className="animate-spin" size={16} />
                    Loading messages...
                  </div>
                ) : selectedMessages.length ? (
                  selectedMessages.map((message) => {
                    const human = message.senderType === "human";
                    const bot = message.senderType === "bot";
                    return (
                      <div className={`flex ${human || bot ? "justify-end" : "justify-start"}`} key={message.id}>
                        <div
                          className={`max-w-3xl border p-3 text-sm shadow-sm ${
                            human
                              ? "border-teal-200 bg-teal-50 text-slate-900"
                              : bot
                                ? "border-indigo-200 bg-indigo-50 text-slate-900"
                                : "border-line bg-white text-slate-800"
                          }`}
                        >
                          <div className="mb-1 flex items-center gap-2 text-xs font-medium uppercase text-slate-500">
                            <MessageSquare size={13} />
                            {message.senderType}
                            <span className="font-normal normal-case">{formatTime(message.createdAt)}</span>
                          </div>
                          <p className="whitespace-pre-wrap leading-6">{message.content}</p>
                        </div>
                      </div>
                    );
                  })
                ) : (
                  <div className="text-sm text-slate-500">No messages found for this ticket.</div>
                )}
              </div>

              <div className="border-t border-line bg-white p-4">
                {sendState === "error" ? (
                  <div className="mb-3 text-sm text-rose-700">Reply was not delivered. Edit and try again.</div>
                ) : null}
                <label className="sr-only" htmlFor="reply">
                  Reply
                </label>
                <textarea
                  className="min-h-28 w-full resize-none border border-line p-3 text-sm focus-ring"
                  disabled={sendState === "sending" || selectedTicket.status === "resolved"}
                  id="reply"
                  onChange={(event) => setComposer(event.target.value)}
                  placeholder={
                    selectedTicket.status === "resolved" ? "Reopen the ticket before replying." : "Write a human reply..."
                  }
                  value={composer}
                />
                <div className="mt-3 flex justify-end">
                  <button
                    className="inline-flex h-9 items-center gap-2 bg-brand px-3 text-sm font-semibold text-white focus-ring disabled:cursor-not-allowed disabled:bg-slate-400"
                    disabled={!composer.trim() || sendState === "sending" || selectedTicket.status === "resolved"}
                    onClick={() => void sendReply()}
                    type="button"
                  >
                    {sendState === "sending" ? <Loader2 className="animate-spin" size={16} /> : <Send size={16} />}
                    Send reply
                  </button>
                </div>
              </div>
            </>
          ) : (
            <div className="p-6 text-sm text-slate-500">Select a ticket to view the conversation.</div>
          )}
        </section>
      </div>
    </>
  );
}
