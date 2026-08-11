# Test Commands

All tests are designed to run without real Supabase, Facebook, Email, FCM, OpenAI, or Gemini credentials.

The full local stack can be started with `./start.sh` on macOS/Linux or `.\start.cmd` on Windows.

## Backend API

```sh
cd backend/api
.venv/bin/python -m pytest
```

Covers:

- Auth and RBAC helpers
- Ticket filtering, visibility, assignment, lifecycle transitions, replies, and outbound failure handling
- Inbound message orchestrator question, complaint, spam, and AI timeout paths
- Notifications, presence, heartbeat, and mock FCM persistence
- Facebook, Mailgun, and SendGrid webhook parsing/signature boundaries

## AI Service

```sh
cd backend/ai
.venv/bin/python -m pytest
```

Covers:

- Intent classification for question, complaint, spam, and error fallback
- TXT document processing, chunking, embedding, storage, and size limits
- RAG answer found, no-context escalation, and missing-LLM deterministic fallback

## Web Admin

```sh
cd web
flutter analyze
flutter test
flutter build web
```

Covers:

- Role-based navigation visibility
- Unified Inbox mock ticket rendering
- Dashboard, Knowledge Base, Staff, Channels, and Widget Demo rendering
- Responsive admin shell behavior

## Mobile

```sh
cd mobile
flutter analyze
flutter test
```

Covers:

- Role-aware navigation
- Ticket list rendering
- Online/Offline toggle state
- Ticket detail reply, resolve, and reopen actions

## External Services

No automated test requires external credentials. Provider-specific live checks for Supabase, Facebook Messenger, Mailgun, SendGrid, FCM, OpenAI, or Gemini should be run manually in a configured environment.
