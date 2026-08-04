# Smart Helpdesk - AI-Powered Customer Support System

Smart Helpdesk is a SaaS platform that helps small and medium online businesses automate customer support with an AI Agent, Retrieval-Augmented Generation (RAG), and a simple ticketing workflow. The system can answer common customer questions automatically, classify message intent, and escalate urgent complaints to human staff through a mobile app.

> Tagline: "Tu dong hoa CSKH. Xu ly khieu nai tuc thi."

## Team Information

| # | Full Name | Student ID | Role | Responsibilities |
| --- | --- | --- | --- | --- |
| 1 | Huỳnh Bá Anh Khoa | N22DCCN141 | Frontend Developer | Build the Web Admin Dashboard, chat widget UI, demo chat page, and responsive user interface |
| 2 | Vũ Kim Long | N22DCCN050 | Backend Developer | Develop REST APIs, database models, ticket workflow, authentication, and service integrations |
| 3 | Trần Tuấn Hải | N22DCCN026 | AI Engineer | Build the RAG pipeline, intent classification, AI answer generation, and LLM integration |
| 4 | Đặng Nhật Nam | N22DCDT038 | Documentation & QA | Prepare project documentation, test user flows, support report writing, and validate feature requirements |
| 5 | Tạ Quang An | N22DCAT003 | Mobile App & QA | Build/support the mobile ticket workflow, push notification flow, and end-to-end testing |

| Item | Detail |
| --- | --- |
| Course | Do an AI Helpdesk Agent / AI Development / Product Development Track |
| Instructor | `[Ten giang vien huong dan]` |
| Academic year | 2025 - 2026 |
| Submission deadline | `[Ngay nop]` |

## Project Overview

| Field | Detail |
| --- | --- |
| Project name | Smart Helpdesk - AI-Powered Customer Support System |
| Type | SaaS Platform: Web Admin + Mobile App + AI Agent |
| Domain | Customer Service / SaaS |
| Target users | Small and medium online shop owners, e-commerce sellers, and customer service staff |
| Core technology | LLM, RAG, LangChain, FastAPI, Supabase, Flutter |
| Main goal | Reduce repetitive customer service work and prevent urgent customer messages from being missed |
| Development timeline | 3 weeks |

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
- Intent Classification: Detects whether a message is a normal question, buying intent, complaint, or urgent issue.
- Omnichannel Unified Inbox: Brings messages from website chat, Facebook Messenger, and email into one support system.
- Web Admin Dashboard: Allows business owners to upload documents, manage tickets, view reports, and manage support staff.
- Mobile App for Staff: Sends urgent ticket notifications and lets customer service staff handle difficult cases anytime.

## Expected Impact

| Metric | Before Smart Helpdesk | After Smart Helpdesk |
| --- | --- | --- |
| Average response time | 15-30 minutes outside working hours | Less than 5 seconds for AI-handled questions |
| Messages handled by AI | 0% | Around 80% for repetitive questions |
| Missed complaint rate | Around 15% | Near 0% through urgent push notifications |
| Staff needed for page monitoring | 2 people per shift | 1 person focusing only on difficult cases |

## System Architecture

```text
CUSTOMER SIDE
Web Chat Widget / Facebook Messenger / Email Inbox
        |
        | Messages and webhooks
        v
BACKEND & AI CORE
        |
        +--> Intent Classifier
        |       |
        |       +--> Complaint or urgent issue
        |       |       +--> Create Ticket
        |       |       +--> Send Push Notification
        |       |
        |       +--> Normal question
        |               +--> RAG Agent
        |               +--> Search uploaded documents
        |               +--> Auto-reply to customer
        |
        +--> Realtime Ticket Sync
                |
                +--> Mobile App for staff
                +--> Web Admin Dashboard for owner/manager
```

## Main Modules

### 1. Chat Widget

The chat widget is used by customers on the business website.

- Display a chat box at the bottom-right corner of the website.
- Send and receive text messages in realtime.
- Show a typing indicator while the AI is processing.
- Support seamless handoff from AI to human staff without resetting the chat.

### 2. Web Admin Dashboard

The admin dashboard is used by shop owners and managers.

- Login and role-based access for managers and staff.
- Upload PDF or Word documents to build the AI knowledge base.
- View all tickets and their status: Open, Pending, Resolved.
- View dashboard statistics such as message count, AI resolution rate, and average response time.
- Manage customer service staff accounts.

### 3. Mobile App

The mobile app is used by customer service staff.

- Login and switch Online/Offline status.
- Receive push notifications when urgent tickets are created.
- View the full customer chat history for context.
- Chat directly with customers in realtime.
- Close tickets after they are resolved.

### 4. AI Core

The AI Core powers the automation layer.

- Classify customer intent.
- Answer questions using uploaded documents with RAG.
- Create tickets when complaints or urgent messages are detected.
- Send push notifications for urgent tickets.
- Receive webhooks from Facebook Messenger and email.
- Sync realtime updates between Web Admin and Mobile App.

## Tech Stack

| Layer | Technology |
| --- | --- |
| AI Agent | LangChain + Gemini API or OpenAI GPT |
| Vector Database | ChromaDB or Pinecone |
| Backend API | FastAPI |
| Database and Auth | Supabase: PostgreSQL, Realtime, Auth |
| Web Frontend | Next.js + Tailwind CSS |
| Mobile App | Flutter |
| Email Integration | Mailgun or SendGrid Webhook |
| Facebook Integration | Meta Messenger Platform API Webhook |
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

- [ ] Display a website chat box.
- [ ] Send and receive realtime text messages.
- [ ] Show typing indicator while AI is processing.
- [ ] Support handoff from AI to human staff.

### Web Admin Dashboard

- [ ] Support login and role-based access.
- [ ] Upload PDF/Word files for the knowledge base.
- [ ] Show ticket list and ticket status.
- [ ] Show dashboard analytics.
- [ ] Manage staff accounts.

### Mobile App

- [ ] Support staff login.
- [ ] Let staff switch Online/Offline status.
- [ ] Receive push notifications for urgent tickets.
- [ ] Show full customer chat context.
- [ ] Support realtime chat with customers.
- [ ] Close tickets after resolution.

### AI Core

- [ ] Classify message intent.
- [ ] Answer common questions using RAG.
- [ ] Create urgent tickets for complaints.
- [ ] Receive Facebook Messenger and email webhooks.
- [ ] Sync realtime data between web and mobile.

## Non-Functional Requirements

- Performance: AI should respond to common questions in less than 5 seconds.
- Availability: The system should support 24/7 customer support automation.
- Scalability: The architecture should allow future channels such as Zalo or WhatsApp.
- Security: Authentication tokens must be protected, and chat data should not be stored in plain text.

## Expected Final Demo

The final project should demonstrate this complete flow:

1. Admin uploads business documents.
2. Customer sends a message through the chat widget or simulated channel.
3. AI classifies the customer's intent.
4. AI answers normal questions using uploaded documents.
5. AI creates an urgent ticket for complaints or difficult cases.
6. Staff receives a mobile notification.
7. Staff reviews the chat context and resolves the ticket.

## Repository Information

| Item | Detail |
| --- | --- |
| Last updated | 2026-08-04 |
| Repository | `[GitHub repository link]` |
