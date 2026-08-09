"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import { AlertCircle, Bot, Loader2, MessageCircle, Minus, Send, UserRound } from "lucide-react";
import { apiClient } from "@/lib/api-client";
import type { SenderType, WebMessageResponse } from "@/lib/types";

type WidgetMessage = {
  id: string;
  senderType: SenderType;
  content: string;
  createdAt: string;
};

type DeliveryState = "idle" | "sending" | "error";

const SENDER_STORAGE_KEY = "smart-helpdesk.widget.sender-id";

function getOrCreateSenderId() {
  if (typeof window === "undefined") return "web-visitor";
  const existing = window.localStorage.getItem(SENDER_STORAGE_KEY);
  if (existing) return existing;
  const next = `web_${crypto.randomUUID()}`;
  window.localStorage.setItem(SENDER_STORAGE_KEY, next);
  return next;
}

function textFromMessage(value: WebMessageResponse["bot_message"]) {
  if (!value) return "";
  return typeof value.content === "string" ? value.content : "";
}

function isEscalated(response: WebMessageResponse) {
  const action = String(response.action ?? "").toLowerCase();
  const status = String(response.ticket?.status ?? "").toLowerCase();
  return action.includes("escalat") || action.includes("handoff") || status === "pending" || status === "in_progress";
}

async function mockWebMessage(content: string): Promise<WebMessageResponse> {
  await new Promise((resolve) => window.setTimeout(resolve, 700));
  const lowered = content.toLowerCase();
  if (lowered.includes("fail") || lowered.includes("error")) {
    throw new Error("Mock message save failure");
  }
  if (["refund", "broken", "late", "angry", "complaint", "cancel"].some((term) => lowered.includes(term))) {
    return {
      action: "escalated",
      intent: "complaint",
      ticket: { id: "mock-ticket", status: "pending" },
      bot_message: {
        id: `bot-${Date.now()}`,
        senderType: "bot",
        content: "I am sorry about that. I have handed this to a support agent for review.",
        createdAt: new Date().toISOString()
      }
    };
  }
  return {
    action: "auto_replied",
    intent: "question",
    ticket: { id: "mock-ticket", status: "open" },
    bot_message: {
      id: `bot-${Date.now()}`,
      senderType: "bot",
      content: "Thanks for your message. For demo mode, I can help with shipping, returns, warranty, or handoff requests.",
      createdAt: new Date().toISOString()
    }
  };
}

export function WebChatWidget({
  customerName = "Storefront visitor",
  mockBackend = false
}: {
  customerName?: string;
  mockBackend?: boolean;
}) {
  const [open, setOpen] = useState(false);
  const [senderId, setSenderId] = useState("");
  const [messages, setMessages] = useState<WidgetMessage[]>([
    {
      id: "welcome",
      senderType: "bot",
      content: "Hi, ask me about shipping, returns, warranty, or order support.",
      createdAt: new Date().toISOString()
    }
  ]);
  const [draft, setDraft] = useState("");
  const [deliveryState, setDeliveryState] = useState<DeliveryState>("idle");
  const [handoff, setHandoff] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const scrollRef = useRef<HTMLDivElement | null>(null);

  useEffect(() => {
    setSenderId(getOrCreateSenderId());
  }, []);

  useEffect(() => {
    scrollRef.current?.scrollTo({ top: scrollRef.current.scrollHeight, behavior: "smooth" });
  }, [messages, deliveryState, open]);

  const subtitle = useMemo(() => {
    if (deliveryState === "sending") return "AI is typing";
    if (handoff) return "Handoff requested";
    if (deliveryState === "error") return "Message not saved";
    return "Usually replies in seconds";
  }, [deliveryState, handoff]);

  async function sendMessage() {
    const content = draft.trim();
    if (!content || deliveryState === "sending") return;

    const now = new Date().toISOString();
    const customerMessage: WidgetMessage = {
      id: `customer-${Date.now()}`,
      senderType: "customer",
      content,
      createdAt: now
    };
    setMessages((current) => [...current, customerMessage]);
    setDraft("");
    setDeliveryState("sending");
    setError(null);

    try {
      const response = mockBackend
        ? await mockWebMessage(content)
        : await apiClient.sendWebMessage({
            sender_id: senderId || getOrCreateSenderId(),
            customer_name: customerName,
            content
          });
      const botText = textFromMessage(response.bot_message);
      if (botText) {
        setMessages((current) => [
          ...current,
          {
            id: String(response.bot_message?.id ?? `bot-${Date.now()}`),
            senderType: "bot",
            content: botText,
            createdAt: String(response.bot_message?.createdAt ?? response.bot_message?.created_at ?? new Date().toISOString())
          }
        ]);
      }
      if (isEscalated(response)) {
        setHandoff(true);
        if (!botText) {
          setMessages((current) => [
            ...current,
            {
              id: `handoff-${Date.now()}`,
              senderType: "human",
              content: "A support agent has been notified and will continue this conversation.",
              createdAt: new Date().toISOString()
            }
          ]);
        }
      }
      setDeliveryState("idle");
    } catch {
      setDeliveryState("error");
      setError("We could not save your message. Please try again in a moment.");
    }
  }

  return (
    <div className="fixed bottom-5 right-5 z-50 font-sans text-slate-900">
      {open ? (
        <section className="mb-3 flex h-[560px] w-[min(380px,calc(100vw-2.5rem))] flex-col overflow-hidden border border-slate-200 bg-white shadow-2xl">
          <header className="flex items-center justify-between bg-[#0f766e] px-4 py-3 text-white">
            <div className="flex items-center gap-3">
              <div className="flex size-9 items-center justify-center bg-white/15">
                <MessageCircle size={19} />
              </div>
              <div>
                <div className="text-sm font-semibold">Shop Support</div>
                <div className="text-xs text-teal-50">{subtitle}</div>
              </div>
            </div>
            <button
              aria-label="Close chat"
              className="flex size-8 items-center justify-center hover:bg-white/10 focus-ring"
              onClick={() => setOpen(false)}
              type="button"
            >
              <Minus size={18} />
            </button>
          </header>

          {handoff ? (
            <div className="border-b border-amber-200 bg-amber-50 px-4 py-2 text-xs font-medium text-amber-800">
              A human support agent has been notified.
            </div>
          ) : null}
          {error ? (
            <div className="flex items-center gap-2 border-b border-rose-200 bg-rose-50 px-4 py-2 text-xs text-rose-800">
              <AlertCircle size={14} />
              {error}
            </div>
          ) : null}

          <div className="flex-1 space-y-3 overflow-y-auto bg-slate-50 p-4" ref={scrollRef}>
            {messages.map((message) => {
              const fromCustomer = message.senderType === "customer";
              const fromHuman = message.senderType === "human";
              return (
                <div className={`flex ${fromCustomer ? "justify-end" : "justify-start"}`} key={message.id}>
                  <div
                    className={`max-w-[82%] border px-3 py-2 text-sm leading-6 ${
                      fromCustomer
                        ? "border-teal-200 bg-teal-50"
                        : fromHuman
                          ? "border-indigo-200 bg-indigo-50"
                          : "border-slate-200 bg-white"
                    }`}
                  >
                    <div className="mb-1 flex items-center gap-1.5 text-[11px] font-medium uppercase text-slate-500">
                      {fromCustomer ? <UserRound size={12} /> : <Bot size={12} />}
                      {message.senderType}
                    </div>
                    {message.content}
                  </div>
                </div>
              );
            })}
            {deliveryState === "sending" ? (
              <div className="flex justify-start">
                <div className="inline-flex items-center gap-2 border border-slate-200 bg-white px-3 py-2 text-sm text-slate-600">
                  <Loader2 className="animate-spin" size={15} />
                  Typing...
                </div>
              </div>
            ) : null}
          </div>

          <footer className="border-t border-slate-200 bg-white p-3">
            <label className="sr-only" htmlFor="widget-message">
              Message
            </label>
            <div className="flex gap-2">
              <input
                className="h-10 min-w-0 flex-1 border border-slate-300 px-3 text-sm focus:outline-none focus:ring-2 focus:ring-[#0f766e]"
                id="widget-message"
                onChange={(event) => setDraft(event.target.value)}
                onKeyDown={(event) => {
                  if (event.key === "Enter") {
                    event.preventDefault();
                    void sendMessage();
                  }
                }}
                placeholder="Type a message..."
                value={draft}
              />
              <button
                aria-label="Send message"
                className="flex size-10 shrink-0 items-center justify-center bg-[#0f766e] text-white disabled:cursor-not-allowed disabled:bg-slate-400"
                disabled={!draft.trim() || deliveryState === "sending"}
                onClick={() => void sendMessage()}
                type="button"
              >
                {deliveryState === "sending" ? <Loader2 className="animate-spin" size={17} /> : <Send size={17} />}
              </button>
            </div>
            <div className="mt-2 truncate text-[11px] text-slate-500">Visitor id: {senderId || "creating..."}</div>
          </footer>
        </section>
      ) : null}

      <button
        aria-label={open ? "Close support chat" : "Open support chat"}
        className="ml-auto flex size-14 items-center justify-center bg-[#0f766e] text-white shadow-2xl transition hover:bg-[#115e59] focus:outline-none focus:ring-2 focus:ring-[#0f766e] focus:ring-offset-2"
        onClick={() => setOpen((current) => !current)}
        type="button"
      >
        <MessageCircle size={25} />
      </button>
    </div>
  );
}
