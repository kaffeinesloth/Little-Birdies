import httpx
from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks
from uuid import UUID

from core.auth import get_current_user
from core.database import get_supabase_client, get_supabase_admin
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
                "customer_name": payload.customer_name or "Khách Hàng SportGear",
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
                },
            )
            if ai_res.status_code == 200:
                ai_data = ai_res.json()
                action = ai_data.get("action", "NONE")
                bot_reply_text = ai_data.get("reply")

                # Lưu ngay phản hồi của Bot nếu có
                if bot_reply_text:
                    # Kiểm tra xem tin nhắn bot đã được callback lưu chưa
                    existing_bot_msg = (
                        supabase_admin.table("messages")
                        .select("id")
                        .eq("ticket_id", ticket_id)
                        .eq("sender_type", SenderType.bot.value)
                        .order("created_at", desc=True)
                        .limit(1)
                        .execute()
                    )
                    if not existing_bot_msg.data:
                        supabase_admin.table("messages").insert({
                            "ticket_id": ticket_id,
                            "sender_type": SenderType.bot.value,
                            "sender_id": "ai-bot",
                            "content": bot_reply_text,
                        }).execute()

                # Nếu AI handoff → đánh dấu ticket
                if action == "HANDOFF":
                    supabase_admin.table("tickets").update({
                        "intent": "complaint",
                    }).eq("id", ticket_id).execute()
    except Exception as e:
        # AI service không phản hồi — ticket vẫn tồn tại, agent xử lý thủ công
        pass

    return APIResponse(
        meta=MetaResponse(code=202, message="Tin nhắn đã được tiếp nhận."),
        data={"ticket_id": ticket_id},
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
        raise HTTPException(status_code=404, detail="Ticket không tồn tại.")

    ticket = ticket_result.data

    if ticket["status"] == "resolved":
        raise HTTPException(
            status_code=400,
            detail="Không thể reply ticket đã đóng. Reopen ticket trước.",
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
        meta=MetaResponse(code=201, message="Tin nhắn đã được gửi."),
        data=msg_result.data[0] if msg_result.data else None,
    )


class AgentReplyDemoPayload(BaseModel):
    ticket_id: str
    content: str

@router.post("/agent-reply-demo", response_model=APIResponse, status_code=201)
async def send_message_demo(
    payload: AgentReplyDemoPayload,
    background_tasks: BackgroundTasks,
):
    """
    Demo endpoint cho Flutter Web Admin (bỏ qua auth JWT)
    """
    supabase = get_supabase_admin()
    t_id = str(payload.ticket_id).strip()
    
    ticket_result = (
        supabase.table("tickets")
        .select("id, source, status, customer_id, summary")
        .eq("id", t_id)
        .single()
        .execute()
    )

    if not ticket_result.data:
        raise HTTPException(status_code=404, detail="Ticket không tồn tại.")

    ticket = ticket_result.data

    if ticket["status"] == "resolved":
        raise HTTPException(
            status_code=400,
            detail="Không thể reply ticket đã đóng. Reopen ticket trước.",
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
        meta=MetaResponse(code=201, message="Tin nhắn đã được gửi (Demo)."),
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
    supabase_admin = get_supabase_admin()
    
    msg_result = (
        supabase_admin.table("messages")
        .insert({
            "ticket_id": str(payload.ticket_id),
            "sender_type": SenderType.bot.value,
            "sender_id": "ai-bot",
            "content": payload.content,
        })
        .execute()
    )
    
    return {"status": "saved"}
