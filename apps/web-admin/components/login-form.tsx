"use client";

import { useState } from "react";
import type { FormEvent } from "react";
import { Radio } from "lucide-react";
import { useAuth } from "@/components/auth-provider";
import type { UserRole } from "@/lib/types";

export function LoginForm() {
  const { login, status, error, isMock } = useAuth();
  const [email, setEmail] = useState("owner@example.com");
  const [password, setPassword] = useState("password");
  const [mockRole, setMockRole] = useState<UserRole>("super_admin");
  const isSubmitting = status === "loading";

  async function onSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    await login(email, password, mockRole);
  }

  return (
    <section className="w-full max-w-sm border border-line bg-white p-6 shadow-panel">
      <div className="mb-6 flex items-center gap-3">
        <div className="flex size-10 items-center justify-center bg-brand text-white">
          <Radio size={20} />
        </div>
        <div>
          <h1 className="text-lg font-semibold text-ink">Smart Helpdesk</h1>
          <p className="text-sm text-slate-500">
            {isMock ? "Local mock auth mode" : "Supabase Auth"}
          </p>
        </div>
      </div>

      {error ? (
        <div className="mb-4 border border-rose-200 bg-rose-50 p-3 text-sm text-rose-800">
          {error}
        </div>
      ) : null}

      <form className="space-y-4" onSubmit={onSubmit}>
        <label className="block">
          <span className="text-sm font-medium text-slate-700">Email</span>
          <input
            className="mt-1 h-10 w-full border border-line px-3 text-sm focus-ring"
            onChange={(event) => setEmail(event.target.value)}
            placeholder="owner@example.com"
            type="email"
            value={email}
          />
        </label>
        <label className="block">
          <span className="text-sm font-medium text-slate-700">Password</span>
          <input
            className="mt-1 h-10 w-full border border-line px-3 text-sm focus-ring"
            onChange={(event) => setPassword(event.target.value)}
            placeholder="••••••••"
            type="password"
            value={password}
          />
        </label>
        {isMock ? (
          <label className="block">
            <span className="text-sm font-medium text-slate-700">Preview role</span>
            <select
              className="mt-1 h-10 w-full border border-line bg-white px-3 text-sm focus-ring"
              onChange={(event) => setMockRole(event.target.value as UserRole)}
              value={mockRole}
            >
              <option value="super_admin">super_admin</option>
              <option value="agent">agent</option>
            </select>
          </label>
        ) : null}
        <button
          className="h-10 w-full bg-brand px-4 text-sm font-semibold text-white focus-ring disabled:cursor-not-allowed disabled:bg-slate-400"
          disabled={isSubmitting}
          type="submit"
        >
          {isSubmitting ? "Signing in..." : "Sign in"}
        </button>
      </form>
    </section>
  );
}
