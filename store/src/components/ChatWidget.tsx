import React, { useState, useEffect, useRef } from 'react';
import { MessageSquare, X, Send, Bot, UserCheck, Sparkles, RotateCcw, Zap } from 'lucide-react';
import { createClient } from '@supabase/supabase-js';

const BACKEND_URL = 'http://localhost:8000';
const SUPABASE_URL = 'https://djgvczqdtysefrdmujrr.supabase.co';
const SUPABASE_ANON_KEY =
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRqZ3ZjenFkdHlzZWZyZG11anJyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY0MDMyODAsImV4cCI6MjEwMTk3OTI4MH0.sRdLhWHSV6OF6wjnvXsTwTyhxLl7yS5MQYOMvkKadiw';

interface MessageItem {
  id: string;
  sender_type: 'customer' | 'bot' | 'human';
  content: string;
  timeStr: string;
}

const DEFAULT_WELCOME =
  '👋 **Xin chào!** Mình là trợ lý AI thông minh của **SportGear Boutique**.\n\nBạn cần tư vấn chọn size, xem bảng giá khuyến mãi, chính sách freeship hay bảo hành đổi trả 30 ngày không ạ?';

const QUICK_PROMPTS = [
  'Shop có freeship không?',
  'Áo Polo Pro Active giá bao nhiêu và có size L không?',
  'Giày Ultra Boost 2026 có size nào?',
  'Chính sách đổi trả trong bao lâu?',
  'Tôi muốn gặp nhân viên CSKH trực tiếp',
];

// Helper render Markdown đơn giản (hỗ trợ **in đậm**, • gạch đầu dòng, icon)
const FormattedMessage: React.FC<{ content: string; isCustomer: boolean }> = ({ content, isCustomer }) => {
  const lines = content.split('\n');

  return (
    <div className="space-y-1.5 text-sm leading-relaxed">
      {lines.map((line, idx) => {
        if (!line.trim()) return <div key={idx} className="h-1" />;

        // Parse **in đậm**
        const parts = line.split(/(\*\*.*?\*\*)/g);
        const renderedLine = parts.map((part, pIdx) => {
          if (part.startsWith('**') && part.endsWith('**')) {
            return (
              <strong key={pIdx} className={isCustomer ? 'font-black text-white' : 'font-bold text-sky-950'}>
                {part.slice(2, -2)}
              </strong>
            );
          }
          return part;
        });

        // Bullet point
        if (line.trim().startsWith('•') || line.trim().startsWith('-') || line.trim().startsWith('+')) {
          return (
            <div key={idx} className="flex items-start gap-1.5 pl-1 text-[13px]">
              <span className={isCustomer ? 'text-sky-200' : 'text-sky-600'}>•</span>
              <span className="flex-1">{renderedLine}</span>
            </div>
          );
        }

        return <div key={idx}>{renderedLine}</div>;
      })}
    </div>
  );
};

export const ChatWidget: React.FC<{ initialMessage?: string }> = ({ initialMessage }) => {
  const [isOpen, setIsOpen] = useState(false);
  const [inputText, setInputText] = useState('');
  const [messages, setMessages] = useState<MessageItem[]>([
    {
      id: 'welcome',
      sender_type: 'bot',
      content: DEFAULT_WELCOME,
      timeStr: new Date().toLocaleTimeString('vi-VN', { hour: '2-digit', minute: '2-digit' }),
    },
  ]);
  const [isTyping, setIsTyping] = useState(false);
  const [currentTicketId, setCurrentTicketId] = useState<string | null>(null);
  const displayedIds = useRef<Set<string>>(new Set(['welcome']));
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const pollIntervalRef = useRef<any>(null);

  // Tạo customer ID duy nhất cho phiên chat
  const [customerId] = useState(() => {
    return 'guest_' + Math.random().toString(36).substring(2, 10);
  });

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  };

  useEffect(() => {
    scrollToBottom();
  }, [messages, isTyping, isOpen]);

  // Khi có initialMessage từ nút "Hỏi AI" trên Card sản phẩm -> Tự động mở và gửi luôn
  useEffect(() => {
    if (initialMessage && initialMessage.trim()) {
      setIsOpen(true);
      handleSend(initialMessage.trim());
    }
  }, [initialMessage]);

  // Supabase Realtime setup
  useEffect(() => {
    if (!currentTicketId) return;

    let supabase: any;
    try {
      supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
      const channel = supabase
        .channel('store_chat_realtime_' + currentTicketId)
        .on(
          'postgres_changes',
          { event: 'INSERT', schema: 'public', table: 'messages', filter: `ticket_id=eq.${currentTicketId}` },
          (payload: any) => {
            const msg = payload.new;
            if (msg.sender_type === 'bot' || msg.sender_type === 'human') {
              if (!displayedIds.current.has(msg.id)) {
                displayedIds.current.add(msg.id);
                setIsTyping(false);
                if (pollIntervalRef.current) clearInterval(pollIntervalRef.current);
                setMessages((prev) => [
                  ...prev,
                  {
                    id: msg.id,
                    sender_type: msg.sender_type,
                    content: msg.content,
                    timeStr: new Date(msg.created_at || Date.now()).toLocaleTimeString('vi-VN', {
                      hour: '2-digit',
                      minute: '2-digit',
                    }),
                  },
                ]);
              }
            }
          }
        )
        .subscribe();

      return () => {
        supabase.removeChannel(channel);
      };
    } catch (e) {
      console.warn('Realtime init error:', e);
    }
  }, [currentTicketId]);

  const pollForReply = (ticketId: string) => {
    if (pollIntervalRef.current) clearInterval(pollIntervalRef.current);
    let attempts = 0;
    pollIntervalRef.current = setInterval(async () => {
      attempts++;
      if (attempts > 20) {
        clearInterval(pollIntervalRef.current);
        setIsTyping(false);
        return;
      }
      try {
        const res = await fetch(`${BACKEND_URL}/api/v1/tickets/demo-detail/${ticketId}`);
        if (res.ok) {
          const json = await res.json();
          const list = json.data?.messages || [];
          let hasNewReply = false;
          for (const msg of list) {
            if (
              (msg.sender_type === 'bot' || msg.sender_type === 'human') &&
              !displayedIds.current.has(msg.id)
            ) {
              displayedIds.current.add(msg.id);
              setIsTyping(false);
              hasNewReply = true;
              setMessages((prev) => [
                ...prev,
                {
                  id: msg.id,
                  sender_type: msg.sender_type,
                  content: msg.content,
                  timeStr: new Date(msg.created_at || Date.now()).toLocaleTimeString('vi-VN', {
                    hour: '2-digit',
                    minute: '2-digit',
                  }),
                },
              ]);
            }
          }
          if (hasNewReply) {
            clearInterval(pollIntervalRef.current);
          }
        }
      } catch (e) {
        console.error('Poll error:', e);
      }
    }, 600);
  };

  const handleSend = async (customText?: string) => {
    const text = (customText || inputText).trim();
    if (!text) return;

    const userMsgId = 'user_' + Date.now();
    displayedIds.current.add(userMsgId);

    const userMessage: MessageItem = {
      id: userMsgId,
      sender_type: 'customer',
      content: text,
      timeStr: new Date().toLocaleTimeString('vi-VN', { hour: '2-digit', minute: '2-digit' }),
    };

    setMessages((prev) => [...prev, userMessage]);
    if (!customText) setInputText('');
    setIsTyping(true);

    try {
      const res = await fetch(`${BACKEND_URL}/api/v1/messages/incoming`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          customer_id: customerId,
          customer_name: 'Khách Hàng SportGear Store',
          source: 'web',
          content: text,
        }),
      });

      if (res.ok) {
        const json = await res.json();
        if (json.data?.ticket_id) {
          const tId = json.data.ticket_id;
          setCurrentTicketId(tId);
          pollForReply(tId);
        }
      } else {
        throw new Error('Server error');
      }
    } catch (e) {
      console.error('Send error:', e);
      setIsTyping(false);
      setMessages((prev) => [
        ...prev,
        {
          id: 'err_' + Date.now(),
          sender_type: 'bot',
          content: 'Dạ xin lỗi bạn, hệ thống đang xử lý một chút. Bạn có thể gửi lại câu hỏi nhé!',
          timeStr: new Date().toLocaleTimeString('vi-VN', { hour: '2-digit', minute: '2-digit' }),
        },
      ]);
    }
  };

  const handleResetChat = () => {
    if (pollIntervalRef.current) clearInterval(pollIntervalRef.current);
    setCurrentTicketId(null);
    displayedIds.current = new Set(['welcome']);
    setMessages([
      {
        id: 'welcome_' + Date.now(),
        sender_type: 'bot',
        content: DEFAULT_WELCOME,
        timeStr: new Date().toLocaleTimeString('vi-VN', { hour: '2-digit', minute: '2-digit' }),
      },
    ]);
  };

  return (
    <>
      {/* Nút bấm mở Chat Floating */}
      <button
        onClick={() => setIsOpen(!isOpen)}
        className="fixed bottom-6 right-6 w-14 h-14 bg-gradient-to-tr from-sky-600 via-sky-500 to-indigo-600 rounded-full flex items-center justify-center text-white shadow-2xl hover:scale-110 active:scale-95 transition-all z-50 focus:outline-none ring-4 ring-sky-400/30 group cursor-pointer"
        aria-label="Toggle chat"
      >
        {isOpen ? (
          <X className="w-6 h-6" />
        ) : (
          <div className="relative">
            <MessageSquare className="w-6 h-6" />
            <span className="absolute -top-1 -right-1 w-3 h-3 bg-emerald-400 border-2 border-white rounded-full animate-ping"></span>
            <span className="absolute -top-1 -right-1 w-3 h-3 bg-emerald-400 border-2 border-white rounded-full"></span>
          </div>
        )}
      </button>

      {/* Cửa sổ Chatbot Thông Minh */}
      {isOpen && (
        <div className="fixed bottom-24 right-6 w-[410px] max-w-[calc(100vw-2rem)] h-[600px] max-h-[82vh] bg-white rounded-3xl shadow-2xl flex flex-col overflow-hidden z-50 border border-slate-200/90 animate-in fade-in slide-in-from-bottom-5 duration-200">
          {/* Header */}
          <div className="bg-gradient-to-r from-slate-950 via-slate-900 to-sky-950 text-white p-4 flex justify-between items-center shadow-md border-b border-slate-800">
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 bg-gradient-to-tr from-sky-500 to-indigo-600 rounded-2xl flex items-center justify-center text-white relative shadow-md">
                <Bot className="w-5 h-5" />
                <span className="absolute -bottom-0.5 -right-0.5 w-3 h-3 bg-emerald-400 border-2 border-slate-950 rounded-full"></span>
              </div>
              <div>
                <h3 className="font-bold text-sm leading-tight flex items-center gap-1.5 text-white">
                  SportGear AI Assistant
                  <Sparkles className="w-3.5 h-3.5 text-amber-400 fill-amber-400" />
                </h3>
                <p className="text-[11px] text-sky-300 font-medium flex items-center gap-1">
                  <Zap className="w-3 h-3 text-emerald-400 fill-emerald-400" /> Trực Tuyến 24/7 • Phản Hồi Siêu Tốc
                </p>
              </div>
            </div>
            <div className="flex items-center gap-1">
              <button
                onClick={handleResetChat}
                title="Tạo cuộc hội thoại mới"
                className="text-slate-400 hover:text-white p-1.5 rounded-full hover:bg-white/10 transition-colors cursor-pointer"
              >
                <RotateCcw className="w-4 h-4" />
              </button>
              <button
                onClick={() => setIsOpen(false)}
                className="text-slate-400 hover:text-white p-1.5 rounded-full hover:bg-white/10 transition-colors cursor-pointer"
              >
                <X className="w-5 h-5" />
              </button>
            </div>
          </div>

          {/* Messages Body */}
          <div className="flex-1 p-4 overflow-y-auto bg-slate-50 flex flex-col gap-3.5">
            {messages.map((m) => {
              const isCustomer = m.sender_type === 'customer';
              const isHuman = m.sender_type === 'human';

              return (
                <div
                  key={m.id}
                  className={`flex flex-col gap-1 max-w-[90%] ${
                    isCustomer ? 'items-end self-end' : 'items-start self-start'
                  }`}
                >
                  <div
                    className={`p-3.5 shadow-sm rounded-2xl ${
                      isCustomer
                        ? 'bg-gradient-to-r from-sky-600 to-indigo-600 text-white rounded-tr-none'
                        : isHuman
                        ? 'bg-amber-50 border border-amber-200 text-slate-900 rounded-tl-none font-medium'
                        : 'bg-white border border-slate-200/90 text-slate-800 rounded-tl-none'
                    }`}
                  >
                    {isHuman && (
                      <div className="text-[11px] font-bold text-amber-800 mb-1.5 flex items-center gap-1.5 pb-1 border-b border-amber-200">
                        <UserCheck className="w-3.5 h-3.5 text-amber-700" /> Nhân Viên CSKH (Human Live Support)
                      </div>
                    )}
                    <FormattedMessage content={m.content} isCustomer={isCustomer} />
                  </div>
                  <span className="text-[10px] text-slate-400 px-1 font-medium">
                    {isCustomer ? 'Bạn' : isHuman ? 'Chuyên Viên CSKH' : 'SportGear AI'} • {m.timeStr}
                  </span>
                </div>
              );
            })}

            {/* Typing Indicator */}
            {isTyping && (
              <div className="flex flex-col items-start gap-1 max-w-[85%] self-start">
                <div className="bg-white border border-slate-200 px-4 py-3 shadow-sm rounded-2xl rounded-tl-none inline-flex items-center gap-2">
                  <div className="w-2 h-2 bg-sky-500 rounded-full animate-bounce"></div>
                  <div className="w-2 h-2 bg-sky-500 rounded-full animate-bounce [animation-delay:0.2s]"></div>
                  <div className="w-2 h-2 bg-sky-500 rounded-full animate-bounce [animation-delay:0.4s]"></div>
                  <span className="text-[11px] text-slate-400 font-medium pl-1">AI đang soạn câu trả lời...</span>
                </div>
              </div>
            )}
            <div ref={messagesEndRef} />
          </div>

          {/* Quick Prompts */}
          <div className="px-3 py-2 bg-slate-100/90 border-t border-slate-200 flex gap-1.5 overflow-x-auto no-scrollbar">
            {QUICK_PROMPTS.map((prompt, idx) => (
              <button
                key={idx}
                onClick={() => handleSend(prompt)}
                className="text-[11px] font-medium text-slate-700 bg-white hover:bg-sky-50 hover:text-sky-700 hover:border-sky-300 px-3 py-1.5 rounded-full border border-slate-200 shrink-0 shadow-2xs transition-all text-left cursor-pointer active:scale-95"
              >
                {prompt}
              </button>
            ))}
          </div>

          {/* Input Area */}
          <div className="p-3 bg-white border-t border-slate-200 flex gap-2 items-center">
            <input
              type="text"
              value={inputText}
              onChange={(e) => setInputText(e.target.value)}
              onKeyDown={(e) => e.key === 'Enter' && handleSend()}
              placeholder="Nhập câu hỏi tư vấn sản phẩm, freeship, size..."
              className="flex-1 bg-slate-100 border-none rounded-full px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-sky-500 text-slate-800 placeholder:text-slate-400"
            />
            <button
              onClick={() => handleSend()}
              disabled={!inputText.trim()}
              className="w-10 h-10 bg-gradient-to-r from-sky-600 to-indigo-600 hover:opacity-90 disabled:opacity-40 text-white rounded-full flex items-center justify-center transition-all shrink-0 shadow-md cursor-pointer active:scale-95"
            >
              <Send className="w-4 h-4 -translate-x-0.5 translate-y-0.5" />
            </button>
          </div>
        </div>
      )}
    </>
  );
};
