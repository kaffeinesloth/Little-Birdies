export type UserRole = "super_admin" | "agent";
export type TicketStatus = "open" | "in_progress" | "pending" | "resolved";
export type ChannelType = "web" | "facebook" | "email";
export type IntentType = "question" | "complaint" | "spam";
export type SenderType = "customer" | "bot" | "human";

export type CurrentUser = {
  id: string;
  email: string;
  fullName: string;
  role: UserRole;
  status: "online" | "offline" | "disabled";
};

export type TicketSummary = {
  id: string;
  customerId?: string;
  customerName: string;
  source: ChannelType;
  status: TicketStatus;
  intent: IntentType;
  summary: string;
  lastMessagePreview?: string;
  createdAt?: string;
  updatedAt: string;
  assignedTo?: string;
};

export type ConversationMessage = {
  id: string;
  ticketId: string;
  senderType: SenderType;
  senderId: string;
  content: string;
  createdAt: string;
};

export type TicketFilters = {
  source: ChannelType | "all";
  status: TicketStatus | "all";
  ownership: "all" | "assigned_to_me" | "open";
  search: string;
};

export type DashboardStats = {
  totalMessagesToday: number;
  aiHandlingRate: number;
  averageResponseTimeSeconds: number;
  openTicketCount: number;
  sevenDayMessageTrend: Array<{ day: string; count: number }>;
  topQuestions: Array<{ question: string; count: number }>;
};

export type KnowledgeDocument = {
  id: string;
  name: string;
  fileType: "pdf" | "docx" | "txt";
  status: "processing" | "ready" | "error";
  chunkCount: number;
  uploadedBy: string;
  updatedAt: string;
};

export type StaffUser = {
  id: string;
  name: string;
  email: string;
  role: UserRole;
  status: "online" | "offline" | "disabled";
};

export type WebMessageResponse = {
  ticket?: Partial<TicketSummary> & Record<string, unknown>;
  customer_message?: Partial<ConversationMessage> & Record<string, unknown>;
  bot_message?: Partial<ConversationMessage> & Record<string, unknown> | null;
  notifications?: unknown[];
  action?: string;
  intent?: IntentType | string;
};
