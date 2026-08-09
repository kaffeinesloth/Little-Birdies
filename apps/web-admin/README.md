# Web Admin

Next.js application for the Smart Helpdesk Web Admin Dashboard and chat widget demo.

## Responsibilities

- Supabase Auth login for `super_admin` and `agent`.
- Role-based navigation and route protection.
- Unified Inbox for Web, Facebook, and Email conversations.
- Ticket reply, assignment, status updates, and resolution workflows.
- Super Admin dashboard analytics.
- Knowledge Base document upload and processing status.
- Staff account management.
- Channel configuration for Facebook Messenger and email.
- Embeddable Web Chat Widget demo.

## Local Setup

This app uses Next.js App Router, TypeScript, and Tailwind CSS.

```bash
pnpm install
```

Create `.env.local` when connecting real services:

```bash
NEXT_PUBLIC_API_BASE_URL=http://localhost:8000
NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_ANON_KEY=
NEXT_PUBLIC_MOCK_ROLE=super_admin
```

Set `NEXT_PUBLIC_MOCK_ROLE=agent` to preview the agent navigation, where only Inbox is visible.

## Run

Start the backend API first from `services/api`, then run:

```bash
pnpm dev
```

The app runs at `http://localhost:3000`.

## Routes

- `/login`
- `/inbox`
- `/dashboard`
- `/knowledge-base`
- `/staff`
- `/settings/channels`
- `/widget-demo`

## Verification

```bash
pnpm lint
pnpm build
```
