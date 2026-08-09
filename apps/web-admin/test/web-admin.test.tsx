import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { beforeEach, describe, expect, test, vi } from "vitest";
import type { ReactNode } from "react";
import type { CurrentUser } from "@/lib/types";

const authState = vi.hoisted(() => ({
  user: {
    id: "agent-demo",
    email: "agent@example.com",
    fullName: "Support Agent",
    role: "agent",
    status: "online"
  } as CurrentUser,
  accessToken: "mock-local-token",
  isMock: true
}));

vi.mock("next/navigation", () => ({
  usePathname: () => "/inbox",
  useRouter: () => ({ replace: vi.fn() })
}));

vi.mock("@/components/auth-provider", () => ({
  useAuth: () => ({
    user: authState.user,
    accessToken: authState.accessToken,
    status: "authenticated",
    error: null,
    isMock: authState.isMock,
    login: vi.fn(),
    logout: vi.fn()
  }),
  ProtectedContent: ({ children }: { children: ReactNode }) => children
}));

describe("web admin role navigation", () => {
  beforeEach(() => {
    authState.user = {
      id: "agent-demo",
      email: "agent@example.com",
      fullName: "Support Agent",
      role: "agent",
      status: "online"
    };
    authState.isMock = true;
  });

  test("agent navigation only shows Inbox", async () => {
    const { AppShell } = await import("@/components/app-shell");

    render(
      <AppShell>
        <div>Current page</div>
      </AppShell>
    );

    expect(screen.getAllByText("Inbox").length).toBeGreaterThan(0);
    expect(screen.queryByText("Dashboard")).not.toBeInTheDocument();
    expect(screen.queryByText("Knowledge Base")).not.toBeInTheDocument();
    expect(screen.queryByText("Staff")).not.toBeInTheDocument();
    expect(screen.queryByText("Channels")).not.toBeInTheDocument();
  });

  test("super_admin navigation shows admin sections", async () => {
    authState.user = { ...authState.user, role: "super_admin", fullName: "Shop Owner" };
    const { AppShell } = await import("@/components/app-shell");

    render(
      <AppShell>
        <div>Current page</div>
      </AppShell>
    );

    expect(screen.getByText("Dashboard")).toBeInTheDocument();
    expect(screen.getByText("Knowledge Base")).toBeInTheDocument();
    expect(screen.getByText("Staff")).toBeInTheDocument();
    expect(screen.getByText("Channels")).toBeInTheDocument();
  });
});

describe("web admin inbox", () => {
  test("renders mock ticket list with source, status, intent, and preview", async () => {
    const { UnifiedInbox } = await import("@/components/unified-inbox");

    render(<UnifiedInbox />);

    expect(screen.getAllByText("Linh Tran").length).toBeGreaterThan(0);
    expect(screen.getAllByText("Web").length).toBeGreaterThan(0);
    expect(screen.getAllByText("pending").length).toBeGreaterThan(0);
    expect(screen.getAllByText("complaint").length).toBeGreaterThan(0);
    expect(screen.getAllByText(/delivery is late/i).length).toBeGreaterThan(0);
  });

  test("shows composer error state when mock outbound delivery fails", async () => {
    const { UnifiedInbox } = await import("@/components/unified-inbox");

    render(<UnifiedInbox />);

    fireEvent.change(screen.getByLabelText("Reply"), {
      target: { value: "please fail this delivery" }
    });
    fireEvent.click(screen.getByRole("button", { name: /send reply/i }));

    await waitFor(() => {
      expect(screen.getByText("Reply was not delivered. Edit and try again.")).toBeInTheDocument();
    });
  });
});

describe("knowledge-base upload validation", () => {
  test("rejects unsupported file types before upload", async () => {
    authState.user = { ...authState.user, role: "super_admin" };
    const { KnowledgeBaseAdmin } = await import("@/components/knowledge-base-admin");
    const { container } = render(<KnowledgeBaseAdmin />);
    const input = container.querySelector('input[type="file"]') as HTMLInputElement;

    fireEvent.change(input, {
      target: {
        files: [new File(["bad"], "policy.csv", { type: "text/csv" })]
      }
    });

    expect(await screen.findByText("Unsupported file type. Upload a PDF, DOCX, or TXT file.")).toBeInTheDocument();
  });
});
