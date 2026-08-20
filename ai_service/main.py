"""
main.py — FastAPI entry point cho AI Service microservice.

Chạy: uvicorn main:app --reload --port 8001
Docs: http://localhost:8001/docs
"""
from contextlib import asynccontextmanager

import httpx

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from agent.schemas import HealthResponse
from config import settings


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: init Supabase client when configured. The class demo fallback
    # must still boot so /health and /process work without service credentials.
    if settings.supabase_url and settings.supabase_service_key:
        try:
            from db.client import get_supabase
            await get_supabase()
        except Exception as exc:
            print(f"Supabase init skipped; demo fallback is available: {exc}")
    else:
        print("Supabase env missing; demo fallback is available")

    print(f"🚀 {settings.app_name} ready")
    print(f"   Models : intent={settings.intent_model} | rag={settings.rag_model}")
    print(f"   ChromaDB: {settings.chroma_persist_dir}")
    yield
    print("👋 Shutdown")


app = FastAPI(
    title=settings.app_name,
    description="AI-powered customer support — Intent Classification + RAG",
    version="0.1.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Routers ───────────────────────────────────────────────────────────────────
from routers import chat, knowledge, process, webhooks

app.include_router(process.router,   prefix="",           tags=["AI Process"])
app.include_router(chat.router,      prefix="/chat",      tags=["Chat"])
app.include_router(knowledge.router, prefix="/knowledge", tags=["Knowledge Base"])
app.include_router(webhooks.router,  prefix="/webhook",   tags=["Webhooks"])


@app.get("/health", response_model=HealthResponse, tags=["System"])
async def health():
    provider = settings.ai_provider.lower()
    if provider not in {"auto", "ollama"}:
        return HealthResponse(
            status="ok",
            version="0.1.0",
            provider="fallback",
            model=None,
            runtime_ready=True,
        )

    ready = False
    try:
        async with httpx.AsyncClient(timeout=2.0) as client:
            response = await client.get(f"{settings.ollama_url.rstrip('/')}/api/tags")
            if response.status_code == 200:
                names = {
                    item.get("name", "")
                    for item in response.json().get("models", [])
                }
                target = settings.ollama_chat_model
                ready = target in names or any(name.startswith(f"{target}:") for name in names)
    except Exception:
        ready = False

    return HealthResponse(
        status="ok" if ready else "degraded",
        version="0.1.0",
        provider="ollama" if ready else "fallback",
        model=settings.ollama_chat_model,
        runtime_ready=ready,
    )


@app.get("/", include_in_schema=False)
async def root():
    return {"message": f"{settings.app_name} is running. Visit /docs"}
