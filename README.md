# Smart Helpdesk - AI-Powered Customer Support System

Smart Helpdesk is a SaaS platform that helps small and medium online businesses automate customer support with an AI Agent, Retrieval-Augmented Generation (RAG), and a simple ticketing workflow. The system can answer common customer questions automatically, classify message intent, and escalate urgent complaints to human staff through a mobile app.

> **Running the project on Windows?** See the beginner-friendly [`STARTUP_GUIDE.md`](STARTUP_GUIDE.md) for one-command startup and shutdown instructions.

> Tagline: "Tự động hóa CSKH. Xử lý khiếu nại tức thì."

## Team Information

| # | Full Name | Student ID | Role | Responsibilities |
| --- | --- | --- | --- | --- |
| 1 | Huỳnh Bá Anh Khoa | N22DCCN141 | Frontend Developer | Build the frontend app and web experience, including the Web Admin Dashboard, chat widget UI, demo chat page, and responsive interface |
| 2 | Vũ Kim Long | N22DCCN050 | Backend Developer | Develop REST APIs, database models, ticket workflow, authentication, and service integrations |
| 3 | Trần Tuấn Hải | N22DCCN026 | AI Engineer | Build the RAG pipeline, intent classification, AI answer generation, and LLM integration |
| 4 | Đặng Nhật Nam | N22DCDT038 | Frontend Support & Testing | Support frontend development, test user flows, support report writing, and validate feature requirements |
| 5 | Tạ Quang An | N22DCAT003 | AI Engineer - Infrastructure | Set up ChromaDB/VectorDB, build the document processor pipeline (PDF to chunks to embeddings), and implement FastAPI endpoints for the AI microservice |


## Project Overview

| Field | Detail |
| --- | --- |
| Project name | Smart Helpdesk - AI-Powered Customer Support System |
| Tagline | "Tự động hóa CSKH. Xử lý khiếu nại tức thì." |
| Type | SaaS Platform: Web + Mobile App + AI Agent |
| Domain | Customer Service / SaaS |
| Target users | Small and medium online shop owners, e-commerce sellers, and customer service staff |
| Core technology | LLM, RAG, LangChain, FastAPI, Supabase, Flutter |
| Main goal | Reduce repetitive customer service work and prevent urgent customer messages from being missed |
| Development timeline | 3 weeks |

## Implemented Demo Status

This repository now contains a local-demo-ready Smart Helpdesk AI monorepo:

- `services/api`: FastAPI backend with health check, mocked Supabase-compatible data access, auth/RBAC dependencies, ticket/message APIs, inbound web/Facebook/email webhook boundaries, notification/presence handling, safe error handling, CORS, and public endpoint rate-limit safeguards.
- `services/ai`: FastAPI AI microservice with health check, deterministic intent classification fallback, document processing for TXT/PDF/DOCX, ChromaDB-backed RAG, and local fallback behavior when LLM credentials are missing.
- `apps/web-admin`: Next.js App Router dashboard with login/mock auth, role-aware navigation, Unified Inbox, Knowledge Base upload UI, staff management UI, channel settings UI, dashboard metrics, and widget demo.
- `apps/mobile`: Flutter support-agent app with login/mock auth, role-aware navigation, Inbox, Ticket Detail, Notifications, simple admin dashboard, profile/settings, online/offline toggle, heartbeat, and local push-notification mock path.
- `infra/supabase`: SQL migrations for Auth-linked user profiles, tickets, messages, documents, channels, notifications, enums, indexes, and RLS policy notes.
- `docs`: local demo, deployment, security, integration, testing, and demo-script documentation.

The project is designed to run locally without real Supabase, Facebook, Email, FCM, OpenAI, or Gemini credentials. Production integrations are documented as explicit setup boundaries.

## Local Demo Quick Start

Detailed steps are in [`docs/local-demo.md`](docs/local-demo.md). The short version is:

### One-command Windows launcher

From PowerShell at the repository root:

```powershell
.\start.cmd
```

The first run creates the Python virtual environments, installs dependencies, starts the AI service, API, and Web Admin, and loads the sample knowledge base. Open `http://127.0.0.1:3000/login`, or use `.\start.cmd -OpenBrowser` to open it automatically. The `.cmd` wrapper works even when Windows blocks direct PowerShell script execution.

Stop only the processes launched by the script with:

```powershell
.\stop.cmd
```

Use `.\start.cmd -SkipInstall` on later runs when dependencies are already installed. The Flutter mobile app remains optional and is started separately because it requires a selected device or emulator.

### Manual startup

1. Start AI service:

```sh
cd services/ai
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
APP_ENV=development RAG_CONFIDENCE_THRESHOLD=0.0 CHROMA_DB_PATH=./chroma uvicorn app.main:app --reload --host 127.0.0.1 --port 8001
```

2. Load the sample Knowledge Base file:

```sh
curl -X POST http://127.0.0.1:8001/documents/process \
  -H "Content-Type: application/json" \
  -d '{"document_id":"demo-support-policy","file_url":"../../docs/demo-data/sample-support-policy.txt","file_type":"txt","file_name":"sample-support-policy.txt","file_size_bytes":856}'
```

3. Start API service:

```sh
cd services/api
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
APP_ENV=development LOCAL_MOCK_AUTH_ENABLED=true AI_SERVICE_URL=http://127.0.0.1:8001 uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

4. Start Web Admin:

```sh
cd apps/web-admin
./node_modules/.bin/next dev --hostname 127.0.0.1 --port 3000
```

Open `http://127.0.0.1:3000/login` and use:

- `owner@example.com` / `password` for `super_admin`
- `agent@example.com` / `password` for `agent`

5. Run Mobile if available:

```sh
cd apps/mobile
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

## Final Demo Narrative

Use [`docs/demo-script.md`](docs/demo-script.md) for the presentation flow:

1. Business problem.
2. Admin uploads Knowledge Base.
3. Customer asks an FAQ in the widget.
4. AI answers instantly with RAG.
5. Customer sends a complaint.
6. AI escalates to a human ticket.
7. Agent receives ticket/notification.
8. Agent replies and resolves.
9. Dashboard updates.

## Inspiration

The idea started from a real experience of one team member who teaches a sports class outside school hours.

One day, a potential student sent a message asking simple questions about the class: whether new students were still accepted, what the schedule was, and how much the tuition fee cost. These were basic questions that could have been answered quickly.

The message was seen, but the team member was teaching another class at that moment and could not reply immediately. After the class, other tasks came up and the message was forgotten. Nearly four hours later, when the reply was finally sent, the customer answered that they had already registered for another class.

The problem was not that the question was difficult. The problem was response time. A customer only needed a quick answer, but the delay caused a lost opportunity. This inspired the team to build a system that can reply instantly to common questions while still knowing when a real staff member should take over.

## Problem Discovery

From that experience, the team found that the same problem happens often in small online businesses:

- Small shops usually have only one or two people handling both sales and customer service.
- Messages come from multiple channels such as website chat, Facebook Messenger, and email.
- Many customer questions are repetitive, including price, shipping time, return policy, warranty, and product size.
- Staff can easily miss messages when they are busy or outside working hours.
- Complaints and angry customers may not be identified quickly enough.
- Slow replies can lead to lost customers and lower trust.

## Solution Hypothesis

If an AI system can answer frequently asked questions 24/7 and detect when a customer needs human support, then small businesses can reduce customer service workload, lower staffing pressure, and avoid missing important messages.

## Proposed Solution

Smart Helpdesk combines five main components:

- AI Agent with RAG: Reads business documents such as product information, return policy, warranty policy, and pricing documents to answer customer questions accurately.
- Intent Classification: Detects whether a message is an information request, complaint, or spam, then escalates serious complaints to staff.
- Omnichannel Unified Inbox: Brings messages from website chat, Facebook Messenger, and email into one support system.
- Web Admin Dashboard: Allows business owners to upload documents, manage tickets, view reports, and manage support staff.
- Mobile App for Staff: Sends urgent ticket notifications and lets customer service staff handle difficult cases anytime.

## Customer Profile

**Customer Segment:** Small and medium e-commerce businesses and online shop owners.

### Customer Jobs

- Read and reply to buyer messages.
- Look up product information, shipping fees, and warranty policies.
- Manually filter and prioritize incoming messages.

### Pains

- Message overload, especially at night or outside office hours, makes customers wait and may cause canceled orders.
- High cost of hiring staff to monitor customer channels 24/7.
- Missed serious complaint messages can damage business reputation.
- Repetitive questions create fatigue and stress for customer service staff.

### Gains

- Reduce staff workload and save operating costs.
- Respond to customers as quickly as possible.
- Intervene in time when customers are unhappy.
- Use a dashboard to monitor employee performance.

## Value Map

### Products and Services

- Website Admin: Upload store documents, policies, and operational knowledge.
- Mobile App: Let customer service staff receive instant notifications on their phones.
- AI Agent with LLM and RAG: Understand uploaded documents, chat with customers automatically, and classify message sentiment or intent.

### Pain Relievers

- AI Agent works 24/7 and immediately answers frequently asked questions.
- Reduce missed messages and support faster complaint handling.
- Lower dependence on human staff for repetitive tasks.

### Gain Creators

- Faster response time improves customer experience and conversion opportunities.
- Unified Inbox gives teams one place to track conversations across channels.
- Analytics help owners understand support performance and AI automation rate.

## Expected Impact

| Metric | Before Smart Helpdesk | After Smart Helpdesk |
| --- | --- | --- |
| Average response time | 15-30 minutes outside working hours | Less than 5 seconds for AI-handled questions |
| Messages handled by AI | 0% | Around 80% for repetitive questions |
| Missed complaint rate | Around 15% | Near 0% through urgent push notifications |
| Staff needed for page monitoring | 2 people per shift | 1 person focusing only on difficult cases |

## System Architecture

```text
INPUT LAYER
Web Chat Widget / Facebook Messenger / Email Webhook
        |
        | Messages and webhooks
        v
ORCHESTRATOR LAYER
Receive message -> attach source and sender_id -> save message -> queue processing
        |
        v
AI CORE LAYER
Intent Classifier -> RAG Agent with ChromaDB -> LLM answer generation
        |
        v
OUTPUT LAYER
Auto-reply to original channel OR create ticket and notify staff
        |
        +--> Web Admin with RBAC
        +--> Mobile App with FCM push notifications
```

## Current System Specification

The latest specification defines Smart Helpdesk as a four-layer system:

| Layer | Responsibility |
| --- | --- |
| Input Layer | Accept messages from Web Widget, Facebook Messenger webhooks, and Email webhooks. |
| Orchestrator Layer | Attach `source` and `sender_id`, persist the message, and start AI processing. |
| AI Core Layer | Classify intent, run RAG over ChromaDB, generate answers, or trigger ticket escalation. |
| Output Layer | Reply through the customer's original channel, update Web Admin, and notify Mobile App users. |

### Actors

| Actor | Role |
| --- | --- |
| Customer | Sends messages through Web Widget, Facebook Messenger, or Email. |
| Super Admin | Owns the shop account and can access Inbox, Dashboard, Knowledge Base, staff management, and channel settings. |
| Agent | Handles assigned or open tickets and replies to customers. |
| AI Bot | Classifies intent, answers with RAG, creates tickets, and triggers notifications. |
| External Systems | Facebook Messenger API, Mailgun, or SendGrid send webhooks and receive outbound replies. |

### Use Case Map

| ID | Use Case | Primary Actor | Result |
| --- | --- | --- | --- |
| UC01 | Send message | Customer / External System | Message is saved with `source`, `sender_id`, and processing state. |
| UC02 | Receive AI reply | Customer / AI Bot | AI answer is sent back to Web, Facebook, or Email and saved as `sender_type = bot`. |
| UC03 | Handoff to staff | Customer / AI Bot / Agent | Ticket is created and the conversation continues with human support. |
| UC04 | Login | Super Admin / Agent | Supabase Auth validates credentials and role-based UI is shown. |
| UC05 | View Unified Inbox | Super Admin / Agent | User sees realtime tickets according to role permissions. |
| UC06 | Reply to customer | Super Admin / Agent | Human reply is sent through the original channel and saved as `sender_type = human`. |
| UC07 | Resolve ticket | Super Admin / Agent | Ticket is marked `resolved`, `resolved_at` is stored, and a closing message is sent. |
| UC08 | Upload AI documents | Super Admin | PDF, DOCX, or TXT files are uploaded, chunked, embedded, and indexed in ChromaDB. |
| UC09 | View dashboard | Super Admin | Admin sees message count, AI handling rate, average response time, open tickets, trends, and top questions. |
| UC10 | Manage staff accounts | Super Admin | Agent accounts are created, invited, updated, or disabled. |
| UC11 | Configure channels | Super Admin | Facebook and Email integration credentials are saved and tested. |
| UC12 | Receive push notification | Agent / Super Admin | Online staff receive FCM notifications for urgent tickets. |
| UC13 | Toggle Online/Offline | Agent | Availability is updated and affects urgent ticket distribution. |
| UC14 | Classify intent | AI Bot | Message is labeled `question`, `complaint`, or `spam`. |
| UC15 | Answer with RAG | AI Bot | Top-3 relevant chunks are retrieved and used to answer the customer. |
| UC16 | Create urgent ticket | AI Bot | Complaint or unanswered question becomes a ticket and triggers staff notification. |

### Core Flow

1. Customer sends a message through Web, Facebook, or Email.
2. Orchestrator saves the message and tags the source channel.
3. AI classifies the message as `question`, `complaint`, or `spam`.
4. If the intent is `question`, the RAG Agent searches ChromaDB and returns an answer when relevant context is found.
5. If the intent is `complaint` or RAG cannot find enough context, the system sends a calming handoff message, creates a ticket, and notifies online agents.
6. Staff reply from Web Admin or Mobile App, and the reply is routed back to the customer's original channel.

## Role-Based Access Control

The system uses one account system and one JWT token from Supabase Auth. After login, the app reads the `role` field in the `users` table and renders the correct web or mobile experience.

| Feature | super_admin on Web | agent on Web | Mobile App, both roles |
| --- | :---: | :---: | :---: |
| Unified Inbox: view and reply | All tickets | Assigned/open tickets | Yes |
| Push Notification | Browser notification only | Browser notification only | Main feature |
| Customer chat history | Yes | Yes | Yes |
| Analytics dashboard | Full | No | Simple view |
| Knowledge Base upload | Yes | No | No |
| Staff account management | Yes | No | No |
| Channel settings: Facebook webhook and email | Yes | No | No |

Agent visibility rules:

- `super_admin` can view every ticket.
- `agent` can view tickets assigned to them and open tickets available for handling.
- Disabled users cannot log in, but historical chat records remain available.
- Online agents receive urgent push notifications; offline agents keep their active tickets but do not receive new urgent assignments.

## Main Modules

### 1. Chat Widget

The chat widget is used by customers on the business website.

- Embed on any website with one `<script>` tag.
- Display a floating chat box at the bottom-right corner of the website.
- Send and receive text messages in realtime.
- Show a typing indicator while the AI is processing.
- Support seamless handoff from AI to human staff without resetting the chat.
- Display a source-channel badge for Web, Facebook, or Email.
- Receive web replies through Supabase Realtime.

### 2. Web Admin Dashboard: super_admin

The full admin dashboard is used by shop owners and managers.

- Login with email/password through Supabase Auth.
- View and reply to every message from Web, Facebook, and Email in the Unified Inbox.
- Filter Inbox by channel and ticket status: Open, In Progress, Resolved.
- Upload PDF, DOCX, or TXT documents up to 10 MB to build the AI knowledge base.
- View dashboard statistics such as today's message count, AI resolution rate, average response time, open tickets, 7-day message trend, and top questions.
- Manage customer service staff accounts.
- Configure Facebook webhook and inbound email settings.

### 3. Web Admin Dashboard: agent

The limited web dashboard is used by customer service staff working from a computer.

- Login with an account created by a super_admin.
- View and reply to assigned or open tickets.
- View the full customer chat history in a context viewer.
- Update ticket status to In Progress or Resolved.
- Hide Dashboard, Knowledge Base, staff management, and channel settings.

### 4. Mobile App

The mobile app is used by customer service staff.

- Login with the same Supabase Auth account used on Web.
- Switch Online/Offline status.
- Receive push notifications when a new ticket or urgent message is created.
- View and reply to realtime messages with the same permissions as the user's role.
- View the full customer chat history for context.
- Close tickets after they are resolved.
- Let super_admin users view a simplified dashboard.

### 5. AI Core

The AI Core powers the automation layer.

- Classify customer intent as question, complaint, or spam.
- Answer questions using uploaded documents with RAG.
- Create tickets when complaints or urgent messages are detected.
- Create tickets when RAG cannot find relevant context above the configured threshold.
- Send push notifications for urgent tickets.
- Receive webhooks from Facebook Messenger and email.
- Sync realtime updates between Web Admin and Mobile App.

## Data Model

| Table | Purpose | Key fields |
| --- | --- | --- |
| `users` | Internal staff accounts and RBAC. | `id`, `email`, `full_name`, `role`, `status`, `avatar_url`, `last_seen_at` |
| `tickets` | Customer conversation cases. | `id`, `customer_id`, `customer_name`, `source`, `status`, `intent`, `summary`, `assigned_to`, `resolved_at` |
| `messages` | Chat history for every ticket. | `id`, `ticket_id`, `sender_type`, `sender_id`, `content`, `created_at` |
| `documents` | Uploaded knowledge-base files. | `id`, `name`, `file_url`, `file_type`, `embedding_status`, `chunk_count`, `uploaded_by` |
| `channels` | Connected Web, Facebook, and Email settings. | `id`, `type`, `config`, `is_active`, `connected_at` |
| `notifications` | Stored push/browser notifications. | `id`, `ticket_id`, `recipient_id`, `title`, `body`, `is_read`, `sent_at` |

### Enumerations

| Field | Values |
| --- | --- |
| `users.role` | `super_admin`, `agent` |
| `users.status` | `online`, `offline`, `disabled` |
| `tickets.source` / `channels.type` | `web`, `facebook`, `email` |
| `tickets.status` | `open`, `in_progress`, `pending`, `resolved` |
| `tickets.intent` | `question`, `complaint`, `spam` |
| `messages.sender_type` | `customer`, `bot`, `human` |
| `documents.file_type` | `pdf`, `docx`, `txt` |
| `documents.embedding_status` | `processing`, `ready`, `error` |

## Tech Stack

| Layer | Technology |
| --- | --- |
| AI Agent | LangChain + Gemini API or OpenAI GPT |
| Vector Database | ChromaDB |
| Backend API | FastAPI |
| Database and Auth | Supabase: PostgreSQL, Realtime, Auth |
| Web Frontend | Next.js + Tailwind CSS |
| Mobile App | Flutter |
| Email Integration | Mailgun or SendGrid Webhook/API |
| Facebook Integration | Meta Messenger Platform API Webhook |
| Push Notification | Firebase Cloud Messaging |
| Hosting | Railway or Render for backend, Vercel for web |

## Project Timeline

| Phase | Duration | Milestones |
| --- | --- | --- |
| Phase 1: Planning & Setup | Day 1-3 | Finalize database schema, API contract, wireframes, and development environment |
| Phase 2: Core Development | Day 4-12 | Build backend API, AI Agent, Web Admin, and Mobile App modules |
| Phase 3: Integration & Testing | Day 13-16 | Connect all modules, run end-to-end testing, and fix bugs |
| Phase 4: Polish & Report | Day 17-18 | Improve UI, complete report, and record demo video |

## Functional Requirements

### Chat Widget

- [ ] Display a floating website chat box at the bottom-right corner.
- [ ] Send and receive realtime text messages.
- [ ] Show typing indicator while AI is processing.
- [ ] Support seamless handoff from AI to human staff without resetting chat history.
- [ ] Display source-channel badge for Web, Facebook, or Email.
- [ ] Show a busy/error fallback when the system cannot save the message.

### Web Admin Dashboard: super_admin

- [ ] Login with email/password through Supabase Auth.
- [ ] View and reply to all messages from Web, Facebook, and Email in the Unified Inbox.
- [ ] Filter Inbox by channel and ticket status: Open, In Progress, Resolved.
- [ ] Show dashboard analytics: total messages today, AI handling rate, average response time, open tickets, 7-day trend, and top 5 questions.
- [ ] Upload PDF, DOCX, or TXT files for the AI knowledge base and view processing status.
- [ ] Create/delete agent accounts and assign roles.
- [ ] Configure Facebook webhook and inbound email address.

### Web Admin Dashboard: agent

- [ ] Login with an account created by a super_admin.
- [ ] View and reply to assigned or open tickets.
- [ ] View full customer chat history.
- [ ] Update ticket status to In Progress or Resolved.
- [ ] Hide Dashboard, Knowledge Base, staff management, and channel settings.

### Mobile App

- [ ] Login with the same account as Web through Supabase Auth.
- [ ] Let users switch Online/Offline status.
- [ ] Receive push notifications for new tickets or urgent messages.
- [ ] View and reply to realtime messages with role-based permissions.
- [ ] Show full customer chat context.
- [ ] Close tickets after resolution.
- [ ] Show simple dashboard statistics for super_admin users.
- [ ] Open the relevant ticket directly when the user taps a push notification.

### AI Core

- [ ] Classify message intent: question, complaint, or spam.
- [ ] Answer common questions using RAG with top-3 ChromaDB chunks.
- [ ] Create tickets and send push notifications for complaints or RAG failures.
- [ ] Receive Facebook Messenger and email webhooks.
- [ ] Sync realtime data across the system with Supabase Realtime.
- [ ] Ignore spam after classification.
- [ ] Default to `question` and continue to RAG when the LLM classifier times out.

## Non-Functional Requirements

- Performance: AI should respond to common questions in less than 5 seconds.
- Availability: The system should support 24/7 customer support automation.
- Scalability: The architecture should allow future channels such as Zalo or WhatsApp.
- Security: Authentication tokens and channel API keys must be protected, and role permissions must be enforced server-side.
- Reliability: Realtime clients should show a warning and retry after connection loss.
- Agent presence: Agents should be marked offline after 30 seconds without heartbeat.

## Expected Final Demo

The final project should demonstrate this complete flow:

1. Admin uploads business documents.
2. Customer sends a message through the chat widget or simulated channel.
3. AI classifies the customer's intent.
4. AI answers normal questions using uploaded documents.
5. AI creates an urgent ticket for complaints or difficult cases.
6. Staff receives a mobile notification.
7. Staff reviews the chat context and resolves the ticket.

## Honest Limitations

- Local demo mode uses mocked auth/session data and local in-memory or browser data where real Supabase is not configured.
- The web widget demo can run with reliable mocked browser responses; API curl commands in `docs/local-demo.md` exercise the real local API and AI services.
- Facebook, Email, FCM, Supabase Auth, and hosted ChromaDB require provider setup before production use.
- Channel settings and staff invites are UI/API boundaries that avoid exposing secrets, but real credential storage and invite delivery still need production provider wiring.
- Multi-instance production rate limiting should move from in-memory safeguards to Redis, an API gateway, or an edge provider.
- Screenshots are not committed because they should only be generated from a running app immediately before presentation or submission.

## Verification Commands

Run the final verification suite:

```sh
cd services/api && .venv/bin/python -m pytest
cd services/ai && .venv/bin/python -m pytest
cd apps/web-admin && ./node_modules/.bin/next lint
cd apps/web-admin && ./node_modules/.bin/vitest run
cd apps/web-admin && ./node_modules/.bin/next build
cd apps/mobile && flutter analyze
cd apps/mobile && flutter test
```

## Repository Information

| Item | Detail |
| --- | --- |
| Last updated | 2026-08-08 |
| Repository | `[GitHub repository link]` |
