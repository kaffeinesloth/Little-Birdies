# AI Microservice

FastAPI AI service for Smart Helpdesk automation.

## Responsibilities

- Health endpoint and AI configuration.
- Intent classification: `question`, `complaint`, or `spam`.
- RAG answer generation using top-3 ChromaDB chunks.
- Full message processing decision endpoint.
- Document processing for PDF, DOCX, and TXT knowledge-base files.
- Deterministic local fallback behavior when API keys are not configured.

## Local Setup

From `backend/ai`:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

## Run The Service

```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8001
```

Health check:

```bash
curl http://localhost:8001/health
```

## Tests

```bash
pytest
```

When `OPENAI_API_KEY` and `GEMINI_API_KEY` are missing, the service uses deterministic fallback behavior so local tests can run without external AI services.
