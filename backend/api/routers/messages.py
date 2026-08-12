import httpx
import os
from fastapi import APIRouter, Depends, HTTPException
from uuid import UUID

from core.auth import get_current_user
from core.database import get_supabase_admin
from models.domain import (
    APIResponse, MetaResponse,
    MessageCreate, IncomingMessage,
    SenderType,
)

router = APIRouter()

AI_SERVICE_URL = os.getenv("AI_SERVICE_URL", "http://localhost:8001")


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
    else:
        # Tạo ticket mới — intent sẽ được AI cập nhật sau
        new_ticket = (
            supabase_admin.table("tickets")
            .insert({
                "customer_id": payload.customer_id,
                "customer_name": payload.customer_name,
                "source": payload.source.value,
                "status": "open",
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

    # 3. Gọi AI service (fire-and-forget style, không await kết quả)
    try:
        async with httpx.AsyncClient(timeout=30.0) as client:
            await client.post(
                f"{AI_SERVICE_URL}/process",
                json={
                    "ticket_id": ticket_id,
                    "customer_id": payload.customer_id,
                    "source": payload.source.value,
                    "content": payload.content,
                },
            )
    except Exception:
        # AI service không phản hồi — ticket vẫn tồn tại, agent xử lý thủ công
        pass

    return APIResponse(
        meta=MetaResponse(code=202, message="Tin nhắn đã được tiếp nhận."),
        data={"ticket_id": ticket_id},
    )


@router.post("", response_model=APIResponse, status_code=201)
def send_message(
    payload: MessageCreate,
    current_user: dict = Depends(get_current_user),
):
    """
    Agent hoặc super_admin reply tin nhắn cho khách.
    Tự động gửi về đúng kênh (web realtime / facebook API / email).
    """
    supabase = get_supabase_admin()

    # Kiểm tra ticket tồn tại
    ticket_result = (
        supabase.table("tickets")
        .select("id, source, status, customer_id")
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

    # TODO: Nếu source=facebook → gọi FB Send API
    # TODO: Nếu source=email → gọi Mailgun API
    # Nếu source=web → Supabase Realtime tự broadcast khi INSERT messages

    return APIResponse(
        meta=MetaResponse(code=201, message="Tin nhắn đã được gửi."),
        data=msg_result.data[0] if msg_result.data else None,
    )
