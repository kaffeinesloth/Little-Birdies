"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import type { ReactNode } from "react";
import {
  BarChart3,
  BookOpen,
  Inbox,
  MessageSquare,
  Radio,
  Settings,
  Users
} from "lucide-react";
import { useAuth } from "@/components/auth-provider";
import { canViewSection } from "@/lib/auth";

const items = [
  { href: "/inbox", label: "Inbox", section: "inbox" as const, icon: Inbox },
  { href: "/dashboard", label: "Dashboard", section: "dashboard" as const, icon: BarChart3 },
  { href: "/knowledge-base", label: "Knowledge Base", section: "knowledge-base" as const, icon: BookOpen },
  { href: "/staff", label: "Staff", section: "staff" as const, icon: Users },
  { href: "/settings/channels", label: "Channels", section: "channels" as const, icon: Settings },
  { href: "/widget-demo", label: "Widget Demo", section: "dashboard" as const, icon: MessageSquare }
];

export function AppShell({
  children
}: {
  children: ReactNode;
}) {
  const pathname = usePathname();
  const { user, logout } = useAuth();

  if (!user) {
    return null;
  }

  const visibleItems = items.filter((item) => canViewSection(user.role, item.section));

  return (
    <div className="min-h-screen bg-surface">
      <aside className="fixed inset-y-0 left-0 hidden w-64 border-r border-line bg-white md:block">
        <div className="flex h-16 items-center gap-2 border-b border-line px-5">
          <div className="flex size-9 items-center justify-center bg-brand text-white">
            <Radio size={18} />
          </div>
          <div>
            <div className="text-sm font-semibold text-ink">Smart Helpdesk</div>
            <div className="text-xs text-slate-500">Admin Console</div>
          </div>
        </div>
        <nav className="space-y-1 p-3">
          {visibleItems.map((item) => {
            const Icon = item.icon;
            const active = pathname === item.href;
            return (
              <Link
                key={item.href}
                href={item.href}
                className={`flex h-10 items-center gap-3 px-3 text-sm font-medium focus-ring ${
                  active ? "bg-teal-50 text-brand" : "text-slate-700 hover:bg-slate-100"
                }`}
              >
                <Icon size={17} />
                {item.label}
              </Link>
            );
          })}
        </nav>
        <div className="absolute bottom-0 left-0 right-0 border-t border-line p-4">
          <div className="text-sm font-medium text-ink">{user.fullName}</div>
          <div className="text-xs text-slate-500">{user.role}</div>
          <button className="mt-3 text-xs font-medium text-brand focus-ring" onClick={() => void logout()} type="button">
            Sign out
          </button>
        </div>
      </aside>
      <div className="md:pl-64">
        <header className="flex h-14 items-center justify-between border-b border-line bg-white px-4 md:hidden">
          <div className="text-sm font-semibold text-ink">Smart Helpdesk</div>
          <Link className="text-sm font-medium text-brand" href="/inbox">
            Inbox
          </Link>
        </header>
        <main>{children}</main>
      </div>
    </div>
  );
}
