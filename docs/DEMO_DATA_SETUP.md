# Demo Data Setup

Use this before the non-Zalo final demo to prepare repeatable SportGear tickets and AI knowledge.

## 1. Start Services

```bash
docker compose up --build
```

Required URLs:

- Backend API: http://localhost:8000
- AI service: http://localhost:8001
- Flutter staff UI: http://localhost:8080
- Store customer chat: http://localhost:3000

## 2. Seed Backend Tickets And Channels

From `backend/`, run:

```bash
python seed.py
```

Default mode is safe: it only refreshes the four known SportGear demo tickets and their messages, then upserts the `web`, `facebook`, and `email` channels.

Do not use this unless you intentionally want to wipe every ticket/message in the connected Supabase project:

```bash
python seed.py --reset-all --yes
```

The script requires `SUPABASE_URL` and `SUPABASE_SERVICE_KEY` in `backend/.env`.

## 3. Seed AI Knowledge

From `ai_service/`, run:

```bash
python seed_knowledge.py --mode auto
```

`auto` first uploads `knowledge_data/sportgear_store.txt` to the running AI service. If that fails, it indexes the file directly into local ChromaDB using `CHROMA_PERSIST_DIR`.

Explicit modes:

```bash
python seed_knowledge.py --mode http
python seed_knowledge.py --mode direct
```

## 4. Verify Demo Knowledge Is Visible

```bash
curl http://localhost:8000/api/v1/documents/demo-list
```

Expected result: a useful SportGear knowledge document appears. If the AI service document table is empty, the backend still returns the fallback `sportgear_store.txt` demo document so the presenter UI remains usable.

## 5. Quick Demo Data Checks

```bash
curl http://localhost:8000/api/v1/tickets/demo-list
curl http://localhost:8000/api/v1/tickets/demo-stats
curl http://localhost:8001/health
```
