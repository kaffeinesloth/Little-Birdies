"""
<<<<<<< HEAD
AI Service — Smart Helpdesk
============================
Microservice này do team AI đảm nhận implement.
Backend gọi 2 endpoint sau qua HTTP (fire-and-forget):

POST /process
    Input:  { ticket_id, customer_id, source, content }
    Output: { status: "auto_replied" | "escalated" | "ignored" }
    Hành vi:
    - Classify intent: question | complaint | spam
    - Nếu question → RAG query → INSERT bot message → resolve ticket
    - Nếu complaint hoặc RAG fail → INSERT handoff message → push notification

POST /embed
    Input:  { document_id, file_url, file_type }
    Output: { status: "ready" | "error", chunk_count: int }
    Hành vi:
    - Download file từ Supabase Storage
    - Parse PDF/DOCX/TXT → chunk → embed → lưu vào vector DB
    - UPDATE documents SET embedding_status=ready/error

GET /
    Health check → { status: "ok" }

Xem chi tiết: AI Helpdesk Agent/api_design_specification.md
Mục "2. AI Processing Background"
"""
=======
main.py — FastAPI entry point (updated với tất cả routers).

Chạy: uvicorn main:app --reload --port 8000
Docs: http://localhost:8000/docs
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
from routers import chat, knowledge, webhooks

app.include_router(chat.router,      prefix="/chat",      tags=["Chat"])
app.include_router(knowledge.router, prefix="/knowledge", tags=["Knowledge Base"])
app.include_router(webhooks.router,  prefix="/webhook",   tags=["Webhooks"])


@app.get("/health", response_model=HealthResponse, tags=["System"])
async def health():
    return HealthResponse(status="ok", version="0.1.0")


@app.get("/", include_in_schema=False)
async def root():
    return {"message": f"{settings.app_name} is running. Visit /docs"}
>>>>>>> 3aa584e (Update AI service)
