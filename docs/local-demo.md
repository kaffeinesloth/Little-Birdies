# Local End-to-End Demo

This demo runs without real Supabase, Facebook, Email, FCM, or LLM credentials. The AI service uses deterministic local fallback behavior, the API can use an in-memory mock Supabase-compatible store, and the web/mobile apps have local mock auth.

## 1. Start The AI Service

Terminal 1:

```sh
cd "/Users/kafe/Desktop/AI Integrated Stack/Little-Birdies/services/ai"
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
APP_ENV=development RAG_CONFIDENCE_THRESHOLD=0.0 CHROMA_DB_PATH=./chroma uvicorn app.main:app --reload --host 127.0.0.1 --port 8001
```

Health check:

```sh
curl http://127.0.0.1:8001/health
```

Load the sample Knowledge Base TXT into ChromaDB:

```sh
curl -X POST http://127.0.0.1:8001/documents/process \
  -H "Content-Type: application/json" \
  -d '{
    "document_id": "demo-support-policy",
    "file_url": "/Users/kafe/Desktop/AI Integrated Stack/Little-Birdies/docs/demo-data/sample-support-policy.txt",
    "file_type": "txt",
    "file_name": "sample-support-policy.txt",
    "file_size_bytes": 856
  }'
```

Try a RAG answer:

```sh
curl -X POST http://127.0.0.1:8001/rag/answer \
  -H "Content-Type: application/json" \
  -d '{"question":"How long does standard shipping take?","top_k":3}'
```

## 2. Start The API

Terminal 2:

```sh
cd "/Users/kafe/Desktop/AI Integrated Stack/Little-Birdies/services/api"
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
APP_ENV=development \
LOCAL_MOCK_AUTH_ENABLED=true \
AI_SERVICE_URL=http://127.0.0.1:8001 \
uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

Health check:

```sh
curl http://127.0.0.1:8000/health
```

Useful local mock bearer tokens:

```text
super_admin: mock:00000000-0000-4000-8000-000000000001:owner@example.com:super_admin:online
agent:       mock:00000000-0000-4000-8000-000000000002:agent@example.com:agent:online
```

Create a normal web question through the API:

```sh
curl -X POST http://127.0.0.1:8000/webhooks/web-message \
  -H "Content-Type: application/json" \
  -d '{"sender_id":"demo-customer","customer_name":"Demo Customer","content":"How long does standard shipping take?"}'
```

Create an urgent complaint:

```sh
curl -X POST http://127.0.0.1:8000/webhooks/web-message \
  -H "Content-Type: application/json" \
  -d '{"sender_id":"demo-customer","customer_name":"Demo Customer","content":"My delivery is late and I want a refund."}'
```

List visible tickets as an agent:

```sh
curl "http://127.0.0.1:8000/tickets?limit=50&offset=0" \
  -H "Authorization: Bearer mock:00000000-0000-4000-8000-000000000002:agent@example.com:agent:online"
```

## 3. Start Web Admin

Terminal 3:

```sh
cd "/Users/kafe/Desktop/AI Integrated Stack/Little-Birdies/apps/web-admin"
PATH=/Users/kafe/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin:$PATH ./node_modules/.bin/next dev --hostname 127.0.0.1 --port 3000
```

Open:

- Web Admin: `http://127.0.0.1:3000/login`
- Widget demo: `http://127.0.0.1:3000/widget-demo`
- Unified Inbox: `http://127.0.0.1:3000/inbox`

Mock login:

- `owner@example.com` / `password` as `super_admin`
- `agent@example.com` / `password` as `agent`

Web demo flow:

1. Log in as `super_admin`.
2. Open Knowledge Base and upload `docs/demo-data/sample-support-policy.txt`. In web mock mode this previews processing locally; use the AI curl above for real local ChromaDB ingestion.
3. Open Widget Demo.
4. Ask: `How long does standard shipping take?`
5. Ask: `My delivery is late and I want a refund.`
6. Open Inbox as an agent to view the preloaded urgent ticket preview.
7. Reply in the conversation panel and resolve the ticket.

## 4. Start Mobile If Practical

Terminal 4:

```sh
cd "/Users/kafe/Desktop/AI Integrated Stack/Little-Birdies/apps/mobile"
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

Mobile mock login:

- `owner@example.com` / `password` as `super_admin`
- `agent@example.com` / `password` as `agent`

Mobile limitations:

- Supabase Auth and FCM are placeholder boundaries until `supabase_flutter` and `firebase_messaging` are configured.
- If the API is not reachable, the mobile app falls back to local mock ticket and notification data.

## Demo Limitations

- The web widget demo intentionally uses mocked backend responses for a reliable browser-only demo. Use the API curl commands above to exercise the real local API and AI services.
- Web Admin mock mode stores session and inbox state in the browser only; it does not share state with the API in-memory store.
- No real Facebook, Email, FCM, Supabase, OpenAI, or Gemini credentials are required.
