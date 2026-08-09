"use client";

import { useEffect, useState } from "react";
import { Loader2, UserPlus } from "lucide-react";
import { ApiClientError, apiClient } from "@/lib/api-client";
import { staff as mockStaff } from "@/lib/mock-data";
import type { StaffUser } from "@/lib/types";
import { useAuth } from "./auth-provider";
import { PageHeader, Panel, StatusBadge } from "./ui";
import { SuperAdminSection } from "./super-admin-section";

function staffError(error: unknown) {
  if (error instanceof ApiClientError && error.status === 403) {
    return "You do not have permission to manage staff.";
  }
  return "Staff backend is unavailable. Local preview data is shown.";
}

export function StaffAdmin() {
  const { accessToken, isMock } = useAuth();
  const [members, setMembers] = useState<StaffUser[]>(mockStaff);
  const [inviteEmail, setInviteEmail] = useState("");
  const [busyId, setBusyId] = useState<string | null>(null);
  const [inviting, setInviting] = useState(false);
  const [notice, setNotice] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (isMock || !accessToken) return;
    let active = true;
    async function loadStaff() {
      try {
        const response = await apiClient.listStaff(accessToken ?? undefined);
        if (active) setMembers(response.items);
      } catch (loadError) {
        if (active) setError(staffError(loadError));
      }
    }
    void loadStaff();
    return () => {
      active = false;
    };
  }, [accessToken, isMock]);

  async function setStatus(member: StaffUser, status: StaffUser["status"]) {
    setBusyId(member.id);
    setError(null);
    setNotice(null);
    try {
      if (isMock || !accessToken) {
        setMembers((current) => current.map((item) => (item.id === member.id ? { ...item, status } : item)));
      } else {
        const updated = await apiClient.setStaffStatus(member.id, status, accessToken);
        setMembers((current) => current.map((item) => (item.id === updated.id ? updated : item)));
      }
    } catch (statusError) {
      setError(staffError(statusError));
    } finally {
      setBusyId(null);
    }
  }

  async function createInvite() {
    const email = inviteEmail.trim();
    if (!email) return;
    setInviting(true);
    setError(null);
    setNotice(null);
    try {
      if (!isMock && accessToken) {
        await apiClient.createAgentInvite(email, accessToken);
      }
      setNotice(`Agent invite placeholder created for ${email}. Supabase Auth invite delivery can be connected later.`);
      setInviteEmail("");
    } catch (inviteError) {
      setError(staffError(inviteError));
    } finally {
      setInviting(false);
    }
  }

  return (
    <SuperAdminSection>
      <PageHeader
        title="Staff"
        description="Manage support users, roles, and availability state from Supabase-backed profiles."
        actions={
          <div className="flex flex-wrap items-center gap-2">
            <input
              className="h-9 w-64 border border-line px-3 text-sm focus-ring"
              onChange={(event) => setInviteEmail(event.target.value)}
              placeholder="agent@example.com"
              type="email"
              value={inviteEmail}
            />
            <button
              className="inline-flex h-9 items-center gap-2 bg-brand px-3 text-sm font-semibold text-white focus-ring disabled:cursor-not-allowed disabled:bg-slate-400"
              disabled={inviting || !inviteEmail.trim()}
              onClick={() => void createInvite()}
              type="button"
            >
              {inviting ? <Loader2 className="animate-spin" size={16} /> : <UserPlus size={16} />}
              Invite agent
            </button>
          </div>
        }
      />
      {error ? <div className="border-b border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800">{error}</div> : null}
      {notice ? <div className="border-b border-emerald-200 bg-emerald-50 px-4 py-3 text-sm text-emerald-800">{notice}</div> : null}
      <div className="p-4">
        <Panel title="Team members">
          <div className="overflow-x-auto">
            <table className="w-full text-left text-sm">
              <thead className="border-b border-line text-xs uppercase text-slate-500">
                <tr>
                  <th className="py-2">User</th>
                  <th className="py-2">Role</th>
                  <th className="py-2">Presence</th>
                  <th className="py-2 text-right">Actions</th>
                </tr>
              </thead>
              <tbody>
                {members.map((member) => (
                  <tr className="border-b border-line last:border-0" key={member.id}>
                    <td className="py-3">
                      <div className="font-medium text-ink">{member.name}</div>
                      <div className="mt-1 text-xs text-slate-500">{member.email}</div>
                    </td>
                    <td className="py-3 text-slate-700">{member.role}</td>
                    <td className="py-3">
                      <StatusBadge value={member.status} />
                    </td>
                    <td className="py-3 text-right">
                      {member.role === "agent" ? (
                        <button
                          className="inline-flex h-8 items-center gap-2 border border-line bg-white px-3 text-xs font-medium text-slate-700 focus-ring disabled:cursor-not-allowed disabled:opacity-50"
                          disabled={busyId !== null}
                          onClick={() =>
                            void setStatus(member, member.status === "disabled" ? "offline" : "disabled")
                          }
                          type="button"
                        >
                          {busyId === member.id ? <Loader2 className="animate-spin" size={14} /> : null}
                          {member.status === "disabled" ? "Enable" : "Disable"}
                        </button>
                      ) : (
                        <span className="text-xs text-slate-400">Protected</span>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </Panel>
      </div>
    </SuperAdminSection>
  );
}
