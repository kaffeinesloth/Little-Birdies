# Smart Helpdesk Demo Guide

This guide is for teammates after the latest code is pushed to `main`.

The demo goal is not purchasing/payment or real Zalo OA. The final non-Zalo path shows this support flow:

1. Customer sends a message from the SportGear store chat at `http://localhost:3000`.
2. Backend receives `POST /api/v1/messages/incoming` with `source="web"`.
3. AI service classifies the message and answers or escalates.
4. Flutter staff workspace at `http://localhost:8080` shows the ticket.
5. Employee uses Human Takeover and replies.
6. Ticket is marked resolved.

## 1. Pull Latest Code

```bash
git switch main
git pull
```

## 2. Prepare Environment Files

For a pure fallback startup, `.env` files are optional because Docker Compose supplies blank demo-safe defaults. For live Supabase persistence and seeded tickets, copy the examples:

```bash
cp .env.example .env
cp backend/.env.example backend/.env
cp ai_service/.env.example ai_service/.env
cp store/.env.example store/.env
```

Fill in real values when using Supabase or real Gemini/RAG. Keep `AI_SERVICE_URL=http://ai-service:8001` and `BACKEND_URL=http://backend:8000` inside Docker; use localhost only for manual local runs.
The root `.env` is only for Docker Compose build-time browser values.

Backend values:

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

AI service values:

```env
GOOGLE_API_KEY=
SUPABASE_URL=
SUPABASE_ANON_KEY=
SUPABASE_SERVICE_KEY=
CHROMA_PERSIST_DIR=/data/chroma_db
BACKEND_URL=http://backend:8000
```

Store values are optional and only enable Supabase Realtime; the final demo also works through backend polling when these are blank:

```env
VITE_SUPABASE_URL=
VITE_SUPABASE_ANON_KEY=
```

Flutter web can receive optional Realtime values at build time with `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`. Docker Compose reads browser build values from the root `.env`.

Never commit `.env` files.

## 3. Run With Docker

Build and start all demo services:

```bash
docker compose up --build
```

URLs:

- Store customer chat: http://localhost:3000
- Flutter web admin/mobile responsive app: http://localhost:8080
- Primary staff/admin demo UI: Flutter at http://localhost:8080
- Optional React admin prototype under `web/` is not served by Docker Compose for the final non-Zalo demo.
- Backend API docs: http://localhost:8000/api/docs
- AI service docs: http://localhost:8001/docs
- AI health: http://localhost:8001/health

Quick startup validation:

```bash
docker compose config --services
curl http://localhost:8000/
curl http://localhost:8001/health
curl http://localhost:8000/api/v1/tickets/demo-stats
curl http://localhost:8000/api/v1/documents/demo-list
```

Expected services from `docker compose config --services`:

```text
ai-service
backend
flutter-web
store-website
```

Stop services:

```bash
docker compose down
```

Reset local AI vector data:

```bash
docker compose down -v
```

## 3.1 Seed Non-Zalo Demo Data

For the customer-store final demo, prepare repeatable SportGear tickets and AI knowledge before presenting:

```bash
cd backend
python seed.py

cd ../ai_service
python seed_knowledge.py --mode auto
```

The backend seed is safe by default and refreshes only known SportGear demo tickets. Full ticket/message wipes require `python seed.py --reset-all --yes`.

More details: [docs/DEMO_DATA_SETUP.md](DEMO_DATA_SETUP.md).

## 4. Run Without Docker

Backend:

```bash
cd backend
python3 -m venv .venv
. .venv/bin/activate
pip install -r requirements.txt
uvicorn main:app --reload --port 8000
```

AI service:

```bash
cd ai_service
python3 -m venv .venv
. .venv/bin/activate
pip install -r requirements.txt
uvicorn main:app --reload --port 8001
```

Flutter:

```bash
cd mobile
flutter pub get
flutter run -d chrome
```

## 5. Zalo Official Account Demo Setup

Your friend already created the official Zalo business account. Next steps:

1. Create or open the linked Zalo Developer App.
2. Link the Zalo App with the Official Account.
3. Generate or refresh the OA OpenAPI access token.
4. Put Zalo secrets into `backend/.env`.
5. Expose local backend through HTTPS for webhook testing.

Example with ngrok:

```bash
ngrok http 8000
```

Use the HTTPS URL from ngrok as the webhook base.

Expected webhook URL:

```text
https://YOUR-NGROK-DOMAIN/api/v1/webhooks/zalo
```

Register that URL in the Zalo Developer console.

Important: Zalo sends webhook events with request signatures. The backend should verify `X-ZEvent-Signature` before accepting production traffic. For class demo, only test with known accounts and avoid sending broadcast/marketing messages.

## 6. Demo Script

Use this simple script during presentation:

1. Open Flutter app at http://localhost:8080.
2. Show the web dashboard.
3. Open mobile-sized browser view or phone/emulator to show employee UI.
4. Send a message to the Zalo OA:

```text
San pham bi rach roi, shop xu ly ngay giup minh!
```

5. Explain expected system behavior:
   - Zalo webhook sends the message to backend.
   - Backend stores customer message as source `zalo`.
   - AI service classifies it as complaint/urgent.
   - Ticket appears in staff inbox.
   - Employee taps `Nhan ca`.
   - Employee selects an AI draft, edits it, and sends reply.
   - Ticket is marked `Hoan thanh`.

If the real Zalo webhook is not implemented yet, use the current Flutter UI as the visual demo and explain this is the integration target.

## 7. Current Demo Scope

Included:

- Flutter web admin/staff dashboard.
- Flutter mobile employee UI.
- Backend API structure.
- AI service structure for intent classification and RAG.
- Docker Compose for backend, AI service, and Flutter web.

Still missing for a complete channel demo:

- `/api/v1/webhooks/zalo` backend endpoint.
- Zalo request signature verification.
- Zalo send-message service for staff/AI replies.
- Realtime ticket sync from backend to Flutter.
- Seed data command for repeatable demo setup.

Recommended next implementation task:

```text
Add Zalo webhook endpoint + create source='zalo' tickets + send staff replies back to Zalo OA.
```
