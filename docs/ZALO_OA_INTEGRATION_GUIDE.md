# Zalo OA Integration Guide

Owner: teammate handling real Zalo Official Account integration.

This file is intentionally scoped to Zalo only. The rest of the demo can be completed without real Zalo by using the existing web chat/customer simulation flow.

## Current State In This Repo

The project currently supports these channel sources in backend models and database schema:

- `web`
- `facebook`
- `email`

Relevant files:

- `backend/main.py`
  - Mounts `backend/api/routers/webhooks.py` at `/api/v1/webhooks`.
- `backend/api/routers/webhooks.py`
  - Has Facebook webhook receive path.
  - Has email webhook receive path.
  - Has shared `_process_incoming(...)` helper for creating tickets, storing messages, and calling AI service.
- `backend/api/routers/messages.py`
  - `POST /api/v1/messages/incoming` is the generic web/customer incoming message path.
  - `POST /api/v1/messages` and `POST /api/v1/messages/agent-reply-demo` call `dispatch_channel_reply(...)`.
- `backend/core/services.py`
  - Sends outbound Facebook/email replies.
  - `web` replies rely on Supabase Realtime message inserts.
- `backend/models/domain.py`
  - `TicketSource` and `ChannelType` do not include `zalo` yet.
- `backend/supabase_schema.sql`
  - `channels.type` CHECK constraint only allows `web`, `facebook`, `email`.
  - `tickets.source` CHECK constraint only allows `web`, `facebook`, `email`.
- `mobile/lib/main.dart`
  - Flutter inbox maps unknown sources to `web`.

## Goal

Add a real Zalo OA channel:

1. Customer sends a text message to Zalo OA.
2. Zalo sends webhook event to backend.
3. Backend verifies Zalo signature.
4. Backend creates/reuses a ticket with `source = "zalo"`.
5. Backend stores customer message.
6. Backend calls `ai_service` `/process`.
7. Staff sees ticket in Flutter inbox.
8. Staff replies.
9. Backend sends reply back to Zalo OA.

## Required Platform Setup

Outside the codebase:

1. Create/open Zalo Developer App.
2. Link app to Zalo Official Account.
3. Authorize OA permissions for message receive/send.
4. Get these values:
   - `ZALO_APP_ID`
   - `ZALO_OA_ID`
   - `ZALO_OA_SECRET_KEY`
   - `ZALO_ACCESS_TOKEN`
   - `ZALO_REFRESH_TOKEN`
5. Expose backend through HTTPS:

```bash
ngrok http 8000
```

6. Register webhook:

```text
https://YOUR-NGROK-DOMAIN/api/v1/webhooks/zalo
```

## Implementation Plan

### Step 1: Add Zalo Source Support

Update:

- `backend/models/domain.py`
  - Add `zalo = "zalo"` to `TicketSource`.
  - Add `zalo = "zalo"` to `ChannelType`.
- `backend/supabase_schema.sql`
  - Add `zalo` to `channels.type` CHECK constraint.
  - Add `zalo` to `tickets.source` CHECK constraint.
  - Add seed row for `channels(type='zalo')`.
- Create a manual migration note for existing Supabase projects because editing the schema file alone does not update a live database.
- `mobile/lib/main.dart`
  - Add source parsing and badge display for Zalo if UI should show real channel badge.

### Step 2: Add Zalo Webhook Receive

Update `backend/api/routers/webhooks.py`:

- Add `POST /zalo`.
- Read raw body.
- Parse JSON defensively.
- Ignore unsupported Zalo events safely.
- Extract:
  - Zalo user id -> `customer_id`
  - message text -> `content`
  - display name if available -> `customer_name`
- Reuse `_process_incoming(customer_id=..., source="zalo", content=..., customer_name=...)`.

Do not invent a separate ticket flow.

### Step 3: Verify Signature

Before coding, check current official Zalo docs for:

- Header name.
- Exact HMAC/hash input.
- Secret/token used.

Implement:

- `hmac.compare_digest`.
- Allow local demo only when `ZALO_OA_SECRET_KEY` is empty.
- Return `403` when secret exists and signature fails.

### Step 4: Add Outbound Zalo Reply

Update `backend/core/services.py`:

- Add `send_zalo_message(recipient_user_id, text_content, token_override=None)`.
- Use env token `ZALO_ACCESS_TOKEN`.
- Call the current Zalo OA send text message API.
- Log errors and return `False`; do not crash the ticket flow.
- Add branch:

```python
elif source == "zalo":
    await send_zalo_message(recipient_user_id=customer_id, text_content=content)
```

### Step 5: Token Refresh

Only after receive/send works:

- Use `ZALO_REFRESH_TOKEN` to refresh expired access tokens.
- Retry outbound send once after refresh.
- If persistent secret storage is not implemented, log the new token values and document manual `.env` update.

## Validation Checklist

- `POST /api/v1/webhooks/zalo` receives real OA text message.
- Ticket appears with `source = "zalo"`.
- Message appears in ticket detail.
- AI reply or handoff happens.
- Staff reply from Flutter calls backend.
- Zalo user receives staff reply.
- Unknown Zalo events do not crash backend.
- Invalid signature is rejected when secret is configured.

## Prompt For Zalo Teammate's AI Agent

```text
You are implementing only the real Zalo OA channel for Smart Helpdesk. Read docs/ZALO_OA_INTEGRATION_GUIDE.md first, then inspect backend/main.py, backend/api/routers/webhooks.py, backend/api/routers/messages.py, backend/core/services.py, backend/models/domain.py, backend/supabase_schema.sql, and mobile/lib/main.dart.

Do not work on the non-Zalo demo flow. Start with Step 1 only: add Zalo as a supported source/channel in backend models, schema SQL, seed notes, and UI source parsing if needed. Preserve existing web/facebook/email behavior. Run the smallest relevant validation and report exactly what changed.
```
