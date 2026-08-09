# Security Review And Production Setup

## Server-Side RBAC

- Protected admin placeholders in `services/api/app/routers/protected.py` use `require_super_admin` for Dashboard, Knowledge Base upload, Staff, and Channel Settings.
- Ticket and message routes in `services/api/app/routers/tickets.py` use `require_agent_or_super_admin` and enforce ticket visibility before reads, updates, replies, resolve, and reopen.
- Presence routes in `services/api/app/routers/presence.py` use `require_agent_or_super_admin`.
- Public routes are intentionally limited to health checks and inbound customer/provider webhooks in `services/api/app/routers/webhooks.py`.

## Secret Handling

- Provider secrets are read from environment variables in `services/api/app/core/config.py`.
- Channel config redaction lives in `services/api/app/services/channels.py`; secret-like keys are replaced with `***` for public channel views.
- Outbound provider implementations in `services/api/app/services/facebook.py` and `services/api/app/services/email.py` do not log tokens or full customer content.
- Frontend clients should only receive channel connection status and non-secret metadata.

## Input And Size Limits

- API message and webhook payloads are limited to 4,000 characters in `services/api/app/schemas/messages.py` and `services/api/app/schemas/webhooks.py`.
- Ticket text fields are length-limited in `services/api/app/schemas/tickets.py`.
- API request body size is limited by `RequestSizeLimitMiddleware` in `services/api/app/core/middleware.py`.
- AI classify, RAG, and process-message inputs are length-limited in `services/ai/app/schemas`.
- AI document processing enforces a 10 MB document boundary in `services/ai/app/schemas/documents.py`.

## CORS, Logging, Errors, And Rate Limits

- API and AI services install CORS middleware for `CORS_ALLOWED_ORIGINS`.
- Safe access logging records method, path, status, and timing only; it excludes tokens, query strings, and message bodies.
- API and AI services return consistent error envelopes via `app/core/errors.py` while preserving `detail` for compatibility.
- Public API webhook endpoints have in-memory rate limiting in `services/api/app/core/middleware.py`.

## Required Production Setup

1. Set `APP_ENV=production` and `DEBUG=false`.
2. Disable local mock mode: `LOCAL_MOCK_AUTH_ENABLED=false`.
3. Configure Supabase JWT validation and service role access.
4. Set `CORS_ALLOWED_ORIGINS` to the exact production admin/widget origins.
5. Put Facebook, Mailgun/SendGrid, FCM, OpenAI/Gemini, and Supabase secrets only in environment variables or a managed secret store.
6. Replace in-memory rate limiting with Redis, API Gateway, Cloudflare, or another distributed limiter before horizontal scaling.
7. Configure provider webhook signature verification for Facebook and Mailgun; add full SendGrid ECDSA verification before enabling signed SendGrid inbound parse in production.
8. Configure structured log redaction at the platform level and avoid request/response body logging.
9. Terminate TLS at the load balancer or platform edge.

## Remaining Risks

- The runtime Supabase adapter is still a placeholder; production needs a real Supabase client and service-role access policy review.
- The API local in-memory mock store is development-only and must not be enabled in production.
- Current webhook rate limiting is process-local and not sufficient for multi-instance production deployments.
- Channel settings admin endpoints are still placeholders; when implemented, they must never return stored secret values.
- SendGrid signature verification is a boundary placeholder pending a maintained crypto dependency.
