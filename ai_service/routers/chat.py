"""
routers/chat.py — Chat endpoint cho Web Widget.

POST /chat/message  → xử lý tin nhắn, trả về reply ngay (synchronous).
"""
from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException

from agent.schemas import ChatMessagePayload, ChatMessageResponse
from dependencies  import get_orchestrator

router = APIRouter()


@router.post("/message", response_model=ChatMessageResponse)
async def receive_message(
    payload:      ChatMessagePayload,
    orchestrator = Depends(get_orchestrator),
):
    """
    Web Chat Widget gửi tin nhắn vào.

    - Nếu AI xử lý → reply ngay trong response
    - Nếu human handling → reply rỗng (widget hiển thị "Đang kết nối nhân viên...")
    """
    if not payload.message.strip():
        raise HTTPException(status_code=400, detail="Message cannot be empty")

    result = await orchestrator.process(
        tenant_id=payload.tenant_id,
        conversation_id=payload.conversation_id,
        message=payload.message.strip(),
        channel=payload.channel,
    )

    return ChatMessageResponse(
        reply=result.reply,
        state=result.state,
        ticket_id=result.ticket_id,
        action=result.action,
    )
