"""
db/queries.py — Tất cả DB operations với Supabase.

Mỗi function nhận supabase client làm tham số để dễ test (inject mock).
"""
from __future__ import annotations

import logging
from datetime import datetime
from uuid import uuid4

logger = logging.getLogger(__name__)


# ─────────────────────────────────────────────────────────────────────────────
# Conversations
# ─────────────────────────────────────────────────────────────────────────────

async def get_conversation(db, conversation_id: str) -> dict | None:
    res = (
        await db.table("conversations")
        .select("*, messages(*)")
        .eq("id", conversation_id)
        .maybe_single()
        .execute()
    )
    return res.data


async def create_conversation(
    db,
    tenant_id:   str,
    channel:     str,
    external_id: str | None = None,
) -> dict:
    data = {
        "id":          str(uuid4()),
        "tenant_id":   tenant_id,
        "channel":     channel,
        "external_id": external_id,
        "state":       "AI_HANDLING",
    }
    res = await db.table("conversations").insert(data).execute()
    return res.data[0]


async def update_conversation_state(
    db,
    conversation_id: str,
    state:           str,
    agent_id:        str | None = None,
) -> None:
    payload: dict = {"state": state, "updated_at": datetime.utcnow().isoformat()}
    if agent_id:
        payload["assigned_agent_id"] = agent_id
    await db.table("conversations").update(payload).eq("id", conversation_id).execute()


# ─────────────────────────────────────────────────────────────────────────────
# Messages
# ─────────────────────────────────────────────────────────────────────────────

async def add_message(
    db,
    conversation_id: str,
    role:            str,
    content:         str,
    intent:          str | None = None,
    confidence:      float | None = None,
) -> dict:
    data = {
        "id":              str(uuid4()),
        "conversation_id": conversation_id,
        "role":            role,
        "content":         content,
        "intent":          intent,
        "confidence":      confidence,
    }
    res = await db.table("messages").insert(data).execute()
    return res.data[0]


async def get_recent_messages(
    db,
    conversation_id: str,
    limit: int = 10,
) -> list[dict]:
    res = (
        await db.table("messages")
        .select("role, content")
        .eq("conversation_id", conversation_id)
        .order("created_at", desc=False)
        .limit(limit)
        .execute()
    )
    return res.data or []


# ─────────────────────────────────────────────────────────────────────────────
# Tickets
# ─────────────────────────────────────────────────────────────────────────────

async def create_ticket(db, payload: dict) -> dict:
    data = {**payload, "id": str(uuid4()), "status": "OPEN"}
    res  = await db.table("tickets").insert(data).execute()
    return res.data[0]


async def update_ticket_status(
    db,
    ticket_id: str,
    status:    str,
    agent_id:  str | None = None,
) -> None:
    payload: dict = {"status": status}
    if agent_id:
        payload["assigned_agent_id"] = agent_id
    if status == "RESOLVED":
        payload["resolved_at"] = datetime.utcnow().isoformat()
    await db.table("tickets").update(payload).eq("id", ticket_id).execute()


async def get_open_tickets(db, tenant_id: str) -> list[dict]:
    res = (
        await db.table("tickets")
        .select("*")
        .eq("tenant_id", tenant_id)
        .neq("status", "RESOLVED")
        .order("urgency", desc=True)
        .order("created_at", desc=False)
        .execute()
    )
    return res.data or []


# ─────────────────────────────────────────────────────────────────────────────
# Knowledge documents
# ─────────────────────────────────────────────────────────────────────────────

async def create_document(
    db,
    doc_id:      str,
    tenant_id:   str,
    file_name:   str,
    storage_path: str,
    mime_type:   str,
    file_size:   int,
    uploaded_by: str,
) -> dict:
    data = {
        "id":           doc_id,
        "tenant_id":    tenant_id,
        "file_name":    file_name,
        "storage_path": storage_path,
        "mime_type":    mime_type,
        "file_size":    file_size,
        "status":       "INDEXING",
        "uploaded_by":  uploaded_by,
    }
    res = await db.table("knowledge_documents").insert(data).execute()
    return res.data[0]


async def update_document_status(
    db,
    doc_id:        str,
    status:        str,
    chunks_count:  int = 0,
    error_message: str | None = None,
) -> None:
    payload: dict = {"status": status}
    if status == "DONE":
        payload["chunks_count"] = chunks_count
        payload["indexed_at"]   = datetime.utcnow().isoformat()
    if error_message:
        payload["error_message"] = error_message
    await db.table("knowledge_documents").update(payload).eq("id", doc_id).execute()


async def get_documents(db, tenant_id: str) -> list[dict]:
    res = (
        await db.table("knowledge_documents")
        .select("id, file_name, status, chunks_count, file_size, created_at, indexed_at, error_message")
        .eq("tenant_id", tenant_id)
        .order("created_at", desc=True)
        .execute()
    )
    return res.data or []


async def delete_document(db, doc_id: str) -> None:
    await db.table("knowledge_documents").delete().eq("id", doc_id).execute()


# ─────────────────────────────────────────────────────────────────────────────
# Tenant config
# ─────────────────────────────────────────────────────────────────────────────

async def get_tenant_config(db, tenant_id: str) -> dict:
    res = (
        await db.table("tenant_ai_configs")
        .select("*")
        .eq("tenant_id", tenant_id)
        .maybe_single()
        .execute()
    )
    # Trả về config mặc định nếu chưa setup
    return res.data or {
        "tenant_id":        tenant_id,
        "shop_name":        "Shop",
        "bot_persona":      "thân thiện, chuyên nghiệp",
        "greeting_message": "Xin chào! Mình có thể giúp gì cho bạn? 😊",
        "auto_reply_enabled": True,
    }


# ─────────────────────────────────────────────────────────────────────────────
# Staff FCM tokens (cho push notification)
# ─────────────────────────────────────────────────────────────────────────────

async def get_staff_fcm_tokens(db, tenant_id: str) -> list[str]:
    """Lấy FCM tokens của tất cả nhân viên online của tenant."""
    res = (
        await db.table("users")
        .select("fcm_token")
        .eq("tenant_id", tenant_id)
        .eq("is_online", True)
        .not_.is_("fcm_token", "null")
        .execute()
    )
    return [row["fcm_token"] for row in (res.data or []) if row.get("fcm_token")]
