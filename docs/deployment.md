# Deployment Guide

This guide deploys Smart Helpdesk AI as separate services:

- Supabase for Auth, Postgres, Realtime, and optional file storage
- `services/ai` as a FastAPI AI microservice on Railway or Render
- `services/api` as a FastAPI backend on Railway or Render
- `apps/web-admin` on Vercel
- `apps/mobile` as Flutter builds for Android/iOS

No deploy config files are required for local development. Use provider dashboards or service-specific root directories when creating deployments.

## Supabase

1. Create a Supabase project.
2. Enable Email Auth or the desired login providers.
3. Apply SQL migrations from the repository root:

```sh
supabase link --project-ref <project-ref>
supabase db push
```

If using the dashboard, run files from `infra/supabase/migrations` in filename order.

4. Create staff users through Supabase Auth.
5. Insert matching `public.users` profile rows using each `auth.users.id`.
6. Review Row Level Security policies before production traffic.
7. Enable Realtime for tables used by the web widget/admin UI when needed.

Required Supabase values:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`
- `SUPABASE_JWT_SECRET`
- `SUPABASE_JWT_AUDIENCE`
- `SUPABASE_JWT_ISSUER`

## ChromaDB

For early production, use a persistent disk attached to the AI service:

- Set `CHROMA_DB_PATH=/data/chroma`
- Attach a persistent volume mounted at `/data`
- Back up the volume on a schedule

For a separately hosted ChromaDB:

- Deploy a ChromaDB server in the same region as `services/ai`
- Set `CHROMA_DB_HOST=<internal-host-or-private-url>`
- Restrict network access to the AI service

Do not use ephemeral filesystem storage for production Knowledge Base embeddings.

## AI Service On Railway Or Render

Service root directory:

```text
services/ai
```

Build command:

```sh
pip install -r requirements.txt
```

Start command:

```sh
uvicorn app.main:app --host 0.0.0.0 --port $PORT
```

Health check path:

```text
/health
```

AI environment variables:

- `APP_ENV=production`
- `DEBUG=false`
- `CORS_ALLOWED_ORIGINS=https://<web-admin-domain>`
- `MAX_REQUEST_BODY_BYTES=10485760`
- `MAX_MESSAGE_CONTENT_CHARS=4000`
- `OPENAI_API_KEY` or `GEMINI_API_KEY`
- `EMBEDDING_MODEL=text-embedding-3-small`
- `CHROMA_DB_PATH=/data/chroma` or `CHROMA_DB_HOST=<host>`
- `RAG_CONFIDENCE_THRESHOLD=0.72`
- `LLM_TIMEOUT_SECONDS=5`

## API Service On Railway Or Render

Service root directory:

```text
services/api
```

Build command:

```sh
pip install -r requirements.txt
```

Start command:

```sh
uvicorn app.main:app --host 0.0.0.0 --port $PORT
```

Health check path:

```text
/health
```

API environment variables:

- `APP_ENV=production`
- `DEBUG=false`
- `LOCAL_MOCK_AUTH_ENABLED=false`
- `CORS_ALLOWED_ORIGINS=https://<web-admin-domain>,https://<widget-host-domain>`
- `MAX_REQUEST_BODY_BYTES=1048576`
- `MAX_MESSAGE_CONTENT_CHARS=4000`
- `PUBLIC_ENDPOINT_RATE_LIMIT=60`
- `PUBLIC_ENDPOINT_RATE_WINDOW_SECONDS=60`
- `AI_SERVICE_URL=https://<ai-service-domain>`
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`
- `SUPABASE_JWT_SECRET`
- `SUPABASE_JWT_AUDIENCE=authenticated`
- `SUPABASE_JWT_ISSUER`
- `FACEBOOK_VERIFY_TOKEN`
- `FACEBOOK_APP_SECRET`
- `FACEBOOK_PAGE_ACCESS_TOKEN`
- `MAILGUN_API_KEY`
- `MAILGUN_DOMAIN`
- `MAILGUN_WEBHOOK_SIGNING_KEY`
- `MAILGUN_FROM_EMAIL`
- `SENDGRID_API_KEY`
- `SENDGRID_WEBHOOK_PUBLIC_KEY`
- `SENDGRID_FROM_EMAIL`
- `OUTBOUND_EMAIL_PROVIDER=mailgun` or `sendgrid`
- `FCM_PROJECT_ID`
- `FCM_SERVICE_ACCOUNT_JSON`

Public webhook URLs:

- Web widget: `https://<api-domain>/webhooks/web-message`
- Facebook: `https://<api-domain>/webhooks/facebook`
- Mailgun: `https://<api-domain>/webhooks/email?provider=mailgun`
- SendGrid: `https://<api-domain>/webhooks/email?provider=sendgrid`

## Web Admin On Vercel

Project root directory:

```text
apps/web-admin
```

Install command:

```sh
pnpm install
```

Build command:

```sh
pnpm build
```

Output:

```text
.next
```

Web environment variables:

- `NEXT_PUBLIC_API_BASE_URL=https://<api-domain>`
- `NEXT_PUBLIC_SUPABASE_URL`
- `NEXT_PUBLIC_SUPABASE_ANON_KEY`
- `NEXT_PUBLIC_MOCK_ROLE` should be unset in production

Production notes:

- Disable local mock auth by configuring Supabase env vars.
- Add the Vercel domain to API and AI `CORS_ALLOWED_ORIGINS`.
- Configure custom domain and HTTPS in Vercel.

## Flutter Builds

Android:

```sh
cd apps/mobile
flutter build apk --release --dart-define=API_BASE_URL=https://<api-domain>
```

For Play Store:

```sh
flutter build appbundle --release --dart-define=API_BASE_URL=https://<api-domain>
```

iOS:

```sh
cd apps/mobile
flutter build ios --release --dart-define=API_BASE_URL=https://<api-domain>
```

Mobile environment/build values:

- `API_BASE_URL=https://<api-domain>`
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `FCM_SENDER_ID`
- `FCM_PROJECT_ID`

Production notes:

- Add `supabase_flutter` and `firebase_messaging` production configuration before store release.
- Configure Android signing and iOS signing/provisioning outside the repository.
- Add FCM platform files through the normal Firebase setup flow; do not commit private service account secrets.

## Production Checklist

- [ ] Supabase RLS reviewed for every table.
- [ ] Supabase Auth users created and matching `public.users` profiles inserted.
- [ ] Service secrets configured in Railway/Render/Vercel dashboards or a managed secret store.
- [ ] `LOCAL_MOCK_AUTH_ENABLED=false` in production API.
- [ ] Facebook webhook URL and verify token configured.
- [ ] Mailgun or SendGrid inbound webhook URL configured.
- [ ] FCM project and mobile app credentials configured.
- [ ] Domain names configured for API, AI, Web Admin, and widget host.
- [ ] API and AI `CORS_ALLOWED_ORIGINS` set to exact production origins.
- [ ] ChromaDB persistence or hosted ChromaDB configured.
- [ ] Rate limiting moved to Redis, API gateway, or edge provider for multi-instance production.
- [ ] Demo `super_admin` and `agent` accounts created with non-shared passwords.
- [ ] `/health` checks enabled for API and AI services.

## Deployment Readiness

Ready for staging once external services are configured:

- API and AI expose `/health`.
- Web Admin builds with Next.js.
- Mobile builds can target the API via `--dart-define=API_BASE_URL`.
- Local mock modes are documented and can be disabled for production.

Unresolved external setup:

- Real Supabase runtime adapter and service role review.
- Provider credentials and webhook dashboard setup.
- FCM production app configuration.
- Production ChromaDB persistence.
- Distributed rate limiting for public endpoints.
