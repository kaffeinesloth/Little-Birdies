"""
main.py — FastAPI entry point cho AI Service microservice.

Chạy: uvicorn main:app --reload --port 8001
Docs: http://localhost:8001/docs
"""
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from agent.schemas import HealthResponse
from config import settings


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: init Supabase client
    from db.client import get_supabase
    await get_supabase()
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
    allow_credentials=True,
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
    return HealthResponse(status="ok", version="0.1.0")


@app.get("/", include_in_schema=False)
async def root():
    return {"message": f"{settings.app_name} is running. Visit /docs"}
