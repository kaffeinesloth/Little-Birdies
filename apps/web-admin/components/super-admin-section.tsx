"use client";

import type { ReactNode } from "react";
import { ShieldAlert } from "lucide-react";
import { useAuth } from "./auth-provider";

export function SuperAdminSection({ children }: { children: ReactNode }) {
  const { user, status } = useAuth();

  if (status === "loading") {
    return <div className="p-6 text-sm text-slate-600">Checking permissions...</div>;
  }

  if (!user || user.role !== "super_admin") {
    return (
      <div className="m-4 border border-rose-200 bg-rose-50 p-4 text-sm text-rose-800">
        <div className="flex items-center gap-2 font-semibold">
          <ShieldAlert size={16} />
          Super admin access required
        </div>
        <p className="mt-2">This section is restricted to super_admin users.</p>
      </div>
    );
  }

  return children;
}
