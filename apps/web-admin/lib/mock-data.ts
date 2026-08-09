import type { ConversationMessage, DashboardStats, KnowledgeDocument, StaffUser, TicketSummary } from "./types";

export const tickets: TicketSummary[] = [
  {
    id: "TCK-1024",
    customerId: "web_9c2",
    customerName: "Linh Tran",
    source: "web",
    status: "pending",
    intent: "complaint",
    summary: "Refund request after delayed delivery",
    lastMessagePreview: "I want a refund because my delivery is late and nobody has replied.",
    createdAt: "2026-08-08T02:31:00.000Z",
    updatedAt: "2026-08-08T02:39:00.000Z"
  },
  {
    id: "TCK-1023",
    customerId: "fb_1842",
    customerName: "Minh Pham",
    source: "facebook",
    status: "open",
    intent: "question",
    summary: "Asked about warranty period for headphones",
    lastMessagePreview: "How long is the warranty for the wireless headphones?",
    createdAt: "2026-08-08T02:22:00.000Z",
    updatedAt: "2026-08-08T02:33:00.000Z"
  },
  {
    id: "TCK-1022",
    customerId: "email_an@example.com",
    customerName: "An Nguyen",
    source: "email",
    status: "in_progress",
    intent: "question",
    summary: "Needs invoice copy for order #4821",
    lastMessagePreview: "Can you send me another invoice copy?",
    createdAt: "2026-08-08T02:05:00.000Z",
    updatedAt: "2026-08-08T02:18:00.000Z",
    assignedTo: "agent-demo"
  }
];

export const conversationMessages: Record<string, ConversationMessage[]> = {
  "TCK-1024": [
    {
      id: "MSG-2048",
      ticketId: "TCK-1024",
      senderType: "customer",
      senderId: "web_9c2",
      content: "I want a refund because my delivery is late and nobody has replied.",
      createdAt: "2026-08-08T02:31:00.000Z"
    },
    {
      id: "MSG-2049",
      ticketId: "TCK-1024",
      senderType: "bot",
      senderId: "ai-assistant",
      content: "I am sorry about the delay. A staff member is reviewing this now.",
      createdAt: "2026-08-08T02:32:00.000Z"
    }
  ],
  "TCK-1023": [
    {
      id: "MSG-2046",
      ticketId: "TCK-1023",
      senderType: "customer",
      senderId: "fb_1842",
      content: "How long is the warranty for the wireless headphones?",
      createdAt: "2026-08-08T02:22:00.000Z"
    },
    {
      id: "MSG-2047",
      ticketId: "TCK-1023",
      senderType: "bot",
      senderId: "ai-assistant",
      content: "Most headphones include a 12-month warranty. I can connect you with an agent if you need order-specific help.",
      createdAt: "2026-08-08T02:23:00.000Z"
    }
  ],
  "TCK-1022": [
    {
      id: "MSG-2044",
      ticketId: "TCK-1022",
      senderType: "customer",
      senderId: "email_an@example.com",
      content: "Can you send me another invoice copy for order #4821?",
      createdAt: "2026-08-08T02:05:00.000Z"
    },
    {
      id: "MSG-2045",
      ticketId: "TCK-1022",
      senderType: "human",
      senderId: "agent-demo",
      content: "I found the order and will send the invoice to this email thread.",
      createdAt: "2026-08-08T02:18:00.000Z"
    }
  ]
};

export const metrics = [
  { label: "Messages today", value: "186", delta: "+12%" },
  { label: "AI handled", value: "78%", delta: "+6%" },
  { label: "Avg response", value: "4.2s", delta: "-31%" },
  { label: "Open tickets", value: "14", delta: "+3" }
];

export const dashboardStats: DashboardStats = {
  totalMessagesToday: 186,
  aiHandlingRate: 78,
  averageResponseTimeSeconds: 4.2,
  openTicketCount: 14,
  sevenDayMessageTrend: [
    { day: "Mon", count: 48 },
    { day: "Tue", count: 62 },
    { day: "Wed", count: 71 },
    { day: "Thu", count: 56 },
    { day: "Fri", count: 88 },
    { day: "Sat", count: 93 },
    { day: "Sun", count: 78 }
  ],
  topQuestions: [
    { question: "What is the warranty period?", count: 31 },
    { question: "How do I request a refund?", count: 24 },
    { question: "Where is my delivery?", count: 22 },
    { question: "Can I get another invoice?", count: 17 },
    { question: "Do you support cash on delivery?", count: 13 }
  ]
};

export const documents: KnowledgeDocument[] = [
  {
    id: "doc-return-policy",
    name: "Return policy.txt",
    fileType: "txt",
    status: "ready",
    chunkCount: 18,
    uploadedBy: "Shop Owner",
    updatedAt: "2026-08-08T02:30:00.000Z"
  },
  {
    id: "doc-warranty",
    name: "Warranty terms.pdf",
    fileType: "pdf",
    status: "processing",
    chunkCount: 0,
    uploadedBy: "Shop Owner",
    updatedAt: "2026-08-08T02:25:00.000Z"
  },
  {
    id: "doc-shipping",
    name: "Shipping FAQ.docx",
    fileType: "docx",
    status: "ready",
    chunkCount: 24,
    uploadedBy: "Shop Owner",
    updatedAt: "2026-08-08T02:20:00.000Z"
  },
  {
    id: "doc-failed",
    name: "Legacy policy.pdf",
    fileType: "pdf",
    status: "error",
    chunkCount: 0,
    uploadedBy: "Shop Owner",
    updatedAt: "2026-08-08T02:10:00.000Z"
  }
];

export const staff: StaffUser[] = [
  { id: "agent-demo", name: "Support Agent", email: "agent@example.com", role: "agent", status: "online" },
  { id: "owner-demo", name: "Shop Owner", email: "owner@example.com", role: "super_admin", status: "online" },
  { id: "evening-agent", name: "Evening Agent", email: "evening@example.com", role: "agent", status: "offline" },
  { id: "disabled-agent", name: "Former Agent", email: "disabled@example.com", role: "agent", status: "disabled" }
];
