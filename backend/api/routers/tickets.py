from fastapi import APIRouter, Depends, HTTPException, status, Query
from typing import Optional
from uuid import UUID

from core.auth import get_current_user, require_super_admin
from core.database import get_supabase_client
from models.domain import (
    APIResponse, MetaResponse,
    TicketCreate, TicketUpdate, TicketOut,
    TicketStatus, TicketSource,
)

router = APIRouter()


@router.get("/stats/dashboard", response_model=APIResponse)
def get_dashboard_stats(
    current_user: dict = Depends(require_super_admin),
):
    """
    Thống kê tổng quan cho super_admin:
    - Tổng ticket hôm nay
    - Ticket đang mở
    - Ticket resolved hôm nay
    - % AI tự xử lý (question intent, không cần agent)
    """
    supabase = get_supabase_client()
    from datetime import datetime, timezone

    today_start = datetime.now(timezone.utc).replace(
        hour=0, minute=0, second=0, microsecond=0
    ).isoformat()

    # Tổng ticket hôm nay
    today_result = (
        supabase.table("tickets")
        .select("id, intent, status", count="exact")
        .gte("created_at", today_start)
        .execute()
    )
    today_tickets = today_result.data or []
    total_today = today_result.count or 0

    # Ticket đang mở
    open_result = (
        supabase.table("tickets")
        .select("id", count="exact")
        .in_("status", ["open", "in_progress", "pending"])
        .execute()
    )

    # Ticket resolved hôm nay
    resolved_today = sum(
        1 for t in today_tickets if t["status"] == "resolved"
    )

    # % AI tự xử lý = ticket intent=question và status=resolved / tổng hôm nay
    ai_handled = sum(
        1 for t in today_tickets
        if t["intent"] == "question" and t["status"] == "resolved"
    )
    ai_percent = round((ai_handled / total_today * 100) if total_today > 0 else 0, 1)

    return APIResponse(
        meta=MetaResponse(code=200, message="Success"),
        data={
            "total_tickets_today": total_today,
            "open_tickets": open_result.count or 0,
            "resolved_tickets_today": resolved_today,
            "ai_handled_percent": ai_percent,
        },
    )


@router.get("", response_model=APIResponse)
def list_tickets(
    ticket_status: Optional[TicketStatus] = Query(None, alias="status"),
    source: Optional[TicketSource] = None,
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    current_user: dict = Depends(get_current_user),
):
    """
    Lấy danh sách tickets.
    - super_admin: thấy tất cả
    - agent: chỉ thấy ticket open / in_progress / được giao cho mình
    """
    supabase = get_supabase_client()
    offset = (page - 1) * limit

    query = supabase.table("tickets").select("*", count="exact")

    # Phân quyền
    if current_user["role"] == "agent":
        # Agent chỉ thấy ticket open, in_progress, hoặc giao cho mình
        query = query.or_(
            f"status.in.(open,in_progress),assigned_to.eq.{current_user['id']}"
        )

    # Filter tùy chọn
    if ticket_status:
        query = query.eq("status", ticket_status.value)
    if source:
        query = query.eq("source", source.value)

    result = (
        query.order("created_at", desc=True)
        .range(offset, offset + limit - 1)
        .execute()
    )

    return APIResponse(
        meta=MetaResponse(code=200, message="Success"),
        data={
            "items": result.data,
            "total": result.count,
            "page": page,
            "limit": limit,
        },
    )


@router.get("/{ticket_id}", response_model=APIResponse)
def get_ticket(
    ticket_id: UUID,
    current_user: dict = Depends(get_current_user),
):
    """Lấy chi tiết 1 ticket kèm toàn bộ messages."""
    supabase = get_supabase_client()

    ticket_result = (
        supabase.table("tickets")
        .select("*")
        .eq("id", str(ticket_id))
        .single()
        .execute()
    )

    if not ticket_result.data:
        raise HTTPException(status_code=404, detail="Ticket không tồn tại.")

    ticket = ticket_result.data

    # Agent không được xem ticket resolved của người khác
    if (
        current_user["role"] == "agent"
        and ticket["status"] == "resolved"
        and ticket["assigned_to"] != current_user["id"]
    ):
        raise HTTPException(status_code=403, detail="Bạn không có quyền xem ticket này.")

    # Lấy toàn bộ messages của ticket
    messages_result = (
        supabase.table("messages")
        .select("*")
        .eq("ticket_id", str(ticket_id))
        .order("created_at")
        .execute()
    )

    return APIResponse(
        meta=MetaResponse(code=200, message="Success"),
        data={
            "ticket": ticket,
            "messages": messages_result.data,
        },
    )


@router.patch("/{ticket_id}", response_model=APIResponse)
def update_ticket(
    ticket_id: UUID,
    payload: TicketUpdate,
    current_user: dict = Depends(get_current_user),
):
    """
    Cập nhật status hoặc assigned_to của ticket.
    Agent chỉ được đổi status; super_admin đổi cả assigned_to.
    """
    supabase = get_supabase_client()

    update_data = payload.model_dump(exclude_none=True)

    # Agent không được tự assign ticket cho người khác
    if current_user["role"] == "agent" and "assigned_to" in update_data:
        raise HTTPException(
            status_code=403,
            detail="Agent không có quyền thay đổi người phụ trách.",
        )

    if not update_data:
        raise HTTPException(status_code=400, detail="Không có trường nào để cập nhật.")

    # Nếu resolve → ghi resolved_at
    if update_data.get("status") == "resolved":
        from datetime import datetime, timezone
        update_data["resolved_at"] = datetime.now(timezone.utc).isoformat()

    result = (
        supabase.table("tickets")
        .update(update_data)
        .eq("id", str(ticket_id))
        .execute()
    )

    if not result.data:
        raise HTTPException(status_code=404, detail="Ticket không tồn tại.")

    return APIResponse(
        meta=MetaResponse(code=200, message="Ticket đã được cập nhật."),
        data=result.data[0],
    )



