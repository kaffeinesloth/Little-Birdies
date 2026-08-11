# Backend API

FastAPI backend for Smart Helpdesk AI.

## Responsibilities

- Health endpoint and service configuration.
- Supabase Auth JWT validation and RBAC.
- Role-aware ticket and message APIs.
- Message intake orchestration for Web, Facebook, and Email.
- Document metadata and channel settings APIs.
- Notification records and urgent ticket delivery hooks.
- Outbound channel routing abstractions.

## Local Setup

From `backend/api`:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

Copy the root `.env.example` to a local `.env` file and fill in values as integrations become available.

## Run The API

Start the AI microservice first in a separate terminal:

```bash
cd ../ai
source .venv/bin/activate
uvicorn app.main:app --reload --host 0.0.0.0 --port 8001
```

Then start the backend API from `backend/api`:

```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

The backend reads `AI_SERVICE_URL`, defaulting to `http://localhost:8001`.

Health check:

```bash
curl http://localhost:8000/health
```

Expected response:

```json
{
  "status": "ok",
  "service": "api",
  "version": "0.1.0",
  "environment": "development"
}
```

## Tests

```bash
pytest
```
