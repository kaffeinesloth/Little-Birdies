# Non-Zalo Final Demo Completion Guide

Owner: teammate finishing the main Smart Helpdesk demo without real Zalo.

Real Zalo OA is handled separately in `docs/ZALO_OA_INTEGRATION_GUIDE.md`. Your part is to make the product demo work end to end using the existing web/customer simulation flow.

## Final Demo Target

The final non-Zalo demo should show:

1. Customer opens SportGear store chat.
2. Customer sends a normal FAQ question.
3. Backend creates/reuses ticket and stores customer message.
4. AI service classifies the message and answers using SportGear knowledge.
5. Bot reply appears in customer chat.
6. Customer sends complaint/escalation.
7. Ticket appears in staff inbox as complaint/handoff.
8. Staff uses Flutter admin/mobile UI to reply.
9. Customer sees human reply.
10. Staff marks ticket resolved.
11. Dashboard/analytics reflect useful demo data.

Use `source = "web"` for your customer simulation unless the Zalo teammate has already completed schema/model support for `zalo`.

## Current Repo Map

### Backend

- `backend/main.py`
  - FastAPI app.
  - API docs at `/api/docs`.
  - Routers under `/api/v1`.
- `backend/api/routers/messages.py`
  - `POST /api/v1/messages/incoming`: customer message path used by store chat.
  - `POST /api/v1/messages/agent-reply-demo`: unauthenticated staff reply used by Flutter demo.
  - `POST /api/v1/messages/bot-reply`: internal callback used by AI service.
- `backend/api/routers/tickets.py`
  - `GET /api/v1/tickets/demo-list`: Flutter ticket list.
  - `GET /api/v1/tickets/demo-detail/{ticket_id}`: store polling and Flutter detail.
  - `GET /api/v1/tickets/demo-ai-suggest/{ticket_id}`: AI draft suggestions.
  - `PATCH /api/v1/tickets/demo-status/{ticket_id}`: resolve/in-progress.
  - Demo stats/product issue/agent performance endpoints.
- `backend/api/routers/documents.py`
  - Demo knowledge list/upload/delete proxying to AI service.
- `backend/api/routers/users.py`
  - Demo staff list/create/delete/status.
- `backend/seed.py`
  - Repeatably seeds SportGear tickets/messages/channels in Supabase.
  - Safe default refreshes only known demo tickets; full wipe requires `--reset-all --yes`.
- `backend/supabase_schema.sql`
  - Current source/channel constraints are only `web`, `facebook`, `email`.

### AI Service

- `ai_service/main.py`
  - FastAPI app.
  - Health at `/health`.
  - Process endpoint at `/process`.
- `ai_service/routers/process.py`
  - Calls orchestrator.
  - Calls backend `/api/v1/messages/bot-reply` when it has a reply.
- `ai_service/agent/orchestrator.py`
  - Intent classification, RAG, handoff behavior.
- `ai_service/rag/vector_store.py`
  - ChromaDB vector store using local Chroma default embedding function.
- `ai_service/knowledge_data/sportgear_store.txt`
  - Main SportGear knowledge seed.
- `ai_service/seed_knowledge.py`
  - Seeds SportGear knowledge through AI service upload or direct local Chroma indexing.
- `ai_service/smoke_test.py`
  - Mocked smoke tests without real API key.

### Frontends

- `store/src/components/ChatWidget.tsx`
  - Customer chat widget.
  - Posts to `http://localhost:8000/api/v1/messages/incoming`.
  - Uses hardcoded `source: "web"`.
  - Listens to Supabase Realtime and falls back to polling `/tickets/demo-detail/{ticketId}`.
- `store/`
  - Vite React customer store.
  - `docker-compose.yml` builds and serves it at port `3000`.
- `mobile/lib/main.dart`
  - Flutter web/mobile staff workspace.
  - Loads demo tickets, messages, stats, users, documents.
  - Sends staff replies through `/messages/agent-reply-demo`.
  - Resolves tickets through `/tickets/demo-status/{ticket_id}`.
  - Uses polling plus Supabase Realtime.
- `web/`
  - Optional React Vite admin prototype for staff management and analytics.
  - Not wired into Docker Compose and not part of the final non-Zalo demo path.
  - Use Flutter at `http://localhost:8080` as the primary staff/admin UI.
  - Does not contain the main support inbox.

### Docker

- `docker-compose.yml`
  - Builds backend.
  - Builds AI service.
  - Builds Flutter web at port `8080`.
  - Builds and serves the customer store at port `3000`.
  - Does not serve `web/`.

## Main Known Risks To Fix

1. Knowledge base should be seeded into Chroma before demo, or the deterministic fallback will answer instead of RAG.
2. Supabase credentials are currently hardcoded in Flutter/store code. For class demo this may pass, but final cleanup should at least document it and avoid committing service-role secrets.
3. `backend/seed.py --reset-all --yes` clears tickets/messages in live Supabase. Use it intentionally.

## Recommended Work Order

1. Audit and run the app as-is.
2. Fix customer chat/store serving.
3. Stabilize backend incoming/reply/dedupe behavior.
4. Stabilize AI service fallback and knowledge seeding.
5. Stabilize Flutter inbox/reply/resolve behavior.
6. Make dashboard/staff/document demo screens graceful.
7. Fix Docker/demo startup.
8. Run full end-to-end tests.
9. Write final presenter guide.
10. Do cleanup/readiness report.

## Step-By-Step Prompts To Paste Into Codex

Paste one prompt at a time. Do not skip the verification prompts.

### Prompt 1: Read Current Program

```text
Re-audit the current Smart Helpdesk repo for the non-Zalo final demo. Do not edit files yet.

Ignore real Zalo OA because another teammate owns it.

Read:
- README.md
- FRONTEND_INTEGRATION.md
- docs/TEAM_DEMO_GUIDE.md
- docs/NON_ZALO_DEMO_COMPLETION_GUIDE.md
- docker-compose.yml
- backend/main.py
- backend/api/routers/messages.py
- backend/api/routers/tickets.py
- backend/api/routers/documents.py
- backend/api/routers/users.py
- backend/core/database.py
- backend/core/auth.py
- backend/supabase_schema.sql
- backend/seed.py
- ai_service/main.py
- ai_service/routers/process.py
- ai_service/agent/orchestrator.py
- ai_service/rag
- ai_service/seed_knowledge.py
- ai_service/smoke_test.py
- store/src/components/ChatWidget.tsx
- mobile/lib/main.dart
- web/src

Return:
1. What currently works.
2. What blocks the final non-Zalo demo.
3. Exact files to edit first.
4. Exact validation commands to run.
```

### Prompt 2: Fix Store Build And Serving

```text
Fix the customer store/chat serving path for the final demo.

Current issue: docker-compose.yml serves ./store/dist, but store has Vite source with no package.json and no dist.

Implement the smallest clean fix. Options:
- Add a proper store/package.json and Docker build path, or
- Add a store build service/stage in Docker Compose, or
- Move/align store with an existing Vite setup if that is cleaner.

Do not redesign the store. Preserve store/src/components/ChatWidget.tsx behavior.

Validation:
- Store can be built.
- Store can be served at http://localhost:3000 through the documented demo path.
- Chat widget loads visually.
```

### Prompt 3: Stabilize Customer Incoming Flow

```text
Stabilize the backend customer incoming flow used by the store chat.

Focus on POST /api/v1/messages/incoming and the AI callback path.

Requirements:
- Create/reuse ticket by customer_id + source.
- Store customer message.
- Call ai_service /process.
- Store bot reply exactly once.
- If AI service fails, keep ticket/message and return a safe accepted response.
- If AI returns HANDOFF, mark ticket intent/status clearly for staff demo.
- Preserve existing demo endpoints.

Check whether /process callback to /messages/bot-reply plus backend reply insertion can duplicate bot messages. Fix if needed.

Validate with curl or a smoke script using source='web'.
```

### Prompt 4: Stabilize AI Service Fallback

```text
Make ai_service reliable for class demo even when GOOGLE_API_KEY is missing or remote LLM calls fail.

Requirements:
- /health works.
- /process always returns a useful response for demo inputs instead of crashing.
- FAQ messages about SportGear products, size, shipping, return, warranty produce useful answers.
- Complaint/angry/escalation messages return HANDOFF or equivalent action and a handoff acknowledgement.
- Keep real LLM/RAG path when keys and knowledge are available.
- Add minimal deterministic fallback only where needed.

Run ai_service/smoke_test.py and any relevant pytest tests if dependencies are available.
```

### Prompt 5: Seed Knowledge And Demo Data

```text
Make demo data setup repeatable.

Requirements:
- backend/seed.py can seed tickets/messages/channels safely with clear instructions.
- ai_service/seed_knowledge.py can seed ai_service/knowledge_data/sportgear_store.txt into ChromaDB.
- Add or update documentation/scripts so a presenter can prepare Supabase ticket data and AI knowledge before demo.
- Do not silently wipe data without clear warning.

Validate:
- Seed backend data.
- Seed AI knowledge.
- Confirm /api/v1/documents/demo-list shows a useful knowledge document.
```

### Prompt 6: Fix Store Chat End-To-End

```text
Make store/src/components/ChatWidget.tsx reliable end to end.

Requirements:
- Customer sends message.
- Backend returns ticket_id.
- Bot or human replies appear via Supabase Realtime or polling fallback.
- Typing state stops on success, timeout, or error.
- Reset chat starts a new conversation safely.
- No duplicate bot/human messages in common demo path.
- Error message is friendly.

Keep the current visual design. Test at least:
- "Shop có freeship không?"
- "Áo Polo Pro Active giá bao nhiêu và có size L không?"
- "Sản phẩm bị rách rồi, shop xử lý ngay giúp mình!"
```

### Prompt 7: Stabilize Flutter Inbox

```text
Stabilize mobile/lib/main.dart for the staff-side final demo.

Requirements:
- Ticket list loads from /tickets/demo-list.
- Ticket detail loads from /tickets/demo-detail/{ticket_id}.
- Source/status/intent badges are correct for web/facebook/email.
- Selecting a ticket fetches messages and AI suggestions.
- Staff reply through /messages/agent-reply-demo is stored and visible.
- Human takeover status is clear.
- Resolve updates ticket via /tickets/demo-status/{ticket_id}.
- Polling/realtime does not visibly duplicate messages during the demo.
- Empty backend falls back to demo data without crashing.

Do not redesign the whole UI. Focus on demo reliability.
```

### Prompt 8: Stabilize Analytics And Staff Screens

```text
Stabilize the analytics/staff/demo admin screens.

Check both:
- Flutter app dashboard/staff/documents sections in mobile/lib/main.dart.
- React web app in web/src if it will be shown.

Requirements:
- Demo stats endpoints return useful values even with low data.
- Product issue and knowledge gap sections do not crash when empty.
- Staff list/create/delete/status demo endpoints work or fail gracefully.
- Document upload/list/delete demo endpoints work or fail gracefully.
- If React web app is not part of Docker/final demo, document that Flutter is the primary admin UI.
```

### Prompt 9: Docker And Local Runbook

```text
Make the non-Zalo demo startup reliable.

Requirements:
- docker compose up --build starts backend, ai-service, Flutter web, and customer store.
- Backend API docs: http://localhost:8000/api/docs
- AI health: http://localhost:8001/health
- Flutter staff UI: http://localhost:8080
- Store customer chat: http://localhost:3000
- If web/ React admin should be shown, add clear run command or Docker service. If not, document it as optional.

Fix Dockerfiles, compose, env examples, or documentation as needed.
```

### Prompt 10: Full Non-Zalo E2E Test

```text
Run the full non-Zalo final demo test and fix blockers.

Test script:
1. Open store at http://localhost:3000.
2. Send: "Shop có freeship không?"
   Expected: AI/bot answers shipping policy.
3. Send: "Áo Polo Pro Active giá bao nhiêu và có size L không?"
   Expected: AI/bot answers product/size info.
4. Send: "Sản phẩm bị rách rồi, shop xử lý ngay giúp mình!"
   Expected: ticket is complaint/handoff and visible to staff.
5. Open Flutter staff UI at http://localhost:8080.
6. Select the new ticket.
7. Send a human reply.
8. Confirm reply appears in store chat.
9. Mark ticket resolved.
10. Confirm dashboard/status updates.

Report commands run, files changed, and any remaining risk.
```

### Prompt 11: Final Presenter README

```text
Create docs/FINAL_DEMO_GUIDE.md for the non-Zalo final presentation.

Include:
- What the demo proves.
- Startup commands.
- Required env files and values placeholders.
- Optional seed commands.
- URLs to open.
- Exact customer messages to type.
- Expected AI behavior.
- Staff actions in Flutter.
- How to resolve a ticket.
- How to explain Zalo if partner has not finished real OA.
- Troubleshooting checklist.

Keep it practical for a live class demo. Do not overload it with implementation details.
```

### Prompt 12: Final Cleanup And Readiness Report

```text
Do final cleanup for the non-Zalo demo.

Tasks:
- Ensure no service-role secrets or private tokens are committed.
- Ensure env examples are accurate.
- Ensure README/demo docs match actual ports and commands.
- Remove or reduce noisy debug output only where safe.
- Keep useful backend/AI logs.
- Run final smoke checks.

Return a readiness report:
- Ready / partially ready / blocked.
- What was tested.
- Remaining issues.
- What the Zalo teammate still owns.
```

## Presenter Fallback If Zalo Is Not Ready

Say:

```text
In this demo, the customer channel is simulated through the web chat widget. The ticket pipeline is the same one a real channel uses: backend receives message, AI classifies/responds or escalates, staff takes over, and the ticket is resolved. Real Zalo OA integration is a separate channel adapter being implemented from docs/ZALO_OA_INTEGRATION_GUIDE.md.
```

## Minimum Acceptance Criteria

Your part is done when:

- `http://localhost:3000` customer chat works.
- `POST /api/v1/messages/incoming` works with `source="web"`.
- AI FAQ reply works or deterministic fallback works.
- Complaint creates visible staff ticket/handoff.
- `http://localhost:8080` Flutter staff UI can reply and resolve.
- Demo docs explain startup, seed, and fallback clearly.
