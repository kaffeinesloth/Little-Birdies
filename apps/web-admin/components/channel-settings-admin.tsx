"use client";

import { useState } from "react";
import { Loader2, Mail, MessageCircle, PlugZap } from "lucide-react";
import { ApiClientError, apiClient } from "@/lib/api-client";
import { useAuth } from "./auth-provider";
import { PageHeader, Panel, StatusBadge } from "./ui";
import { SuperAdminSection } from "./super-admin-section";

type ChannelKey = "facebook" | "email" | "web";

function channelError(error: unknown) {
  if (error instanceof ApiClientError && error.status === 403) {
    return "You do not have permission to manage channel settings.";
  }
  return "Channel settings backend is unavailable. Placeholder state is shown.";
}

export function ChannelSettingsAdmin() {
  const { accessToken, isMock } = useAuth();
  const [facebookToken, setFacebookToken] = useState("");
  const [emailProvider, setEmailProvider] = useState("mailgun");
  const [emailApiKey, setEmailApiKey] = useState("");
  const [busyAction, setBusyAction] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  async function saveFacebook() {
    setBusyAction("facebook-save");
    setError(null);
    setNotice(null);
    try {
      if (!isMock && accessToken) {
        await apiClient.saveChannelSettings("facebook", { token: facebookToken }, accessToken);
      }
      setFacebookToken("");
      setNotice("Facebook token placeholder saved. Stored secrets are not displayed in the admin UI.");
    } catch (saveError) {
      setError(channelError(saveError));
    } finally {
      setBusyAction(null);
    }
  }

  async function saveEmail() {
    setBusyAction("email-save");
    setError(null);
    setNotice(null);
    try {
      if (!isMock && accessToken) {
        await apiClient.saveChannelSettings("email", { provider: emailProvider, apiKey: emailApiKey }, accessToken);
      }
      setEmailApiKey("");
      setNotice("Email provider placeholder saved. Stored API keys are not displayed in the admin UI.");
    } catch (saveError) {
      setError(channelError(saveError));
    } finally {
      setBusyAction(null);
    }
  }

  async function testConnection(channel: ChannelKey) {
    setBusyAction(`${channel}-test`);
    setError(null);
    setNotice(null);
    try {
      if (!isMock && accessToken) {
        await apiClient.testChannelConnection(channel, accessToken);
      }
      setNotice(`${channel} connection test placeholder completed.`);
    } catch (testError) {
      setError(channelError(testError));
    } finally {
      setBusyAction(null);
    }
  }

  return (
    <SuperAdminSection>
      <PageHeader
        title="Channels"
        description="Configure source channels and outbound delivery credentials."
        actions={
          <button
            className="inline-flex h-9 items-center gap-2 border border-line bg-white px-3 text-sm font-medium text-slate-700 focus-ring disabled:cursor-not-allowed disabled:opacity-50"
            disabled={busyAction !== null}
            onClick={() => void testConnection("web")}
            type="button"
          >
            {busyAction === "web-test" ? <Loader2 className="animate-spin" size={16} /> : <PlugZap size={16} />}
            Test web
          </button>
        }
      />
      {error ? <div className="border-b border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800">{error}</div> : null}
      {notice ? <div className="border-b border-emerald-200 bg-emerald-50 px-4 py-3 text-sm text-emerald-800">{notice}</div> : null}
      <div className="grid gap-4 p-4 xl:grid-cols-2">
        <Panel title="Facebook Messenger">
          <div className="space-y-4">
            <div className="flex items-center justify-between gap-3 border border-line p-3">
              <div className="flex items-center gap-3">
                <MessageCircle className="text-blue-600" size={20} />
                <div>
                  <div className="text-sm font-semibold text-ink">Page access token</div>
                  <div className="mt-1 text-xs text-slate-500">Replacement value only. Existing tokens are never shown.</div>
                </div>
              </div>
              <StatusBadge value="offline" />
            </div>
            <label className="block">
              <span className="text-sm font-medium text-slate-700">New Facebook token</span>
              <input
                className="mt-1 h-10 w-full border border-line px-3 text-sm focus-ring"
                onChange={(event) => setFacebookToken(event.target.value)}
                placeholder="Paste a new token"
                type="password"
                value={facebookToken}
              />
            </label>
            <div className="flex justify-end gap-2">
              <button
                className="inline-flex h-9 items-center gap-2 border border-line bg-white px-3 text-sm font-medium text-slate-700 focus-ring disabled:cursor-not-allowed disabled:opacity-50"
                disabled={busyAction !== null}
                onClick={() => void testConnection("facebook")}
                type="button"
              >
                {busyAction === "facebook-test" ? <Loader2 className="animate-spin" size={16} /> : <PlugZap size={16} />}
                Test connection
              </button>
              <button
                className="h-9 bg-brand px-3 text-sm font-semibold text-white focus-ring disabled:cursor-not-allowed disabled:bg-slate-400"
                disabled={busyAction !== null || !facebookToken.trim()}
                onClick={() => void saveFacebook()}
                type="button"
              >
                Save token
              </button>
            </div>
          </div>
        </Panel>

        <Panel title="Inbound Email">
          <div className="space-y-4">
            <div className="flex items-center justify-between gap-3 border border-line p-3">
              <div className="flex items-center gap-3">
                <Mail className="text-violet-600" size={20} />
                <div>
                  <div className="text-sm font-semibold text-ink">Mailgun or SendGrid</div>
                  <div className="mt-1 text-xs text-slate-500">Provider and replacement API key placeholder.</div>
                </div>
              </div>
              <StatusBadge value="offline" />
            </div>
            <label className="block">
              <span className="text-sm font-medium text-slate-700">Provider</span>
              <select
                className="mt-1 h-10 w-full border border-line bg-white px-3 text-sm focus-ring"
                onChange={(event) => setEmailProvider(event.target.value)}
                value={emailProvider}
              >
                <option value="mailgun">Mailgun</option>
                <option value="sendgrid">SendGrid</option>
              </select>
            </label>
            <label className="block">
              <span className="text-sm font-medium text-slate-700">New API key</span>
              <input
                className="mt-1 h-10 w-full border border-line px-3 text-sm focus-ring"
                onChange={(event) => setEmailApiKey(event.target.value)}
                placeholder="Paste a new API key"
                type="password"
                value={emailApiKey}
              />
            </label>
            <div className="flex justify-end gap-2">
              <button
                className="inline-flex h-9 items-center gap-2 border border-line bg-white px-3 text-sm font-medium text-slate-700 focus-ring disabled:cursor-not-allowed disabled:opacity-50"
                disabled={busyAction !== null}
                onClick={() => void testConnection("email")}
                type="button"
              >
                {busyAction === "email-test" ? <Loader2 className="animate-spin" size={16} /> : <PlugZap size={16} />}
                Test connection
              </button>
              <button
                className="h-9 bg-brand px-3 text-sm font-semibold text-white focus-ring disabled:cursor-not-allowed disabled:bg-slate-400"
                disabled={busyAction !== null || !emailApiKey.trim()}
                onClick={() => void saveEmail()}
                type="button"
              >
                Save email
              </button>
            </div>
          </div>
        </Panel>
      </div>
    </SuperAdminSection>
  );
}
