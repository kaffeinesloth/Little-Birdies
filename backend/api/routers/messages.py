import httpx
from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks
from uuid import UUID

from core.auth import get_current_user
from core.database import get_supabase_client, get_supabase_admin
from core import demo_store
from core.services import dispatch_channel_reply
from pydantic import BaseModel
from models.domain import (
    APIResponse, MetaResponse,
    MessageCreate, IncomingMessage,
    SenderType,
)

import os

router = APIRouter()

AI_SERVICE_URL = os.getenv("AI_SERVICE_URL", "http://localhost:8001")  # URL của ai_service


def _insert_bot_reply(supabase_admin, ticket_id: str, content: str) -> bool:
    text = content.strip()
    if not text:
        return False

    supabase_admin.table("messages").insert({
        "ticket_id": ticket_id,
        "sender_type": SenderType.bot.value,
        "sender_id": "ai-bot",
        "content": text,
    }).execute()
    return True


def _insert_bot_reply_once(supabase_admin, ticket_id: str, content: str) -> bool:
    """
    Store a bot reply if the same ticket does not already have the exact text.
    This keeps the /process callback and /incoming response path from duplicating
    a visible bot bubble during the demo.
    """
    text = content.strip()
    if not text:
        return False

    existing = (
        supabase_admin.table("messages")
        .select("id")
        .eq("ticket_id", ticket_id)
        .eq("sender_type", SenderType.bot.value)
        .eq("content", text)
        .limit(1)
        .execute()
    )
    if existing.data:
        return False

    return _insert_bot_reply(supabase_admin, ticket_id, text)


async def _incoming_demo_fallback(payload: IncomingMessage) -> APIResponse:
    """Persist an incoming store message without Supabase and still use AI.

    The demo store is the persistence fallback, not an AI replacement. Keeping
    the AI request here makes the shopping widget exercise the same Ollama (or
    deterministic fallback) service as the staff application.
    """
    ticket_id = demo_store.create_or_reuse_ticket(
        customer_id=payload.customer_id,
        customer_name=payload.customer_name,
        source=payload.source.value,
        content=payload.content,
    )
    demo_store.add_message(
        ticket_id,
        SenderType.customer.value,
        payload.customer_id,
        payload.content,
    )

    action, intent, reply = demo_store.fallback_ai_reply(payload.content)
    ai_status = "fallback"

    try:
        async with httpx.AsyncClient(timeout=15.0) as client:
            ai_res = await client.post(
                f"{AI_SERVICE_URL}/process",
                json={
                    "ticket_id": ticket_id,
                    "customer_id": payload.customer_id,
                    "source": payload.source.value,
                    "content": payload.content,
                    "persist_reply": False,
                },
            )
        if ai_res.status_code == 200:
            ai_data = ai_res.json()
            generated_reply = (ai_data.get("reply") or "").strip()
            if generated_reply:
                reply = generated_reply
            action = ai_data.get("action") or action
            ai_status = ai_data.get("provider") or "ok"
            intent = "complaint" if action == "HANDOFF" else "question"
    except Exception:
        # The deterministic reply chosen above keeps the shopping demo usable
        # if the AI container is still starting or is temporarily unavailable.
        pass

    demo_store.add_bot_reply_once(ticket_id, reply)
    updates = {"intent": intent}
    if action == "HANDOFF":
        updates["status"] = "in_progress"
    demo_store.update_ticket(ticket_id, **updates)
    return APIResponse(
        meta=MetaResponse(code=202, message="Message received."),
        data={
            "ticket_id": ticket_id,
            "ai_status": ai_status,
            "ai_action": action,
        },
    )


@router.post("/incoming", response_model=APIResponse, status_code=202)
async def incoming_message(payload: IncomingMessage):
    """
    Endpoint nhận tin nhắn từ khách hàng (chat widget gọi vào).
    Luồng:
    1. Lưu message vào DB với sender_type=customer
    2. Tìm/tạo ticket đang mở cho customer_id + source
    3. Gửi sang AI service để phân loại intent và trả lời
    4. Trả về 202 Accepted (AI xử lý bất đồng bộ)
    """
    try:
        supabase_admin = get_supabase_admin()

        # 1. Tìm ticket đang mở cho khách hàng này (cùng source)
        existing = (
            supabase_admin.table("tickets")
            .select("id, status")
            .eq("customer_id", payload.customer_id)
            .eq("source", payload.source.value)
            .in_("status", ["open", "in_progress"])
            .order("created_at", desc=True)
            .limit(1)
            .execute()
        )

        if existing.data:
            ticket_id = existing.data[0]["id"]
            # Cập nhật summary tin nhắn mới nhất
            try:
                supabase_admin.table("tickets").update({
                    "summary": payload.content[:120],
                    "updated_at": "now()",
                }).eq("id", ticket_id).execute()
            except Exception:
                pass
        else:
            # Tạo ticket mới — intent sẽ được AI cập nhật sau
            new_ticket = (
                supabase_admin.table("tickets")
                .insert({
                    "customer_id": payload.customer_id,
                    "customer_name": payload.customer_name or "SportGear Customer",
                    "source": payload.source.value,
                    "status": "open",
                    "summary": payload.content[:120],
                })
                .execute()
            )
            ticket_id = new_ticket.data[0]["id"]

        # 2. Lưu message của khách vào DB
        supabase_admin.table("messages").insert({
            "ticket_id": ticket_id,
            "sender_type": SenderType.customer.value,
            "sender_id": payload.customer_id,
            "content": payload.content,
        }).execute()
    except Exception:
        return await _incoming_demo_fallback(payload)

    ai_status = "skipped"
    ai_action = "NONE"

    # 3. Gọi AI service
    try:
        async with httpx.AsyncClient(timeout=15.0) as client:
            ai_res = await client.post(
                f"{AI_SERVICE_URL}/process",
                json={
                    "ticket_id": ticket_id,
                    "customer_id": payload.customer_id,
                    "source": payload.source.value,
                    "content": payload.content,
                    "persist_reply": False,
                },
            )
            if ai_res.status_code == 200:
                ai_data = ai_res.json()
                action = ai_data.get("action", "NONE")
                ai_action = action
                ai_status = "ok"
                bot_reply_text = ai_data.get("reply")

                # /incoming owns persistence for store chat replies. The AI
                # callback path is disabled for this request to avoid races.
                if bot_reply_text:
                    _insert_bot_reply(supabase_admin, ticket_id, bot_reply_text)

                # Nếu AI handoff → đánh dấu ticket rõ ràng cho staff demo.
                if action == "HANDOFF":
                    supabase_admin.table("tickets").update({
                        "intent": "complaint",
                        "status": "in_progress",
                    }).eq("id", ticket_id).execute()
                elif bot_reply_text:
                    supabase_admin.table("tickets").update({
                        "intent": "question",
                    }).eq("id", ticket_id).execute()
            else:
                ai_status = f"error:{ai_res.status_code}"
    except Exception as e:
        # AI service không phản hồi — ticket vẫn tồn tại, agent xử lý thủ công
        action, intent, reply = demo_store.fallback_ai_reply(payload.content)
        if reply:
            _insert_bot_reply_once(supabase_admin, ticket_id, reply)
            if action == "HANDOFF":
                supabase_admin.table("tickets").update({
                    "intent": "complaint",
                    "status": "in_progress",
                }).eq("id", ticket_id).execute()
            else:
                supabase_admin.table("tickets").update({
                    "intent": intent,
                }).eq("id", ticket_id).execute()
        ai_status = "fallback"
        ai_action = action

    return APIResponse(
        meta=MetaResponse(code=202, message="Message received."),
        data={
            "ticket_id": ticket_id,
            "ai_status": ai_status,
            "ai_action": ai_action,
        },
    )


@router.post("", response_model=APIResponse, status_code=201)
async def send_message(
    payload: MessageCreate,
    background_tasks: BackgroundTasks,
    current_user: dict = Depends(get_current_user),
):
    """
    Agent hoặc super_admin reply tin nhắn cho khách.
    Tự động gửi về đúng kênh (web realtime / facebook API / email).
    """
    supabase = get_supabase_client()

    # Kiểm tra ticket tồn tại
    ticket_result = (
        supabase.table("tickets")
        .select("id, source, status, customer_id, summary")
        .eq("id", str(payload.ticket_id))
        .single()
        .execute()
    )

    if not ticket_result.data:
        raise HTTPException(status_code=404, detail="Ticket not found.")

    ticket = ticket_result.data

    if ticket["status"] == "resolved":
        raise HTTPException(
            status_code=400,
            detail="Cannot reply to a closed ticket. Reopen it first.",
        )

    # Lưu message vào DB
    msg_result = (
        supabase.table("messages")
        .insert({
            "ticket_id": str(payload.ticket_id),
            "sender_type": SenderType.human.value,
            "sender_id": current_user["id"],
            "content": payload.content,
        })
        .execute()
    )

    # Tự động đổi status sang in_progress nếu đang open
    if ticket["status"] == "open":
        supabase.table("tickets").update({
            "status": "in_progress",
            "assigned_to": current_user["id"],
        }).eq("id", str(payload.ticket_id)).execute()

    # Gửi tin nhắn phản hồi đến kênh của khách hàng (FB/Email) bất đồng bộ
    background_tasks.add_task(
        dispatch_channel_reply,
        source=ticket["source"],
        customer_id=ticket["customer_id"],
        content=payload.content,
        ticket_summary=ticket.get("summary"),
    )

    return APIResponse(
        meta=MetaResponse(code=201, message="Message sent."),
        data=msg_result.data[0] if msg_result.data else None,
    )


class AgentReplyDemoPayload(BaseModel):
    ticket_id: str
    content: str


def _agent_reply_demo_fallback(payload: AgentReplyDemoPayload) -> APIResponse:
    t_id = str(payload.ticket_id).strip()
    ticket_detail = demo_store.get_ticket_detail(t_id)
    if not ticket_detail:
        raise HTTPException(status_code=404, detail="Ticket not found.")
    ticket = ticket_detail["ticket"]
    if ticket["status"] == "resolved":
        raise HTTPException(
            status_code=400,
            detail="Cannot reply to a closed ticket. Reopen it first.",
        )
    msg = demo_store.add_message(
        t_id,
        SenderType.human.value,
        "agent_demo",
        payload.content,
    )
    if ticket["status"] == "open":
        demo_store.update_ticket(t_id, status="in_progress")
    return APIResponse(
        meta=MetaResponse(code=201, message="Message sent (demo)."),
        data=msg,
    )


@router.post("/agent-reply-demo", response_model=APIResponse, status_code=201)
async def send_message_demo(
    payload: AgentReplyDemoPayload,
    background_tasks: BackgroundTasks,
):
    """
    Demo endpoint cho Flutter Web Admin (bỏ qua auth JWT)
    """
    t_id = str(payload.ticket_id).strip()
    try:
        supabase = get_supabase_admin()
        ticket_result = (
            supabase.table("tickets")
            .select("id, source, status, customer_id, summary")
            .eq("id", t_id)
            .single()
            .execute()
        )
    except Exception:
        return _agent_reply_demo_fallback(payload)

    if not ticket_result.data:
        raise HTTPException(status_code=404, detail="Ticket not found.")

    ticket = ticket_result.data

    if ticket["status"] == "resolved":
        raise HTTPException(
            status_code=400,
            detail="Cannot reply to a closed ticket. Reopen it first.",
        )

    admin_id = "agent_demo"
    msg_result = (
        supabase.table("messages")
        .insert({
            "ticket_id": str(payload.ticket_id),
            "sender_type": SenderType.human.value,
            "sender_id": admin_id,
            "content": payload.content,
        })
        .execute()
    )

    if ticket["status"] == "open":
        supabase.table("tickets").update({
            "status": "in_progress",
        }).eq("id", str(payload.ticket_id)).execute()

    background_tasks.add_task(
        dispatch_channel_reply,
        source=ticket["source"],
        customer_id=ticket["customer_id"],
        content=payload.content,
        ticket_summary=ticket.get("summary"),
    )

    return APIResponse(
        meta=MetaResponse(code=201, message="Message sent (demo)."),
        data=msg_result.data[0] if msg_result.data else None,
    )



from pydantic import BaseModel
class BotReplyCreate(BaseModel):
    ticket_id: UUID
    content: str

@router.post("/bot-reply", include_in_schema=False)
async def bot_reply(payload: BotReplyCreate):
    """
    Endpoint nội bộ: AI service gọi sau khi generate reply xong.
    Lưu message vào DB và Supabase Realtime sẽ broadcast.
    """
    try:
        supabase_admin = get_supabase_admin()
    except Exception:
        inserted = demo_store.add_bot_reply_once(str(payload.ticket_id), payload.content)
        return {"status": "saved" if inserted else "duplicate_ignored"}
    
    inserted = _insert_bot_reply_once(
        supabase_admin,
        ticket_id=str(payload.ticket_id),
        content=payload.content,
    )

    return {"status": "saved" if inserted else "duplicate_ignored"}
