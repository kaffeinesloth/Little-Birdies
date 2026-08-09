import type {
  ConversationMessage,
  CurrentUser,
  DashboardStats,
  KnowledgeDocument,
  StaffUser,
  TicketFilters,
  TicketStatus,
  TicketSummary,
  WebMessageResponse
} from "./types";

const API_BASE_URL = process.env.NEXT_PUBLIC_API_BASE_URL ?? "http://localhost:8000";

export class ApiClientError extends Error {
  constructor(
    message: string,
    public readonly status?: number
  ) {
    super(message);
  }
}

type TicketListResponse = {
  items: TicketSummary[];
  count: number;
  limit?: number;
  offset?: number;
};

async function request<T>(path: string, init?: RequestInit & { token?: string }): Promise<T> {
  const { token, headers, ...requestInit } = init ?? {};
  const response = await fetch(`${API_BASE_URL}${path}`, {
    ...requestInit,
    headers: {
      "Content-Type": "application/json",
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(headers ?? {})
    },
    cache: "no-store"
  });

  if (!response.ok) {
    throw new ApiClientError(`API request failed: ${path}`, response.status);
  }

  return response.json() as Promise<T>;
}

async function uploadRequest<T>(path: string, formData: FormData, token?: string): Promise<T> {
  const response = await fetch(`${API_BASE_URL}${path}`, {
    method: "POST",
    headers: {
      ...(token ? { Authorization: `Bearer ${token}` } : {})
    },
    body: formData,
    cache: "no-store"
  });

  if (!response.ok) {
    throw new ApiClientError(`API request failed: ${path}`, response.status);
  }

  return response.json() as Promise<T>;
}

export const apiClient = {
  health: () => request<{ status: string; service: string }>("/health"),
  currentUser: (token: string) => request<CurrentUser>("/users/me", { token }),
  listTickets: (query = "", token?: string) =>
    request<TicketListResponse>(`/tickets${query}`, { token }),
  getTicket: (ticketId: string, token?: string) => request<TicketSummary>(`/tickets/${ticketId}`, { token }),
  updateTicket: (ticketId: string, payload: Partial<TicketSummary> & { status?: TicketStatus }, token?: string) =>
    request<TicketSummary>(`/tickets/${ticketId}`, {
      method: "PATCH",
      token,
      body: JSON.stringify({
        status: payload.status,
        intent: payload.intent,
        summary: payload.summary,
        assigned_to: payload.assignedTo
      })
    }),
  assignTicket: (ticketId: string, assignedTo: string, token?: string) =>
    request<TicketSummary>(`/tickets/${ticketId}/assign`, {
      method: "POST",
      token,
      body: JSON.stringify({ assigned_to: assignedTo })
    }),
  resolveTicket: (ticketId: string, token?: string) =>
    request<TicketSummary>(`/tickets/${ticketId}/resolve`, { method: "POST", token }),
  reopenTicket: (ticketId: string, token?: string) =>
    request<TicketSummary>(`/tickets/${ticketId}/reopen`, { method: "POST", token }),
  listMessages: (ticketId: string, token?: string) =>
    request<{ items: ConversationMessage[]; count: number }>(`/tickets/${ticketId}/messages`, { token }),
  sendTicketMessage: (ticketId: string, content: string, token?: string) =>
    request<{ message: ConversationMessage; outbound: { ok?: boolean; destination?: string } }>(
      `/tickets/${ticketId}/messages`,
      {
        method: "POST",
        token,
        body: JSON.stringify({ content })
      }
    ),
  buildTicketQuery: (filters: TicketFilters, currentUserId: string) => {
    const params = new URLSearchParams({ limit: "50", offset: "0" });
    if (filters.source !== "all") params.set("source", filters.source);
    if (filters.status !== "all") params.set("status", filters.status);
    if (filters.ownership === "assigned_to_me") params.set("assigned_to", currentUserId);
    if (filters.search.trim()) params.set("search", filters.search.trim());
    return `?${params.toString()}`;
  },
  dashboardStats: (token?: string) => request<DashboardStats>("/dashboard", { token }),
  listDocuments: (token?: string) => request<{ items: KnowledgeDocument[]; count: number }>("/documents", { token }),
  uploadDocument: (file: File, token?: string) => {
    const formData = new FormData();
    formData.set("file", file);
    return uploadRequest<KnowledgeDocument>("/documents/upload", formData, token);
  },
  retryDocument: (documentId: string, token?: string) =>
    request<KnowledgeDocument>(`/documents/${documentId}/retry`, { method: "POST", token }),
  listStaff: (token?: string) => request<{ items: StaffUser[]; count: number }>("/staff", { token }),
  setStaffStatus: (userId: string, status: "online" | "offline" | "disabled", token?: string) =>
    request<StaffUser>(`/staff/${userId}/status`, {
      method: "PATCH",
      token,
      body: JSON.stringify({ status })
    }),
  createAgentInvite: (email: string, token?: string) =>
    request<{ email: string; status: string }>("/staff/invites", {
      method: "POST",
      token,
      body: JSON.stringify({ email, role: "agent" })
    }),
  saveChannelSettings: (
    channel: "facebook" | "email",
    payload: { token?: string; provider?: string; apiKey?: string },
    token?: string
  ) =>
    request<{ status: string }>(`/channels/${channel}`, {
      method: "PATCH",
      token,
      body: JSON.stringify(payload)
    }),
  testChannelConnection: (channel: "facebook" | "email" | "web", token?: string) =>
    request<{ status: string; message?: string }>(`/channels/${channel}/test`, { method: "POST", token }),
  updatePresence: (status: "online" | "offline", token?: string) =>
    request("/presence/status", {
      method: "POST",
      token,
      body: JSON.stringify({ status })
    }),
  sendWebMessage: (payload: { sender_id: string; content: string; customer_name?: string }) =>
    request<WebMessageResponse>("/webhooks/web-message", {
      method: "POST",
      body: JSON.stringify(payload)
    })
};
