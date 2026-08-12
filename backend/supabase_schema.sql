-- ============================================================================
-- Smart Helpdesk — AI-Powered Customer Support System
-- Supabase Schema (PostgreSQL)
-- ============================================================================

-- Bật extension tự tạo UUID
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================================
-- 1. Bảng users
-- Lưu tài khoản nội bộ: super_admin và agent.
-- Tài khoản được tạo qua Supabase Auth; trigger bên dưới tự đồng bộ.
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.users (
    id          UUID         PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email       VARCHAR(255) UNIQUE NOT NULL,
    full_name   VARCHAR(100) NOT NULL,
    role        VARCHAR(20)  NOT NULL DEFAULT 'agent'
                             CHECK (role IN ('super_admin', 'agent')),
    status      VARCHAR(20)  NOT NULL DEFAULT 'offline'
                             CHECK (status IN ('online', 'offline', 'disabled')),
    avatar_url  TEXT,
    fcm_token   TEXT,                              -- Firebase Cloud Messaging token cho push notification
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    last_seen_at TIMESTAMPTZ
);

-- ============================================================================
-- 2. Bảng channels
-- Cấu hình kênh chat: web, facebook, email.
-- Mỗi loại kênh chỉ có 1 bản ghi (UNIQUE type).
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.channels (
    id           UUID    PRIMARY KEY DEFAULT uuid_generate_v4(),
    type         VARCHAR(20) NOT NULL UNIQUE
                              CHECK (type IN ('web', 'facebook', 'email')),
    config       JSONB   NOT NULL DEFAULT '{}',    -- Chứa token, API key, webhook URL
    is_active    BOOLEAN NOT NULL DEFAULT false,
    connected_at TIMESTAMPTZ
);

-- Seed 3 kênh mặc định (chưa kết nối)
INSERT INTO public.channels (type) VALUES ('web'), ('facebook'), ('email')
ON CONFLICT (type) DO NOTHING;

-- ============================================================================
-- 3. Bảng tickets
-- Mỗi ticket đại diện cho 1 phiên hội thoại của 1 khách hàng.
-- Được tạo tự động bởi AI khi phát hiện complaint hoặc RAG thất bại.
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.tickets (
    id              UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_name   VARCHAR(100),
    customer_id     VARCHAR(255) NOT NULL,          -- sender_id từ kênh (PSID, email addr, session id)
    source          VARCHAR(20)  NOT NULL
                                 CHECK (source IN ('web', 'facebook', 'email')),
    status          VARCHAR(20)  NOT NULL DEFAULT 'open'
                                 CHECK (status IN ('open', 'in_progress', 'pending', 'resolved')),
    intent          VARCHAR(20)
                                 CHECK (intent IN ('question', 'complaint', 'spam')),
    summary         TEXT,                           -- Tóm tắt nội dung do AI sinh ra
    assigned_to     UUID         REFERENCES public.users(id) ON DELETE SET NULL,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    resolved_at     TIMESTAMPTZ
);

-- ============================================================================
-- 4. Bảng messages
-- Lưu từng tin nhắn trong 1 ticket.
-- sender_type phân biệt: khách hàng / bot AI / nhân viên thật.
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.messages (
    id          UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    ticket_id   UUID        NOT NULL REFERENCES public.tickets(id) ON DELETE CASCADE,
    sender_type VARCHAR(20) NOT NULL
                             CHECK (sender_type IN ('customer', 'bot', 'human')),
    sender_id   VARCHAR(255) NOT NULL,              -- user_id (nhân viên) hoặc customer_id
    content     TEXT        NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- 5. Bảng documents
-- Tài liệu nghiệp vụ do super_admin upload để làm knowledge base cho AI.
-- Sau khi upload, document processor sẽ chunk + embed + lưu vào ChromaDB.
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.documents (
    id               UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    name             VARCHAR(255) NOT NULL,
    file_url         TEXT        NOT NULL,          -- Đường dẫn file trên Supabase Storage
    file_type        VARCHAR(10) NOT NULL
                                  CHECK (file_type IN ('pdf', 'docx', 'txt')),
    embedding_status VARCHAR(20) NOT NULL DEFAULT 'processing'
                                  CHECK (embedding_status IN ('processing', 'ready', 'error')),
    chunk_count      INTEGER,                       -- Số đoạn sau khi chunking
    uploaded_by      UUID        NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- 6. Bảng notifications
-- Lưu push notification gửi đến agent khi có ticket khẩn cấp.
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.notifications (
    id           UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    ticket_id    UUID        NOT NULL REFERENCES public.tickets(id) ON DELETE CASCADE,
    recipient_id UUID        NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    title        VARCHAR(255) NOT NULL,
    body         TEXT        NOT NULL,
    is_read      BOOLEAN     NOT NULL DEFAULT false,
    sent_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- INDEXES — Tối ưu các query phổ biến
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_tickets_status      ON public.tickets(status);
CREATE INDEX IF NOT EXISTS idx_tickets_assigned_to ON public.tickets(assigned_to);
CREATE INDEX IF NOT EXISTS idx_tickets_customer_id ON public.tickets(customer_id);
CREATE INDEX IF NOT EXISTS idx_messages_ticket_id  ON public.messages(ticket_id);
CREATE INDEX IF NOT EXISTS idx_messages_created_at ON public.messages(created_at);
CREATE INDEX IF NOT EXISTS idx_notifications_recipient_id ON public.notifications(recipient_id);
CREATE INDEX IF NOT EXISTS idx_notifications_is_read      ON public.notifications(is_read);

-- ============================================================================
-- SUPABASE AUTH TRIGGER
-- Khi Supabase Auth tạo user mới (qua invite email), tự động tạo bản ghi
-- trong public.users. Super admin phải set role thủ công sau khi tạo.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO public.users (id, email, full_name, role)
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'full_name', 'New Agent'),
        COALESCE(NEW.raw_user_meta_data->>'role', 'agent')
    )
    ON CONFLICT (id) DO NOTHING;
    RETURN NEW;
END;
$$;

-- Chỉ tạo trigger nếu chưa tồn tại
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================================================

-- Bật RLS cho tất cả các bảng
ALTER TABLE public.users          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.channels       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tickets        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.documents      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications  ENABLE ROW LEVEL SECURITY;

-- Helper function: lấy role của user hiện tại
CREATE OR REPLACE FUNCTION public.get_my_role()
RETURNS TEXT
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT role FROM public.users WHERE id = auth.uid();
$$;

-- ---- users ----
-- User chỉ xem được chính mình; super_admin xem tất cả
CREATE POLICY "users_select" ON public.users FOR SELECT
    USING (id = auth.uid() OR public.get_my_role() = 'super_admin');

-- Chỉ super_admin mới được UPDATE users khác (đổi role, disable)
CREATE POLICY "users_update" ON public.users FOR UPDATE
    USING (id = auth.uid() OR public.get_my_role() = 'super_admin');

-- ---- channels ----
-- Mọi user đã đăng nhập đều xem được kênh
CREATE POLICY "channels_select" ON public.channels FOR SELECT
    USING (auth.uid() IS NOT NULL);

-- Chỉ super_admin mới được cấu hình kênh
CREATE POLICY "channels_modify" ON public.channels FOR ALL
    USING (public.get_my_role() = 'super_admin');

-- ---- tickets ----
-- Super admin thấy tất cả; agent chỉ thấy ticket được giao hoặc đang mở
CREATE POLICY "tickets_select" ON public.tickets FOR SELECT
    USING (
        public.get_my_role() = 'super_admin'
        OR status IN ('open', 'in_progress')
        OR assigned_to = auth.uid()
    );

-- Mọi user đã đăng nhập có thể UPDATE ticket (đổi status, assigned_to)
CREATE POLICY "tickets_update" ON public.tickets FOR UPDATE
    USING (auth.uid() IS NOT NULL);

-- Chỉ backend service role (service_key) mới INSERT ticket (qua AI)
-- Frontend không gọi trực tiếp
CREATE POLICY "tickets_insert" ON public.tickets FOR INSERT
    WITH CHECK (auth.role() = 'service_role');

-- ---- messages ----
-- Cùng logic với tickets: xem theo quyền ticket cha
CREATE POLICY "messages_select" ON public.messages FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.tickets t
            WHERE t.id = messages.ticket_id
              AND (
                  public.get_my_role() = 'super_admin'
                  OR t.status IN ('open', 'in_progress')
                  OR t.assigned_to = auth.uid()
              )
        )
    );

-- Agent INSERT message khi reply
CREATE POLICY "messages_insert" ON public.messages FOR INSERT
    WITH CHECK (auth.uid() IS NOT NULL);

-- ---- documents ----
-- Mọi user xem được danh sách KB (để biết AI đang dùng tài liệu gì)
CREATE POLICY "documents_select" ON public.documents FOR SELECT
    USING (auth.uid() IS NOT NULL);

-- Chỉ super_admin mới upload / xóa tài liệu
CREATE POLICY "documents_modify" ON public.documents FOR ALL
    USING (public.get_my_role() = 'super_admin');

-- ---- notifications ----
-- Mỗi user chỉ xem notification của chính mình
CREATE POLICY "notifications_select" ON public.notifications FOR SELECT
    USING (recipient_id = auth.uid());

CREATE POLICY "notifications_update" ON public.notifications FOR UPDATE
    USING (recipient_id = auth.uid());

-- ============================================================================
-- SUPABASE REALTIME
-- Bật realtime cho các bảng cần sync live giữa Web Admin và Mobile App
-- ============================================================================
ALTER PUBLICATION supabase_realtime ADD TABLE public.tickets;
ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;

-- ============================================================================
-- STORAGE
-- Bucket dùng cho Knowledge Base uploads.
-- ============================================================================
INSERT INTO storage.buckets (id, name, public)
VALUES ('knowledge-base', 'knowledge-base', true)
ON CONFLICT (id) DO NOTHING;

-- ============================================================================
-- FIRST ADMIN SETUP
-- Sau khi tạo user đầu tiên bằng màn hình Sign up của web app, chạy câu này
-- trong Supabase SQL Editor và thay email bằng email của bạn:
--
-- UPDATE public.users
-- SET role = 'super_admin', status = 'online'
-- WHERE email = 'your-email@example.com';
-- ============================================================================
