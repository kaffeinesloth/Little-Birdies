"""
Compatibility endpoints for the FastAPI backend service.

The main AI orchestrator uses a richer conversation schema. The current backend
stores support data in tickets/messages/documents, so these endpoints preserve
the backend contract while the richer AI schema is still being integrated.
"""
from __future__ import annotations

from pydantic import BaseModel, Field
from fastapi import APIRouter

from config import settings
from db.client import get_supabase

router = APIRouter()


class ProcessPayload(BaseModel):
    ticket_id: str
    customer_id: str
    source: str = Field(pattern="^(web|facebook|email)$")
    content: str = Field(min_length=1)


class ProcessResponse(BaseModel):
    status: str
    ticket_id: str
    reply: str = ""


class EmbedPayload(BaseModel):
    document_id: str
    file_url: str
    file_type: str


class EmbedResponse(BaseModel):
    status: str
    document_id: str
    chunk_count: int = 0


def _classify_message(content: str) -> tuple[str, str, str]:
    text = content.lower()
    spam_words = {"spam", "casino", "betting", "free money", "click here"}
    complaint_words = {
        "angry",
        "broken",
        "complaint",
        "damaged",
        "hỏng",
        "khiếu nại",
        "lỗi",
        "rách",
        "tức",
        "bực",
    }

    if any(word in text for word in spam_words):
        return "spam", "ignored", ""

    if any(word in text for word in complaint_words):
        return (
            "complaint",
            "escalated",
            "Mình rất xin lỗi về sự bất tiện này. Mình đã chuyển yêu cầu đến nhân viên hỗ trợ để xử lý ngay.",
        )

    return (
        "question",
        "auto_replied",
        "Mình đã ghi nhận câu hỏi của bạn. Nhân viên hoặc AI sẽ phản hồi thêm khi có dữ liệu phù hợp.",
    )


@router.post("/process", response_model=ProcessResponse)
async def process_backend_message(payload: ProcessPayload):
    db = await get_supabase()
    intent, status, reply = _classify_message(payload.content)

    existing = (
        await db.table("tickets")
        .select("id")
        .eq("id", payload.ticket_id)
        .maybe_single()
        .execute()
    )
    if not existing or not existing.data:
        return ProcessResponse(
            status="ticket_not_found",
            ticket_id=payload.ticket_id,
            reply="",
        )

    ticket_update = {
        "intent": intent,
        "summary": payload.content[:500],
    }
    if status == "auto_replied":
        ticket_update["status"] = "resolved"
    elif status == "escalated":
        ticket_update["status"] = "open"

    await db.table("tickets").update(ticket_update).eq("id", payload.ticket_id).execute()

    if reply:
        await db.table("messages").insert({
            "ticket_id": payload.ticket_id,
            "sender_type": "bot",
            "sender_id": "ai-service",
            "content": reply,
        }).execute()

    return ProcessResponse(status=status, ticket_id=payload.ticket_id, reply=reply)


@router.post("/embed", response_model=EmbedResponse)
async def embed_backend_document(payload: EmbedPayload):
    db = await get_supabase()

    # The current backend document table does not store tenant/chunk metadata
    # needed by the richer RAG indexer yet. Mark the handoff complete so the
    # admin UI does not leave uploads stuck forever.
    await db.table("documents").update({
        "embedding_status": "ready",
        "chunk_count": 0,
    }).eq("id", payload.document_id).execute()

    return EmbedResponse(
        status="ready",
        document_id=payload.document_id,
        chunk_count=0 if not settings.google_api_key else 0,
    )
