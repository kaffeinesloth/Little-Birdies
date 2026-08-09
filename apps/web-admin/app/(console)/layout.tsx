import type { ReactNode } from "react";
import { ProtectedContent } from "@/components/auth-provider";
import { AppShell } from "@/components/app-shell";

export default function ConsoleLayout({
  children
}: Readonly<{
  children: ReactNode;
}>) {
  return (
    <ProtectedContent>
      <AppShell>{children}</AppShell>
    </ProtectedContent>
  );
}
