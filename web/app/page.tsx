"use client";

import {
  Activity,
  BarChart3,
  Bell,
  Bot,
  CircleAlert,
  Clock3,
  FileText,
  Globe2,
  Headphones,
  Inbox,
  Loader2,
  LogOut,
  Mail,
  MessageCircle,
  PanelLeft,
  Phone,
  Plus,
  Search,
  Send,
  Settings,
  ShieldCheck,
  Sparkles,
  Upload,
  UserRound,
  UsersRound,
  Wifi,
  Trash2
} from "lucide-react";
import type { LucideIcon } from "lucide-react";
import type { Session } from "@supabase/supabase-js";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";

import { apiFetch, publicApiFetch, type ApiResponse } from "../lib/api";
import { getSupabaseClient } from "../lib/supabase";

type TicketStatus = "open" | "in_progress" | "pending" | "resolved";
type Channel = "web" | "facebook" | "email";
type TicketIntent = "question" | "complaint" | "spam" | null;
type View = "inbox" | "analytics" | "knowledge" | "staff" | "channels";

type UserProfile = {
  id: string;
  email: string;
  full_name: string;
  role: "super_admin" | "agent";
  status: "online" | "offline" | "disabled";
};

type TicketRow = {
  id: string;
  customer_id: string;
  customer_name: string | null;
  source: Channel;
  status: TicketStatus;
  intent: TicketIntent;
  summary: string | null;
  assigned_to: string | null;
  created_at: string;
  resolved_at: string | null;
};

type MessageRow = {
  id: string;
  ticket_id: string;
  sender_type: "customer" | "bot" | "human";
  sender_id: string;
  content: string;
  created_at: string;
};

type DocumentRow = {
  id: string;
  name: string;
  file_type: string;
  embedding_status: "processing" | "ready" | "error";
  chunk_count: number | null;
  uploaded_by: string;
  created_at: string;
};

type ChannelRow = {
  id: string;
  type: Channel;
  is_active: boolean;
  connected_at: string | null;
};

type Stats = {
  total_tickets_today: number;
  open_tickets: number;
  resolved_tickets_today: number;
  ai_handled_percent: number;
};

const navItems: Array<{ Icon: LucideIcon; label: string; view: View }> = [
  { Icon: Inbox, label: "Unified Inbox", view: "inbox" },
  { Icon: BarChart3, label: "Analytics", view: "analytics" },
  { Icon: FileText, label: "Knowledge Base", view: "knowledge" },
  { Icon: UsersRound, label: "Staff", view: "staff" },
  { Icon: Settings, label: "Channels", view: "channels" }
];

function channelIcon(channel: Channel) {
  if (channel === "web") return <Globe2 size={14} />;
  if (channel === "facebook") return <MessageCircle size={14} />;
  return <Mail size={14} />;
}

function statusLabel(status: TicketStatus) {
  if (status === "in_progress") return "In progress";
  return status[0].toUpperCase() + status.slice(1);
}

function intentLabel(intent: TicketIntent) {
  if (!intent) return "Unclassified";
  if (intent === "question") return "FAQ";
  return intent[0].toUpperCase() + intent.slice(1);
}

function priorityFor(ticket: TicketRow) {
  if (ticket.intent === "complaint") return "urgent";
  if (ticket.status === "pending") return "medium";
  return "low";
}

function relativeTime(value: string) {
  const created = new Date(value).getTime();
  const delta = Math.max(0, Date.now() - created);
  const minutes = Math.floor(delta / 60000);

  if (minutes < 1) return "now";
  if (minutes < 60) return `${minutes}m ago`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours}h ago`;
  return `${Math.floor(hours / 24)}d ago`;
}

function messageName(message: MessageRow, profile: UserProfile | null) {
  if (message.sender_type === "bot") return "AI Agent";
  if (message.sender_type === "human") return profile?.full_name ?? "Staff";
  return "Customer";
}

export default function SmartHelpdeskPage() {
  const [session, setSession] = useState<Session | null>(null);
  const [profile, setProfile] = useState<UserProfile | null>(null);
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [authMode, setAuthMode] = useState<"login" | "signup">("login");
  const [authLoading, setAuthLoading] = useState(true);
  const [activeView, setActiveView] = useState<View>("inbox");
  const [tickets, setTickets] = useState<TicketRow[]>([]);
  const [messages, setMessages] = useState<MessageRow[]>([]);
  const [documents, setDocuments] = useState<DocumentRow[]>([]);
  const [staff, setStaff] = useState<UserProfile[]>([]);
  const [channels, setChannels] = useState<ChannelRow[]>([]);
  const [stats, setStats] = useState<Stats | null>(null);
  const [selectedTicketId, setSelectedTicketId] = useState<string | null>(null);
  const [channelFilter, setChannelFilter] = useState<Channel | "all">("all");
  const [search, setSearch] = useState("");
  const [reply, setReply] = useState("");
  const [newMessage, setNewMessage] = useState("Cho mình hỏi phí ship nội thành là bao nhiêu?");
  const [notice, setNotice] = useState("Connect Supabase, run the schema, then sign in.");
  const [loading, setLoading] = useState(false);
  const [apiStatus, setApiStatus] = useState<"checking" | "online" | "offline">("checking");
  const fileInputRef = useRef<HTMLInputElement>(null);

  const selectedTicket = tickets.find((ticket) => ticket.id === selectedTicketId) ?? tickets[0] ?? null;

  useEffect(() => {
    let client;
    try {
      client = getSupabaseClient();
    } catch (error) {
      queueMicrotask(() => {
        setNotice(error instanceof Error ? error.message : "Supabase env vars are missing.");
        setAuthLoading(false);
      });
      return;
    }

    client.auth.getSession().then(({ data }) => {
      setSession(data.session);
      setAuthLoading(false);
    });

    const { data: listener } = client.auth.onAuthStateChange((_event, nextSession) => {
      setSession(nextSession);
    });

    return () => listener.subscription.unsubscribe();
  }, []);

  useEffect(() => {
    const backendUrl = process.env.NEXT_PUBLIC_BACKEND_URL ?? "http://localhost:8000";

    fetch(backendUrl)
      .then((response) => setApiStatus(response.ok ? "online" : "offline"))
      .catch(() => setApiStatus("offline"));
  }, []);

  const loadTicketDetail = useCallback(
    async (ticketId: string, activeSession = session) => {
      if (!activeSession) return;
      const detail = await apiFetch<ApiResponse<{ ticket: TicketRow; messages: MessageRow[] }>>(
        `/api/v1/tickets/${ticketId}`,
        activeSession
      );
      setMessages(detail.data.messages);
    },
    [session]
  );

  const loadData = useCallback(
    async (activeSession = session) => {
      if (!activeSession) return;

      setLoading(true);
      try {
        const me = await apiFetch<ApiResponse<UserProfile>>("/api/v1/users/me", activeSession);
        setProfile(me.data);

        const ticketResult = await apiFetch<ApiResponse<{ items: TicketRow[]; total: number }>>(
          "/api/v1/tickets?limit=50",
          activeSession
        );
        setTickets(ticketResult.data.items);
        const nextSelected = selectedTicketId ?? ticketResult.data.items[0]?.id ?? null;
        setSelectedTicketId(nextSelected);

        if (nextSelected) {
          await loadTicketDetail(nextSelected, activeSession);
        } else {
          setMessages([]);
        }

        const documentResult = await apiFetch<ApiResponse<DocumentRow[]>>("/api/v1/documents", activeSession);
        setDocuments(documentResult.data);

        const channelResult = await apiFetch<ApiResponse<ChannelRow[]>>("/api/v1/channels", activeSession);
        setChannels(channelResult.data);

        if (me.data.role === "super_admin") {
          const statsResult = await apiFetch<ApiResponse<Stats>>("/api/v1/tickets/stats/dashboard", activeSession);
          setStats(statsResult.data);

          const staffResult = await apiFetch<ApiResponse<{ items: UserProfile[] }>>(
            "/api/v1/users?limit=50",
            activeSession
          );
          setStaff(staffResult.data.items);
        } else {
          setStats(null);
          setStaff([me.data]);
        }

        setNotice("Loaded live data from the backend.");
      } catch (error) {
        setNotice(error instanceof Error ? error.message : "Could not load backend data.");
      } finally {
        setLoading(false);
      }
    },
    [loadTicketDetail, selectedTicketId, session]
  );

  useEffect(() => {
    if (session) {
      loadData(session);
    } else {
      setProfile(null);
      setTickets([]);
      setMessages([]);
      setDocuments([]);
      setStaff([]);
      setChannels([]);
      setStats(null);
      setSelectedTicketId(null);
    }
  }, [loadData, session]);

  useEffect(() => {
    if (selectedTicketId && session) {
      loadTicketDetail(selectedTicketId, session).catch((error) => {
        setNotice(error instanceof Error ? error.message : "Could not load messages.");
      });
    }
  }, [loadTicketDetail, selectedTicketId, session]);

  const filteredTickets = useMemo(() => {
    const term = search.trim().toLowerCase();

    return tickets.filter((ticket) => {
      const lastMessage = ticket.summary ?? ticket.customer_id;
      const matchesChannel = channelFilter === "all" || ticket.source === channelFilter;
      const matchesSearch =
        !term ||
        ticket.id.toLowerCase().includes(term) ||
        ticket.customer_id.toLowerCase().includes(term) ||
        (ticket.customer_name ?? "").toLowerCase().includes(term) ||
        lastMessage.toLowerCase().includes(term);

      return matchesChannel && matchesSearch;
    });
  }, [channelFilter, search, tickets]);

  const computedMetrics = useMemo(
    () => [
      { Icon: Activity, label: "Tickets today", value: String(stats?.total_tickets_today ?? tickets.length), delta: "live" },
      { Icon: Bot, label: "AI resolved", value: `${stats?.ai_handled_percent ?? 0}%`, delta: "RAG" },
      { Icon: Clock3, label: "Open tickets", value: String(stats?.open_tickets ?? tickets.filter((ticket) => ticket.status !== "resolved").length), delta: "now" },
      { Icon: CircleAlert, label: "Urgent open", value: String(tickets.filter((ticket) => ticket.intent === "complaint" && ticket.status !== "resolved").length), delta: "now" }
    ],
    [stats, tickets]
  );

  async function handleAuthSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setLoading(true);

    try {
      const result =
        authMode === "login"
          ? await getSupabaseClient().auth.signInWithPassword({ email, password })
          : await getSupabaseClient().auth.signUp({
              email,
              password,
              options: {
                data: {
                  full_name: email.split("@")[0],
                  role: "agent"
                }
              }
            });

      if (result.error) throw result.error;
      setNotice(authMode === "signup" ? "Account created. If email confirmation is enabled, confirm it before login." : "Signed in.");
    } catch (error) {
      setNotice(error instanceof Error ? error.message : "Authentication failed.");
    } finally {
      setLoading(false);
    }
  }

  async function handleLogout() {
    await getSupabaseClient().auth.signOut();
    setNotice("Signed out.");
  }

  async function handleCreateIncoming(channel: Channel = "web", overrideMessage?: string) {
    const content = (overrideMessage ?? newMessage).trim();
    if (!content) {
      setNotice("Enter a customer message first.");
      return;
    }

    setLoading(true);
    try {
      await publicApiFetch<ApiResponse<{ ticket_id: string }>>("/api/v1/messages/incoming", {
        method: "POST",
        body: JSON.stringify({
          customer_id: `web-${Date.now()}`,
          customer_name: "Website visitor",
          source: channel,
          content
        })
      });
      setNotice("Incoming customer message created. Refreshing tickets.");
      if (session) await loadData(session);
    } catch (error) {
      setNotice(error instanceof Error ? error.message : "Could not create incoming message.");
    } finally {
      setLoading(false);
    }
  }

  async function handleSendReply() {
    if (!session || !selectedTicket) return;
    const content = reply.trim();
    if (!content) {
      setNotice("Reply is empty.");
      return;
    }

    setLoading(true);
    try {
      await apiFetch<ApiResponse<MessageRow>>("/api/v1/messages", session, {
        method: "POST",
        body: JSON.stringify({
          ticket_id: selectedTicket.id,
          content
        })
      });
      setReply("");
      await loadData(session);
      setNotice("Reply sent through the backend.");
    } catch (error) {
      setNotice(error instanceof Error ? error.message : "Could not send reply.");
    } finally {
      setLoading(false);
    }
  }

  async function handleUpdateTicket(status: TicketStatus) {
    if (!session || !selectedTicket) return;

    setLoading(true);
    try {
      await apiFetch<ApiResponse<TicketRow>>(`/api/v1/tickets/${selectedTicket.id}`, session, {
        method: "PATCH",
        body: JSON.stringify({ status })
      });
      await loadData(session);
      setNotice(`${selectedTicket.id} updated to ${statusLabel(status)}.`);
    } catch (error) {
      setNotice(error instanceof Error ? error.message : "Could not update ticket.");
    } finally {
      setLoading(false);
    }
  }

  async function handleUpload(files: FileList | null) {
    if (!session) return;
    const file = files?.[0];
    if (!file) return;

    const form = new FormData();
    form.append("file", file);

    setLoading(true);
    try {
      await apiFetch<ApiResponse<{ document_id: string }>>("/api/v1/documents", session, {
        method: "POST",
        body: form
      });
      await loadData(session);
      setNotice(`${file.name} uploaded to Supabase Storage.`);
    } catch (error) {
      setNotice(error instanceof Error ? error.message : "Could not upload document.");
    } finally {
      setLoading(false);
    }
  }

  async function handleDeleteDocument(document: DocumentRow) {
    if (!session) return;

    const confirmed = window.confirm(`Delete ${document.name} from the knowledge base?`);
    if (!confirmed) return;

    setLoading(true);
    try {
      await apiFetch<ApiResponse<null>>(`/api/v1/documents/${document.id}`, session, {
        method: "DELETE"
      });
      await loadData(session);
      setNotice(`${document.name} deleted from the knowledge base.`);
    } catch (error) {
      setNotice(error instanceof Error ? error.message : "Could not delete document.");
    } finally {
      setLoading(false);
    }
  }

  if (authLoading) {
    return (
      <main className="auth-shell">
        <Loader2 className="spin" size={24} />
      </main>
    );
  }

  if (!session) {
    return (
      <main className="auth-shell">
        <form className="auth-card" onSubmit={handleAuthSubmit}>
          <div className="brand">
            <div className="brand-mark">
              <Headphones size={22} />
            </div>
            <div>
              <strong>Smart Helpdesk</strong>
              <span>Supabase login required</span>
            </div>
          </div>
          <h1>{authMode === "login" ? "Sign in" : "Create account"}</h1>
          <input placeholder="Email" type="email" value={email} onChange={(event) => setEmail(event.target.value)} required />
          <input placeholder="Password" type="password" value={password} onChange={(event) => setPassword(event.target.value)} required />
          <button className="primary-button" type="submit" disabled={loading}>
            {loading ? <Loader2 className="spin" size={16} /> : null}
            {authMode === "login" ? "Sign in" : "Sign up"}
          </button>
          <button className="ghost-button" type="button" onClick={() => setAuthMode(authMode === "login" ? "signup" : "login")}>
            {authMode === "login" ? "Need an account?" : "Already have an account?"}
          </button>
          <p>{notice}</p>
        </form>
      </main>
    );
  }

  return (
    <main className="app-shell">
      <aside className="sidebar">
        <div className="brand">
          <div className="brand-mark">
            <Headphones size={22} />
          </div>
          <div>
            <strong>Smart Helpdesk</strong>
            <span>{profile ? `${profile.full_name} · ${profile.role}` : "Loading profile"}</span>
          </div>
        </div>

        <nav className="nav-list" aria-label="Main navigation">
          {navItems.map(({ Icon, label, view }) => (
            <button
              className={activeView === view ? "nav-item active" : "nav-item"}
              key={label}
              onClick={() => setActiveView(view)}
            >
              <Icon size={18} />
              <span>{label}</span>
            </button>
          ))}
        </nav>

        <div className="ai-card">
          <div className="ai-card-top">
            <Bot size={18} />
            <span>Backend {apiStatus}</span>
          </div>
          <strong>{apiStatus === "online" ? "ON" : apiStatus === "offline" ? "OFF" : "..."}</strong>
          <p>Data is loaded through FastAPI with your Supabase session token.</p>
        </div>
      </aside>

      <section className="content">
        <header className="topbar">
          <div>
            <p className="eyebrow">Owner dashboard</p>
            <h1>Customer support command center</h1>
          </div>
          <div className="topbar-actions">
            <div className="search">
              <Search size={16} />
              <input
                aria-label="Search tickets"
                placeholder="Search tickets, customers, messages"
                value={search}
                onChange={(event) => setSearch(event.target.value)}
              />
            </div>
            <button className="icon-button" aria-label="Notifications" onClick={() => setNotice("Notifications are stored in Supabase after AI escalation.")}>
              <Bell size={18} />
              <span className="dot" />
            </button>
            <button className="icon-button" aria-label="Sign out" onClick={handleLogout}>
              <LogOut size={18} />
            </button>
          </div>
        </header>

        <div className={`status-banner ${apiStatus}`}>
          <span>{loading ? "Working..." : notice}</span>
          <small>Backend: {apiStatus}</small>
        </div>

        <section className="metrics" aria-label="Support metrics">
          {computedMetrics.map(({ Icon, label, value, delta }) => (
            <article className="metric" key={label}>
              <div>
                <span>{label}</span>
                <strong>{value}</strong>
              </div>
              <div className="metric-icon">
                <Icon size={18} />
              </div>
              <small>{delta}</small>
            </article>
          ))}
        </section>

        {activeView === "analytics" && <AnalyticsView tickets={tickets} stats={stats} />}
        {activeView === "knowledge" && (
          <KnowledgeView
            documents={documents}
            fileInputRef={fileInputRef}
            onUpload={handleUpload}
            onDelete={handleDeleteDocument}
            loading={loading}
          />
        )}
        {activeView === "staff" && <StaffView staff={staff} />}
        {activeView === "channels" && <ChannelsView channels={channels} />}
        {activeView === "inbox" && (
          <section className="workspace">
            <div className="ticket-list">
              <div className="section-head">
                <div>
                  <p className="eyebrow">Unified inbox</p>
                  <h2>Live tickets</h2>
                </div>
                <button className="icon-button" aria-label="Refresh tickets" onClick={() => loadData(session)}>
                  <PanelLeft size={17} />
                </button>
              </div>

              <div className="filters" aria-label="Channel filters">
                {(["all", "web", "facebook", "email"] as const).map((channel) => (
                  <button
                    className={channelFilter === channel ? "filter active" : "filter"}
                    key={channel}
                    onClick={() => setChannelFilter(channel)}
                  >
                    {channel === "all" ? <Inbox size={14} /> : channelIcon(channel)}
                    <span>{channel === "all" ? "All" : channel}</span>
                  </button>
                ))}
              </div>

              <div className="new-message-box">
                <textarea value={newMessage} onChange={(event) => setNewMessage(event.target.value)} />
                <button className="primary-button" onClick={() => handleCreateIncoming("web")}>
                  <Plus size={16} />
                  Simulate customer
                </button>
              </div>

              <div className="tickets">
                {filteredTickets.length === 0 && <div className="empty-state">No tickets yet. Simulate a customer message.</div>}
                {filteredTickets.map((ticket) => (
                  <button
                    className={selectedTicket?.id === ticket.id ? "ticket active" : "ticket"}
                    key={ticket.id}
                    onClick={() => setSelectedTicketId(ticket.id)}
                  >
                    <div className="ticket-row">
                      <span className={`priority ${priorityFor(ticket)}`}>{priorityFor(ticket)}</span>
                      <span>{relativeTime(ticket.created_at)}</span>
                    </div>
                    <strong>{ticket.customer_name ?? ticket.customer_id}</strong>
                    <p>{ticket.summary ?? intentLabel(ticket.intent)}</p>
                    <div className="ticket-row">
                      <span className="channel">
                        {channelIcon(ticket.source)}
                        {ticket.source}
                      </span>
                      <span>{statusLabel(ticket.status)}</span>
                    </div>
                  </button>
                ))}
              </div>
            </div>

            <div className="conversation">
              {selectedTicket ? (
                <>
                  <div className="conversation-head">
                    <div>
                      <p className="eyebrow">{selectedTicket.id}</p>
                      <h2>{selectedTicket.customer_name ?? selectedTicket.customer_id}</h2>
                      <span className="conversation-meta">
                        {channelIcon(selectedTicket.source)}
                        {selectedTicket.source} · {intentLabel(selectedTicket.intent)}
                      </span>
                    </div>
                    <div className="handoff">
                      <ShieldCheck size={16} />
                      {statusLabel(selectedTicket.status)}
                    </div>
                  </div>

                  <div className="chat-feed">
                    {messages.map((message) => (
                      <div className={`message ${message.sender_type === "bot" ? "ai" : message.sender_type}`} key={message.id}>
                        <div className="message-meta">
                          <span>{messageName(message, profile)}</span>
                          <span>{relativeTime(message.created_at)}</span>
                        </div>
                        <p>{message.content}</p>
                      </div>
                    ))}
                  </div>

                  <div className="assistant-panel">
                    <div>
                      <span>
                        <Sparkles size={15} />
                        Reply composer
                      </span>
                      <small>{selectedTicket.assigned_to ? "Assigned" : "Unassigned"}</small>
                    </div>
                    <textarea
                      aria-label="Reply draft"
                      placeholder="Write a reply..."
                      value={reply}
                      onChange={(event) => setReply(event.target.value)}
                    />
                    <div className="reply-actions">
                      <button className="ghost-button" onClick={() => handleUpdateTicket("in_progress")}>Take over</button>
                      <button className="ghost-button" onClick={() => handleUpdateTicket("resolved")}>Resolve</button>
                      <button className="primary-button" onClick={handleSendReply}>
                        <Send size={16} />
                        Send reply
                      </button>
                    </div>
                  </div>
                </>
              ) : (
                <div className="empty-state">Select or create a ticket.</div>
              )}
            </div>

            <aside className="right-panel">
              <KnowledgePanel
                documents={documents}
                fileInputRef={fileInputRef}
                onUpload={handleUpload}
                onDelete={handleDeleteDocument}
                loading={loading}
              />
              <StaffView staff={staff} compact />
              <section className="widget-preview">
                <div className="widget-head">
                  <Phone size={17} />
                  Customer widget
                  <span>
                    <Wifi size={12} />
                    live
                  </span>
                </div>
                <div className="widget-body">
                  <p>Xin chào! Mình có thể hỗ trợ gì cho bạn hôm nay?</p>
                  <button onClick={() => {
                    const message = "Cho mình hỏi phí ship nội thành là bao nhiêu?";
                    setNewMessage(message);
                    handleCreateIncoming("web", message);
                  }}>Hỏi phí ship</button>
                  <button onClick={() => {
                    const message = "Đơn hàng của mình bị lỗi, shop hỗ trợ ngay giúp mình.";
                    setNewMessage(message);
                    handleCreateIncoming("web", message);
                  }}>Báo lỗi đơn hàng</button>
                </div>
              </section>
            </aside>
          </section>
        )}
      </section>
    </main>
  );
}

function KnowledgePanel({
  documents,
  fileInputRef,
  onUpload,
  onDelete,
  loading
}: {
  documents: DocumentRow[];
  fileInputRef: React.RefObject<HTMLInputElement | null>;
  onUpload: (files: FileList | null) => void;
  onDelete: (document: DocumentRow) => void;
  loading: boolean;
}) {
  return (
    <section>
      <div className="section-head compact">
        <div>
          <p className="eyebrow">Knowledge base</p>
          <h2>Documents</h2>
        </div>
        <button className="icon-button" aria-label="Upload document" onClick={() => fileInputRef.current?.click()}>
          <Upload size={16} />
        </button>
        <input
          ref={fileInputRef}
          className="file-input"
          type="file"
          accept=".pdf,.docx,.txt"
          onChange={(event) => onUpload(event.target.files)}
        />
      </div>
      <div className="doc-list">
        {documents.length === 0 && <div className="empty-state">No documents uploaded.</div>}
        {documents.map((doc) => (
          <div className="doc" key={doc.id}>
            <FileText size={17} />
            <div>
              <strong>{doc.name}</strong>
              <span>{doc.chunk_count ?? 0} chunks · {doc.file_type}</span>
            </div>
            <em className={doc.embedding_status === "ready" ? "ready" : "processing"}>{doc.embedding_status}</em>
            <button
              className="icon-button danger doc-delete"
              aria-label={`Delete ${doc.name}`}
              title={`Delete ${doc.name}`}
              disabled={loading}
              onClick={() => onDelete(doc)}
            >
              <Trash2 size={15} />
            </button>
          </div>
        ))}
      </div>
    </section>
  );
}

function KnowledgeView(props: {
  documents: DocumentRow[];
  fileInputRef: React.RefObject<HTMLInputElement | null>;
  onUpload: (files: FileList | null) => void;
  onDelete: (document: DocumentRow) => void;
  loading: boolean;
}) {
  return (
    <section className="panel-view">
      <KnowledgePanel {...props} />
    </section>
  );
}

function StaffView({ staff, compact = false }: { staff: UserProfile[]; compact?: boolean }) {
  const content = (
    <section>
      <div className="section-head compact">
        <div>
          <p className="eyebrow">Team</p>
          <h2>Staff status</h2>
        </div>
      </div>
      <div className="staff-list">
        {staff.length === 0 && <div className="empty-state">Only super_admin can list all staff.</div>}
        {staff.map((member) => (
          <div className="staff" key={member.id}>
            <div className="avatar">
              <UserRound size={15} />
            </div>
            <div>
              <strong>{member.full_name}</strong>
              <span>{member.role} · {member.email}</span>
            </div>
            <i className={member.status}>{member.status}</i>
          </div>
        ))}
      </div>
    </section>
  );

  return compact ? content : <section className="panel-view">{content}</section>;
}

function AnalyticsView({ tickets, stats }: { tickets: TicketRow[]; stats: Stats | null }) {
  const byStatus = (["open", "in_progress", "pending", "resolved"] as const).map((status) => ({
    label: statusLabel(status),
    count: tickets.filter((ticket) => ticket.status === status).length
  }));

  return (
    <section className="panel-view">
      <div className="section-head">
        <div>
          <p className="eyebrow">Analytics</p>
          <h2>Ticket distribution</h2>
        </div>
      </div>
      <div className="analytics-grid">
        {byStatus.map((item) => (
          <article className="analytics-item" key={item.label}>
            <span>{item.label}</span>
            <strong>{item.count}</strong>
          </article>
        ))}
        <article className="analytics-item">
          <span>Resolved today</span>
          <strong>{stats?.resolved_tickets_today ?? 0}</strong>
        </article>
      </div>
    </section>
  );
}

function ChannelsView({ channels }: { channels: ChannelRow[] }) {
  return (
    <section className="panel-view">
      <div className="section-head">
        <div>
          <p className="eyebrow">Channels</p>
          <h2>Connection status</h2>
        </div>
      </div>
      <div className="channel-grid">
        {channels.length === 0 && <div className="empty-state">No channel rows found. Run the Supabase schema.</div>}
        {channels.map((channel) => (
          <article className="channel-card" key={channel.id}>
            <span className="channel">
              {channelIcon(channel.type)}
              {channel.type}
            </span>
            <strong>{channel.is_active ? "Active" : "Needs setup"}</strong>
          </article>
        ))}
      </div>
    </section>
  );
}
