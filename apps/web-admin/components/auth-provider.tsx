"use client";

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode
} from "react";
import { usePathname, useRouter } from "next/navigation";
import { ApiClientError } from "@/lib/api-client";
import {
  canViewSection,
  defaultRouteForRole,
  fetchCurrentUserProfile,
  getMockUserForEmail,
  isMockAuthMode,
  supabase
} from "@/lib/auth";
import type { CurrentUser, UserRole } from "@/lib/types";

type AuthStatus = "loading" | "authenticated" | "unauthenticated" | "error";

type AuthContextValue = {
  user: CurrentUser | null;
  accessToken: string | null;
  status: AuthStatus;
  error: string | null;
  isMock: boolean;
  login: (email: string, password: string, mockRole?: UserRole) => Promise<void>;
  logout: () => Promise<void>;
};

const AuthContext = createContext<AuthContextValue | null>(null);
const MOCK_SESSION_KEY = "smart-helpdesk-web-admin.mock-session";

function sectionForPath(pathname: string) {
  if (pathname.startsWith("/dashboard")) return "dashboard";
  if (pathname.startsWith("/widget-demo")) return "dashboard";
  if (pathname.startsWith("/knowledge-base")) return "knowledge-base";
  if (pathname.startsWith("/staff")) return "staff";
  if (pathname.startsWith("/settings/channels")) return "channels";
  return "inbox";
}

function readMockUser() {
  if (typeof window === "undefined") {
    return null;
  }
  const raw = window.localStorage.getItem(MOCK_SESSION_KEY);
  if (!raw) {
    return null;
  }
  try {
    return JSON.parse(raw) as CurrentUser;
  } catch {
    window.localStorage.removeItem(MOCK_SESSION_KEY);
    return null;
  }
}

function writeMockUser(user: CurrentUser) {
  window.localStorage.setItem(MOCK_SESSION_KEY, JSON.stringify(user));
}

function clearMockUser() {
  window.localStorage.removeItem(MOCK_SESSION_KEY);
}

function authErrorMessage(error: unknown) {
  if (error instanceof ApiClientError) {
    if (error.status === 401) {
      return "Your session expired. Please sign in again.";
    }
    if (error.status === 403) {
      return "This account is disabled or does not have permission to access the admin console.";
    }
  }
  if (error instanceof Error) {
    return error.message;
  }
  return "Authentication failed.";
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const router = useRouter();
  const pathname = usePathname();
  const [user, setUser] = useState<CurrentUser | null>(null);
  const [accessToken, setAccessToken] = useState<string | null>(null);
  const [status, setStatus] = useState<AuthStatus>("loading");
  const [error, setError] = useState<string | null>(null);

  const loadSupabaseProfile = useCallback(async () => {
    if (!supabase) {
      return;
    }
    const { data, error: sessionError } = await supabase.auth.getSession();
    if (sessionError) {
      throw sessionError;
    }
    const token = data.session?.access_token;
    if (!token) {
      setUser(null);
      setAccessToken(null);
      setStatus("unauthenticated");
      return;
    }
    const profile = await fetchCurrentUserProfile(token);
    if (profile.status === "disabled") {
      throw new ApiClientError("Account disabled", 403);
    }
    setAccessToken(token);
    setUser(profile);
    setStatus("authenticated");
  }, []);

  useEffect(() => {
    let active = true;
    async function boot() {
      try {
        setError(null);
        if (isMockAuthMode) {
          const mockUser = readMockUser();
          if (!active) return;
          setUser(mockUser);
          setAccessToken(mockUser ? "mock-local-token" : null);
          setStatus(mockUser ? "authenticated" : "unauthenticated");
          return;
        }
        await loadSupabaseProfile();
      } catch (bootError) {
        if (!active) return;
        setUser(null);
        setAccessToken(null);
        setStatus("error");
        setError(authErrorMessage(bootError));
      }
    }
    void boot();
    return () => {
      active = false;
    };
  }, [loadSupabaseProfile]);

  useEffect(() => {
    if (status === "loading") {
      return;
    }
    if (pathname === "/login") {
      if (user && user.status !== "disabled") {
        router.replace(defaultRouteForRole(user.role));
      }
      return;
    }
    if (!user) {
      router.replace("/login");
      return;
    }
    if (user.status === "disabled") {
      setError("This account is disabled. Contact a super admin for access.");
      router.replace("/login");
      return;
    }
    const section = sectionForPath(pathname);
    if (!canViewSection(user.role, section)) {
      router.replace(defaultRouteForRole(user.role));
    }
  }, [pathname, router, status, user]);

  const login = useCallback(
    async (email: string, password: string, mockRole?: UserRole) => {
      setStatus("loading");
      setError(null);
      try {
        if (isMockAuthMode) {
          const mockUser = getMockUserForEmail(email);
          const userWithRole = mockRole ? { ...mockUser, role: mockRole } : mockUser;
          if (userWithRole.status === "disabled") {
            throw new ApiClientError("Account disabled", 403);
          }
          writeMockUser(userWithRole);
          setUser(userWithRole);
          setAccessToken("mock-local-token");
          setStatus("authenticated");
          router.replace(defaultRouteForRole(userWithRole.role));
          return;
        }
        if (!supabase) {
          throw new Error("Supabase is not configured.");
        }
        const { data, error: signInError } = await supabase.auth.signInWithPassword({
          email,
          password
        });
        if (signInError) {
          throw signInError;
        }
        const token = data.session?.access_token;
        if (!token) {
          throw new Error("Supabase did not return a session.");
        }
        const profile = await fetchCurrentUserProfile(token);
        if (profile.status === "disabled") {
          await supabase.auth.signOut();
          throw new ApiClientError("Account disabled", 403);
        }
        setUser(profile);
        setAccessToken(token);
        setStatus("authenticated");
        router.replace(defaultRouteForRole(profile.role));
      } catch (loginError) {
        setUser(null);
        setAccessToken(null);
        setStatus("error");
        setError(authErrorMessage(loginError));
      }
    },
    [router]
  );

  const logout = useCallback(async () => {
    if (isMockAuthMode) {
      clearMockUser();
    } else {
      await supabase?.auth.signOut();
    }
    setUser(null);
    setAccessToken(null);
    setStatus("unauthenticated");
    router.replace("/login");
  }, [router]);

  const value = useMemo<AuthContextValue>(
    () => ({
      user,
      accessToken,
      status,
      error,
      isMock: isMockAuthMode,
      login,
      logout
    }),
    [accessToken, error, login, logout, status, user]
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const value = useContext(AuthContext);
  if (!value) {
    throw new Error("useAuth must be used within AuthProvider");
  }
  return value;
}

export function ProtectedContent({ children }: { children: ReactNode }) {
  const { status, user, error } = useAuth();

  if (status === "loading") {
    return <div className="p-6 text-sm text-slate-600">Loading session...</div>;
  }

  if (error) {
    return (
      <div className="m-6 border border-rose-200 bg-rose-50 p-4 text-sm text-rose-800">
        {error}
      </div>
    );
  }

  if (!user) {
    return <div className="p-6 text-sm text-slate-600">Redirecting to login...</div>;
  }

  return children;
}
