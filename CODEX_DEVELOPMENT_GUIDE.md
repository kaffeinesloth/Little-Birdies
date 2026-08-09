# Codex Development Guide - Smart Helpdesk AI

This guide is a step-by-step prompt sequence for building the full Smart Helpdesk AI project with Codex. Use one prompt at a time. After Codex finishes a step, review the result, run the app or tests when available, then paste the next prompt.

The project source of truth is the latest Smart Helpdesk specification:

- Multi-channel input: Web Widget, Facebook Messenger webhook, Email webhook.
- Orchestrator: receive message, attach `source` and `sender_id`, save message, start AI processing.
- AI Core: classify intent, answer with RAG over ChromaDB, create urgent tickets when needed.
- Output: reply through original channel, update Web Admin, notify Mobile App.
- Roles: `super_admin`, `agent`.
- Core tables: `users`, `tickets`, `messages`, `documents`, `channels`, `notifications`.

## How To Use These Prompts

1. Start with Prompt 01.
2. Do not skip prompts unless the work is already implemented and verified.
3. At the end of each prompt, ask Codex to summarize changed files, verification commands, and the next recommended prompt.
4. If Codex reports a blocker, resolve that blocker before continuing.
5. Keep each implementation step small enough to review.
6. Ask Codex to preserve existing changes and avoid unrelated refactors.

## Global Instructions To Include In Every Prompt

You can prepend this block to any prompt when starting a fresh Codex task:

```text
Use the repository at /Users/kafe/Desktop/AI Integrated Stack/Little-Birdies.
Follow the Smart Helpdesk AI spec from README.md and README.vi.md.
Preserve existing user changes. Do not remove unrelated files.
Use conservative, production-oriented defaults.
After implementation, run the most relevant formatting, linting, or tests available.
At the end, summarize changed files, verification results, and any remaining risks.
```

## Prompt 01 - Create The Monorepo Structure

```text
Create the initial Smart Helpdesk AI monorepo structure.

Requirements:
- Keep the existing README.md, README.vi.md, and CODEX_DEVELOPMENT_GUIDE.md.
- Create a practical monorepo layout:
  - apps/web-admin for the Next.js Web Admin Dashboard and embeddable Chat Widget demo.
  - apps/mobile for the Flutter Mobile App.
  - services/api for the FastAPI backend.
  - services/ai for the FastAPI AI microservice.
  - packages/shared for shared API contracts, schemas, and documentation.
  - infra for Supabase SQL migrations and deployment notes.
  - docs for architecture and API documentation.
- Add root-level .gitignore, .env.example, and a short CONTRIBUTING.md.
- Add README files inside each major folder explaining its purpose.
- Do not install dependencies yet unless required by the scaffold command.

Verification:
- Show the final folder tree.
- Confirm no existing README content was deleted.
```

## Prompt 02 - Scaffold Backend API

```text
Scaffold the services/api FastAPI backend.

Requirements:
- Use Python FastAPI with a clean app structure:
  - app/main.py
  - app/core/config.py
  - app/core/security.py
  - app/db/supabase.py
  - app/models or app/schemas for Pydantic models
  - app/routers for auth, tickets, messages, documents, channels, notifications, webhooks, health
  - app/services for business logic
  - tests
- Add pyproject.toml or requirements.txt, choosing the simplest maintainable option.
- Add environment variables for Supabase URL/key, AI service URL, Facebook, Mailgun/SendGrid, and FCM placeholders.
- Implement /health returning service status.
- Add a README for local backend startup.

Verification:
- Create or run a minimal test for /health.
- Run formatting or linting if configured.
```

## Prompt 03 - Add Supabase Database Schema

```text
Implement the Supabase PostgreSQL schema in infra/supabase/migrations.

Requirements:
- Create SQL migrations for:
  - users
  - tickets
  - messages
  - documents
  - channels
  - notifications
- Include enums:
  - user_role: super_admin, agent
  - user_status: online, offline, disabled
  - channel_type: web, facebook, email
  - ticket_status: open, in_progress, pending, resolved
  - intent_type: question, complaint, spam
  - sender_type: customer, bot, human
  - document_file_type: pdf, docx, txt
  - embedding_status: processing, ready, error
- Add foreign keys and indexes for common reads:
  - tickets by status, source, assigned_to, created_at
  - messages by ticket_id and created_at
  - notifications by recipient_id and is_read
  - documents by embedding_status
- Add updated_at where useful.
- Add seed data for one super_admin and one agent if appropriate, but keep credentials documented as placeholders.
- Document how to apply migrations.

Verification:
- Validate SQL syntax as much as possible locally.
- Explain any parts that must be run inside Supabase.
```

## Prompt 04 - Implement Backend Data Access Layer

```text
Implement the backend data access layer for Supabase.

Requirements:
- Add typed Pydantic schemas for User, Ticket, Message, Document, Channel, Notification.
- Add create/read/update service functions for each core table.
- Implement ticket status transitions:
  - open -> in_progress
  - open/in_progress/pending -> resolved
  - resolved -> open for reopen
- Implement message creation with sender_type validation.
- Implement role-aware ticket query logic:
  - super_admin sees all tickets.
  - agent sees assigned tickets and open tickets.
- Keep channel config handling separated so secrets are never returned directly to frontend clients.

Verification:
- Add unit tests using mocks where Supabase is not available.
- Run tests.
```

## Prompt 05 - Implement Authentication And RBAC

```text
Implement backend authentication and RBAC helpers.

Requirements:
- Validate Supabase JWT tokens for protected API routes.
- Add dependencies/helpers:
  - get_current_user
  - require_super_admin
  - require_agent_or_super_admin
- Protect routes by role:
  - Dashboard, Knowledge Base upload, staff management, and channel settings require super_admin.
  - Inbox, messages, ticket reply, ticket resolve require agent or super_admin.
- Handle disabled users by rejecting access.
- Return clear 401/403 errors.

Verification:
- Add tests for missing token, invalid token, disabled user, agent permission, and super_admin permission.
- Run tests.
```

## Prompt 06 - Implement Tickets And Messages API

```text
Build the Tickets and Messages API in services/api.

Requirements:
- Endpoints:
  - GET /tickets with filters for status, source, assigned_to, search, pagination
  - GET /tickets/{ticket_id}
  - PATCH /tickets/{ticket_id}
  - POST /tickets/{ticket_id}/assign
  - POST /tickets/{ticket_id}/resolve
  - POST /tickets/{ticket_id}/reopen
  - GET /tickets/{ticket_id}/messages
  - POST /tickets/{ticket_id}/messages
- Sending a human message must:
  - save the message with sender_type = human
  - route the outbound response to web, facebook, or email based on ticket.source
  - return a useful error if outbound delivery fails
- For web source, prepare a Supabase Realtime-compatible message record.
- For Facebook and email, use service abstractions with mock implementations until real credentials exist.

Verification:
- Add tests for ticket filtering, role visibility, resolving/reopening, and message creation.
- Run tests.
```

## Prompt 07 - Implement Message Intake Orchestrator

```text
Implement the message intake orchestrator.

Requirements:
- Add a service function process_inbound_message(source, sender_id, content, customer_name=None).
- It must:
  - validate source as web, facebook, or email
  - find or create an open/pending ticket for the same customer/source
  - save the customer message
  - call the AI service for classification/RAG/escalation decision
  - save bot replies when returned
  - create or update ticket state when escalation is needed
  - trigger notifications for online agents
- Add API endpoints for:
  - POST /webhooks/web-message
  - POST /webhooks/facebook
  - POST /webhooks/email
- Keep Facebook and email signature verification as TODO placeholders if credentials are missing, but design the function boundaries.

Verification:
- Add tests for question auto-reply, complaint escalation, spam ignore, and AI timeout fallback.
- Run tests.
```

## Prompt 08 - Scaffold AI Microservice

```text
Scaffold services/ai as a FastAPI AI microservice.

Requirements:
- Create app/main.py, app/core/config.py, app/routers, app/services, app/schemas, tests.
- Endpoints:
  - GET /health
  - POST /classify
  - POST /rag/answer
  - POST /process-message
  - POST /documents/process
- Define request/response schemas for:
  - intent classification
  - RAG answer
  - full AI processing result
  - document processing result
- Add environment config for OpenAI or Gemini API key, embedding model, ChromaDB path/host, confidence threshold.
- Implement deterministic fallback behavior when API keys are missing, so local tests still pass.

Verification:
- Add tests for /health and deterministic fallback /classify.
- Run tests.
```

## Prompt 09 - Implement Intent Classification

```text
Implement AI intent classification in services/ai.

Requirements:
- classify_intent(message_text) returns:
  - intent: question, complaint, or spam
  - confidence
  - short reason
- Use an LLM when configured.
- Provide a deterministic local fallback:
  - complaint for angry/refund/broken/cancel/late/complaint keywords
  - spam for obvious promotions, links, and repeated junk patterns
  - question otherwise
- On LLM timeout or error, default to question according to the project spec.
- Keep prompts short and controlled.
- Add tests for question, complaint, spam, and timeout fallback.

Verification:
- Run tests for services/ai.
```

## Prompt 10 - Implement Document Processing And ChromaDB

```text
Implement the Knowledge Base document processing pipeline in services/ai.

Requirements:
- Support PDF, DOCX, and TXT.
- Enforce 10 MB file size limit at the API boundary.
- Extract text with appropriate libraries.
- Chunk text into useful passages with metadata:
  - document_id
  - file name
  - chunk index
  - source page/section if available
- Generate embeddings using configured provider or deterministic local fallback for tests.
- Store chunks in ChromaDB.
- Return embedding_status: processing, ready, or error.
- Add clear error messages for unsupported file type and failed extraction.

Verification:
- Add tests with small TXT fixture and mocked embedding.
- Run tests.
```

## Prompt 11 - Implement RAG Answering

```text
Implement RAG answering in services/ai.

Requirements:
- rag_answer(question) must:
  - embed the question
  - retrieve top-3 ChromaDB chunks
  - check similarity threshold
  - return answer, citations/chunk metadata, confidence, and should_escalate boolean
- If no chunk is above threshold:
  - return the default apology/escalation message from the spec
  - set should_escalate = true
- If context exists:
  - call LLM to answer using only retrieved context
  - avoid hallucinating policies not in context
- Add tests for answer found and no-context escalation.

Verification:
- Run tests for services/ai.
```

## Prompt 12 - Connect Backend To AI Service

```text
Connect services/api to services/ai.

Requirements:
- Add an AI client in services/api that calls:
  - /classify
  - /rag/answer
  - /process-message
  - /documents/process
- Use timeouts and clear error handling.
- In classifier timeout, default to question and continue RAG.
- In AI process failure, create a pending ticket and save a bot handoff/fallback message.
- Add integration-style tests with mocked HTTP responses.

Verification:
- Run backend tests.
- Document local startup for running both API services.
```

## Prompt 13 - Implement Notifications

```text
Implement notification handling.

Requirements:
- Track user online/offline/disabled status.
- Add endpoint to update current user's Online/Offline state.
- Add heartbeat handling:
  - update last_seen_at
  - mark user offline after 30 seconds without heartbeat, if feasible in current architecture
- When an urgent ticket is created:
  - notify all online agents and super_admin users
  - create rows in notifications table
  - send FCM push notification through an abstraction
- If no agents are online:
  - set ticket status to pending
  - store notifications for later delivery
- Add mock FCM implementation for local development.

Verification:
- Add tests for online agents, no online agents, and notification persistence.
- Run tests.
```

## Prompt 14 - Scaffold Web Admin App

```text
Scaffold apps/web-admin as a Next.js + Tailwind CSS app.

Requirements:
- Use TypeScript.
- Use App Router unless there is a strong reason not to.
- Add pages/routes:
  - /login
  - /inbox
  - /dashboard
  - /knowledge-base
  - /staff
  - /settings/channels
  - /widget-demo
- Add shared layout with navigation that respects role:
  - super_admin sees all sections.
  - agent sees Inbox only.
- Add API client module pointing to services/api.
- Add auth/session placeholders compatible with Supabase Auth.
- Add polished but practical UI components.

Verification:
- Run lint/build if available.
- Start the dev server and provide the local URL.
```

## Prompt 15 - Implement Web Login And RBAC UI

```text
Implement login and role-based navigation in apps/web-admin.

Requirements:
- Login with email/password through Supabase Auth or a mocked local auth mode when env vars are missing.
- Store session safely.
- Fetch current user profile from backend.
- Redirect:
  - super_admin to /dashboard or /inbox
  - agent to /inbox
- Hide unauthorized navigation items.
- Protect routes client-side and handle backend 401/403 responses.
- Show disabled account error clearly.

Verification:
- Add component or e2e tests if the project setup supports them.
- Run lint/build.
```

## Prompt 16 - Implement Unified Inbox UI

```text
Build the Unified Inbox in apps/web-admin.

Requirements:
- Ticket list with:
  - customer name/id
  - source badge: web, facebook, email
  - status
  - intent
  - last message preview
  - timestamp
- Filters:
  - source
  - status
  - assigned/open
  - search
- Conversation panel:
  - full message history
  - sender types: customer, bot, human
  - message composer
  - send button with loading/error states
- Ticket actions:
  - assign to me
  - mark in_progress
  - resolve
  - reopen
- Add Supabase Realtime subscription placeholder or implementation based on available env vars.
- Show reconnect warning and retry state when realtime disconnects.

Verification:
- Run lint/build.
- If possible, test against mocked API data.
```

## Prompt 17 - Implement Dashboard, Knowledge Base, Staff, And Channel Settings

```text
Implement the super_admin-only Web Admin sections.

Requirements:
- Dashboard:
  - total messages today
  - AI handling rate
  - average response time
  - open ticket count
  - 7-day message trend
  - top 5 questions
- Knowledge Base:
  - upload PDF/DOCX/TXT up to 10 MB
  - show processing/ready/error status
  - show chunk_count
  - retry failed processing if backend supports it
- Staff:
  - list users
  - create agent invite placeholder
  - disable/enable agent
  - show online/offline status
- Channel Settings:
  - configure Facebook token placeholder
  - configure Email provider/API key placeholder
  - test connection button placeholder
- Enforce super_admin-only UI and handle 403.

Verification:
- Run lint/build.
```

## Prompt 18 - Implement Chat Widget And Demo Page

```text
Implement the Web Chat Widget and widget demo.

Requirements:
- Create an embeddable widget module in apps/web-admin or a clear package location.
- Widget behavior:
  - floating bottom-right chat button
  - open/close chat panel
  - customer sender_id stored locally
  - send text message to backend web-message endpoint
  - show customer, bot, and human replies
  - show typing indicator while AI/backend is processing
  - show handoff status when ticket is escalated
  - show busy/error fallback when message cannot be saved
- /widget-demo should demonstrate the widget on a simple storefront-like page.
- Keep the widget styling isolated.

Verification:
- Run lint/build.
- Start dev server and manually verify the widget flow with mocked backend if needed.
```

## Prompt 19 - Scaffold Flutter Mobile App

```text
Scaffold apps/mobile as a Flutter app for Smart Helpdesk.

Requirements:
- Pages/screens:
  - Login
  - Inbox
  - Ticket Detail
  - Notifications
  - Simple Dashboard for super_admin
  - Settings/Profile
- Add API client for services/api.
- Add auth/session placeholder compatible with Supabase Auth.
- Add role-aware navigation:
  - both roles can access Inbox and Notifications
  - super_admin can access simple Dashboard
- Add Online/Offline toggle in the main shell.
- Keep UI practical for support agents.

Verification:
- Run flutter analyze.
- Run flutter test if tests exist.
```

## Prompt 20 - Implement Mobile Inbox And Push Flow

```text
Implement core mobile workflows.

Requirements:
- Login with Supabase Auth or local mock mode when env vars are missing.
- Inbox:
  - list assigned/open tickets
  - source badge, status, summary, timestamp
- Ticket Detail:
  - full chat history
  - reply composer
  - resolve/reopen actions
- Online/Offline:
  - update backend status
  - heartbeat while online
- Push notifications:
  - configure FCM placeholders
  - register token with backend if endpoint exists
  - tap notification opens the relevant ticket
  - local mock notification path for development

Verification:
- Run flutter analyze.
- Run flutter test if tests exist.
```

## Prompt 21 - Implement External Channel Integrations

```text
Implement real integration boundaries for Facebook Messenger and Email.

Requirements:
- Facebook:
  - webhook verification endpoint
  - inbound message parsing
  - outbound Send API service
  - clear errors for invalid token and API failure
- Email:
  - inbound webhook parsing for Mailgun or SendGrid
  - outbound email reply service
  - provider abstraction so Mailgun/SendGrid can be swapped
- Keep secrets in environment variables only.
- Never expose channel config secrets in frontend API responses.
- Add tests with sample webhook payloads.

Verification:
- Run backend tests.
- Document required provider setup steps in docs/integrations.md.
```

## Prompt 22 - End-To-End Local Demo

```text
Prepare an end-to-end local demo.

Requirements:
- Add docs/local-demo.md with exact startup steps for:
  - services/ai
  - services/api
  - apps/web-admin
  - apps/mobile, if practical
- Add local mock mode so the demo works without real Supabase, Facebook, Email, FCM, or LLM credentials where possible.
- Demo flow:
  1. Admin logs in.
  2. Admin uploads a sample TXT knowledge-base document.
  3. Customer sends a normal question in widget demo.
  4. AI returns a RAG answer.
  5. Customer sends a complaint.
  6. System creates urgent ticket.
  7. Agent sees ticket in inbox.
  8. Agent replies and resolves ticket.
- Add sample knowledge-base file under docs/demo-data or packages/shared/demo-data.

Verification:
- Run all available tests.
- Start the local services needed for the demo and report URLs.
```

## Prompt 23 - Add Automated Test Coverage

```text
Improve automated test coverage across the project.

Requirements:
- Backend API tests for:
  - auth/RBAC
  - ticket lifecycle
  - message send
  - inbound orchestrator
  - notifications
  - webhook parsing
- AI service tests for:
  - classification
  - document processing
  - RAG found/no-context paths
- Web tests for:
  - role-based navigation
  - inbox rendering
  - message composer states
  - knowledge-base upload validation
- Mobile tests for:
  - ticket list rendering
  - online/offline state
  - ticket detail actions
- Add a root test command or documentation that lists each test command.

Verification:
- Run all feasible tests and document anything that requires external credentials.
```

## Prompt 24 - Security And Production Hardening

```text
Review and harden the app for production readiness.

Requirements:
- Check server-side RBAC on every protected route.
- Ensure channel secrets and API keys are not returned to clients.
- Add input validation for messages, uploads, and webhook payloads.
- Add request size limits for uploads and message content.
- Add safe logging that avoids leaking tokens or customer private data.
- Add CORS configuration for known frontend origins.
- Add rate-limiting plan or implementation for public widget/webhook endpoints.
- Add error handling standards across API and AI services.
- Add docs/security.md with remaining risks and required production setup.

Verification:
- Run tests.
- Provide a concise security review summary with file references.
```

## Prompt 25 - Deployment Preparation

```text
Prepare deployment documentation and config.

Requirements:
- Add docs/deployment.md covering:
  - Supabase project setup and migrations
  - ChromaDB hosting or persistence
  - API deployment on Railway or Render
  - AI service deployment on Railway or Render
  - Web Admin deployment on Vercel
  - Flutter build notes
  - environment variables for each service
- Add example deploy config files only if they fit the chosen platform and do not break local development.
- Add health checks for API and AI services.
- Add production checklist:
  - Supabase RLS reviewed
  - secrets configured
  - webhook URLs configured
  - FCM configured
  - domain/CORS configured
  - demo account created

Verification:
- Run all available tests/builds.
- Report deployment readiness and unresolved external setup items.
```

## Prompt 26 - Final Polish And Demo Script

```text
Polish the project for final presentation.

Requirements:
- Update root README.md and README.vi.md to reflect implemented features and local demo steps.
- Add docs/demo-script.md with a clear final demo narrative:
  1. Business problem.
  2. Admin uploads knowledge base.
  3. Customer asks FAQ.
  4. AI answers instantly.
  5. Customer complains.
  6. AI escalates.
  7. Agent receives ticket/notification.
  8. Agent replies and resolves.
  9. Dashboard updates.
- Add screenshots or placeholders only if generated from the running app.
- Remove obsolete TODOs that no longer apply.
- Keep unresolved limitations documented honestly.

Verification:
- Run final tests/builds.
- Provide a final changed-files summary and demo readiness checklist.
```

## Suggested Milestone Order

| Milestone | Prompts | Outcome |
| --- | --- | --- |
| Foundation | 01-05 | Repo, schema, backend base, auth/RBAC. |
| Core Workflow | 06-13 | Ticketing, orchestrator, AI service, RAG, notifications. |
| Web Product | 14-18 | Admin dashboard, inbox, KB, channel settings, chat widget. |
| Mobile Product | 19-20 | Agent mobile app, online status, ticket handling, push flow. |
| Integrations | 21-22 | External channels and local end-to-end demo. |
| Quality | 23-24 | Tests, security, production hardening. |
| Delivery | 25-26 | Deployment docs, final demo script, README polish. |

## Prompt Template For Fixing A Failed Step

Use this when a step fails or tests break:

```text
The previous step failed. Inspect the current repo state and fix only the issues required to complete that step.

Context:
- The intended step was: [paste the prompt title]
- The failure was: [paste error output or summary]

Requirements:
- Do not restart the project.
- Preserve existing changes.
- Identify the root cause.
- Apply the smallest correct fix.
- Re-run the relevant verification command.
- Summarize the cause, fix, and remaining risk.
```

## Prompt Template For Continuing After Manual Changes

Use this when you edited files manually between Codex tasks:

```text
Continue the Smart Helpdesk AI implementation from the current repo state.

Before changing files:
- Inspect git status.
- Read the files relevant to the next prompt.
- Preserve manual changes and do not revert unrelated edits.

Next prompt to implement:
[paste the next prompt here]
```

