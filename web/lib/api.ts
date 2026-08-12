import type { Session } from "@supabase/supabase-js";

export type ApiResponse<T> = {
  meta: {
    code: number;
    message: string;
  };
  data: T;
};

export class ApiError extends Error {
  status: number;

  constructor(message: string, status: number) {
    super(message);
    this.name = "ApiError";
    this.status = status;
  }
}

const backendUrl = process.env.NEXT_PUBLIC_BACKEND_URL ?? "http://localhost:8000";

export async function apiFetch<T>(
  path: string,
  session: Session,
  options: RequestInit = {}
): Promise<T> {
  const headers = new Headers(options.headers);
  headers.set("Authorization", `Bearer ${session.access_token}`);

  if (!(options.body instanceof FormData) && !headers.has("Content-Type")) {
    headers.set("Content-Type", "application/json");
  }

  const response = await fetch(`${backendUrl}${path}`, {
    ...options,
    headers
  });

  const contentType = response.headers.get("content-type");
  const payload = contentType?.includes("application/json") ? await response.json() : null;

  if (!response.ok) {
    const message = payload?.detail ?? payload?.meta?.message ?? `Request failed with ${response.status}`;
    throw new ApiError(message, response.status);
  }

  return payload as T;
}

export async function publicApiFetch<T>(path: string, options: RequestInit = {}): Promise<T> {
  const headers = new Headers(options.headers);

  if (!(options.body instanceof FormData) && !headers.has("Content-Type")) {
    headers.set("Content-Type", "application/json");
  }

  const response = await fetch(`${backendUrl}${path}`, {
    ...options,
    headers
  });

  const contentType = response.headers.get("content-type");
  const payload = contentType?.includes("application/json") ? await response.json() : null;

  if (!response.ok) {
    const message = payload?.detail ?? payload?.meta?.message ?? `Request failed with ${response.status}`;
    throw new ApiError(message, response.status);
  }

  return payload as T;
}
