# Final Non-Zalo Demo Guide

Use this guide for the live class presentation. The demo uses the SportGear store web chat instead of real Zalo OA.

## What The Demo Proves

This demo proves the core Smart Helpdesk workflow:

1. A customer sends a message from the store chat.
2. Backend creates or reuses a ticket with `source="web"`.
3. AI answers common SportGear questions automatically.
4. Complaints are marked for human handoff.
5. Staff sees the ticket in Flutter, sends a live reply, and resolves it.
6. Dashboard numbers update from the demo ticket state.

The demo is not about checkout, payment, or real Zalo OA.

## Required Env Files

For the fallback class demo, `.env` files are optional. The app can still run with deterministic demo answers when Supabase or Gemini is missing.

For live Supabase persistence and real RAG/LLM, create these files:

```bash
cp .env.example .env
cp backend/.env.example backend/.env
cp ai_service/.env.example ai_service/.env
cp store/.env.example store/.env
```

The root `.env` is only for Docker Compose build-time browser values.

Backend placeholders:

```env
SUPABASE_URL=
SUPABASE_ANON_KEY=
SUPABASE_SERVICE_KEY=
AI_SERVICE_URL=http://ai-service:8001

FB_VERIFY_TOKEN=
FB_APP_SECRET=

ZALO_APP_ID=
ZALO_OA_ID=
ZALO_OA_SECRET_KEY=
ZALO_ACCESS_TOKEN=
ZALO_REFRESH_TOKEN=

MAILGUN_SIGNING_KEY=
```

AI service placeholders:

```env
GOOGLE_API_KEY=
SUPABASE_URL=
SUPABASE_ANON_KEY=
SUPABASE_SERVICE_KEY=
CHROMA_PERSIST_DIR=/data/chroma_db
BACKEND_URL=http://backend:8000
```

Store placeholders, only needed if you want Supabase Realtime instead of polling:

```env
VITE_SUPABASE_URL=
VITE_SUPABASE_ANON_KEY=
```

Flutter web can also receive optional Supabase Realtime values at build time. Docker Compose reads browser build values from the root `.env`:

```bash
flutter build web --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```

Do not commit `.env` files.

## Startup Commands

Recommended demo startup:

```bash
docker compose up --build
```

Expected services:

```bash
docker compose config --services
```

Expected output:

```text
ai-service
backend
flutter-web
store-website
```

Quick health checks:

```bash
curl http://localhost:8001/health
curl http://localhost:8000/api/v1/tickets/demo-stats
curl http://localhost:8000/api/v1/documents/demo-list
```

Stop after the demo:

```bash
docker compose down
```

## Optional Seed Commands

Use these when Supabase credentials are configured and you want repeatable starting data.

Backend tickets/channels:

```bash
cd backend
python seed.py
```

AI knowledge:

```bash
cd ai_service
python seed_knowledge.py --mode auto
```

Warning: only use this when you intentionally want to wipe all connected ticket/message data:

```bash
cd backend
python seed.py --reset-all --yes
```

## URLs To Open

Open these before presenting:

- Customer store chat: http://localhost:3000
- Flutter staff/admin UI: http://localhost:8080
- Backend API docs: http://localhost:8000/api/docs
- AI health: http://localhost:8001/health

Flutter at `http://localhost:8080` is the primary staff/admin UI for the final demo. The React app under `web/` is optional and not part of the Docker demo path.

## Customer Messages To Type

In the store chat at `http://localhost:3000`, type these in order:

```text
Shop có freeship không?
```

Expected: AI explains freeship from 500.000đ and shipping fee for smaller orders.

```text
Áo Polo Pro Active giá bao nhiêu và có size L không?
```

Expected: AI answers product price, size L availability, and size guidance.

```text
Sản phẩm bị rách rồi, shop xử lý ngay giúp mình!
```

Expected: AI apologizes, acknowledges the complaint, and marks the ticket for human handoff.

## Staff Actions In Flutter

In Flutter at `http://localhost:8080`:

1. Stay on `Live Chat & CSKH`.
2. Select the newest `Web Store` ticket.
3. Confirm the ticket detail shows the customer messages.
4. For complaint flow, point out the complaint/handoff status badge.
5. Type a human reply, for example:

```text
Dạ SportGear đã nhận yêu cầu, bên em sẽ đổi sản phẩm mới và miễn phí ship 2 chiều cho mình ạ.
```

6. Click `Gửi Trực Tiếp`.
7. Go back to the store chat and confirm the human reply appears.

## Resolve A Ticket

In the selected Flutter ticket:

1. Click `Hoàn Tất & Đóng`.
2. Confirm the ticket badge changes to resolved/completed.
3. Open `Báo Cáo & Doanh Số`.
4. Point out that ticket counts and channel distribution are still visible.

## How To Explain Zalo

If the Zalo teammate has not finished real OA integration, say this:

```text
Today we are demoing the completed non-Zalo customer support pipeline through the web store chat. The channel adapter is different, but the core flow is the same: customer message enters the backend, AI answers or escalates, staff takes over in Flutter, and the ticket is resolved. Real Zalo OA is owned as a separate integration task and will plug into the same backend ticket pipeline.
```

Do not claim real Zalo webhook or outbound OA reply is working unless the Zalo teammate has verified it.

## Troubleshooting Checklist

If a page does not open:

```bash
docker compose ps
docker compose logs backend
docker compose logs ai-service
docker compose logs store-website
docker compose logs flutter-web
```

If the AI does not answer:

```bash
curl http://localhost:8001/health
curl http://localhost:8000/api/v1/tickets/demo-stats
```

Fallback answers should still work when `GOOGLE_API_KEY` is blank.

If the store chat does not show staff replies:

1. Keep the store chat open on the same conversation.
2. Wait a few seconds for polling.
3. Confirm the staff reply appears in Flutter first.
4. If needed, reset the chat and create a fresh ticket.

If Flutter shows no tickets:

```bash
curl http://localhost:8000/api/v1/tickets/demo-list
```

If Supabase seed fails:

1. Check `backend/.env`.
2. Confirm `SUPABASE_URL` and `SUPABASE_SERVICE_KEY` are real.
3. Skip seeding and continue with fallback demo data if time is short.

If document list is empty:

```bash
curl http://localhost:8000/api/v1/documents/demo-list
```

The presenter UI should still show the SportGear fallback document when real document storage is unavailable.
