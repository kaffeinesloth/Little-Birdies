import { createClient } from "@supabase/supabase-js";
import { ApiClientError, apiClient } from "./api-client";
import type { CurrentUser, UserRole } from "./types";

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL ?? "";
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ?? "";

export const supabase =
  supabaseUrl && supabaseAnonKey
    ? createClient(supabaseUrl, supabaseAnonKey)
    : null;

export const isMockAuthMode = supabase === null;

export function getMockRole(): UserRole {
  const value = process.env.NEXT_PUBLIC_MOCK_ROLE;
  return value === "agent" ? "agent" : "super_admin";
}

export function getCurrentUserPlaceholder(): CurrentUser {
  const role = getMockRole();
  return {
    id: role === "agent" ? "agent-demo" : "owner-demo",
    email: role === "agent" ? "agent@example.com" : "owner@example.com",
    fullName: role === "agent" ? "Support Agent" : "Shop Owner",
    role,
    status: "online"
  };
}

type Section = "inbox" | "dashboard" | "knowledge-base" | "staff" | "channels";

export function canViewSection(role: UserRole, section: Section) {
  if (role === "super_admin") {
    return true;
  }
  return section === "inbox";
}

export function defaultRouteForRole(role: UserRole) {
  return role === "agent" ? "/inbox" : "/dashboard";
}

export function normalizeBackendUser(value: Partial<CurrentUser> & { full_name?: string }): CurrentUser {
  return {
    id: String(value.id ?? ""),
    email: String(value.email ?? ""),
    fullName: String(value.fullName ?? value.full_name ?? value.email ?? "Support User"),
    role: value.role === "agent" ? "agent" : "super_admin",
    status: value.status === "disabled" || value.status === "offline" ? value.status : "online"
  };
}

export async function fetchCurrentUserProfile(token: string): Promise<CurrentUser> {
  try {
    return normalizeBackendUser(await apiClient.currentUser(token));
  } catch (error) {
    if (error instanceof ApiClientError && (error.status === 401 || error.status === 403)) {
      throw error;
    }
    throw error;
  }
}

export function getMockUserForEmail(email: string): CurrentUser {
  const lowered = email.toLowerCase();
  const role = lowered.includes("agent") ? "agent" : getMockRole();
  const status = lowered.includes("disabled") ? "disabled" : "online";
  return {
    id: role === "agent" ? "agent-demo" : "owner-demo",
    email,
    fullName: role === "agent" ? "Support Agent" : "Shop Owner",
    role,
    status
  };
}
