export type UserRole = 'super_admin' | 'agent';
export type UserStatus = 'online' | 'offline' | 'disabled';

export interface User {
  id: string;
  email: string;
  full_name: string;
  role: UserRole;
  status: UserStatus;
  avatar_url?: string;
  created_at: string;
  last_seen_at?: string;
}

export type TicketStatus = 'open' | 'in_progress' | 'pending' | 'resolved';
export type TicketIntent = 'question' | 'complaint' | 'spam';
export type TicketSource = 'web' | 'facebook' | 'email';

export interface DashboardStats {
  total_tickets: number;
  open_tickets: number;
  in_progress_tickets: number;
  resolved_tickets: number;
  ai_handled_percent: number;
  avg_bot_response_seconds: number;
  avg_human_response_seconds: number;
  resolution_rate_percent: number;
  ai_vs_human_ratio: string;
  channels: {
    web: number;
    facebook: number;
    email: number;
  };
  hourly_distribution: Array<{ hour: string; count: number }>;
}

export interface ProductIssue {
  product: string;
  complaint_count: number;
  top_issues: string[];
}

export interface KnowledgeGap {
  topic: string;
  query_count: number;
}
