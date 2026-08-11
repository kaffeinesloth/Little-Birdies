from fastapi import APIRouter, Depends, HTTPException
from uuid import UUID

from core.auth import get_current_user, require_super_admin
from core.database import get_supabase_client
from models.domain import APIResponse, MetaResponse, ChannelUpdate

router = APIRouter()


@router.get("", response_model=APIResponse)
def list_channels(current_user: dict = Depends(get_current_user)):
    """Lấy danh sách kênh và trạng thái kết nối (không trả về config secrets)."""
    supabase = get_supabase_client()

    result = (
        supabase.table("channels")
        .select("id, type, is_active, connected_at")
        .order("type")
        .execute()
    )

    return APIResponse(
        meta=MetaResponse(code=200, message="Success"),
        data=result.data,
    )


@router.put("/{channel_type}", response_model=APIResponse)
def configure_channel(
    channel_type: str,
    payload: ChannelUpdate,
    current_user: dict = Depends(require_super_admin),
):
    """
    super_admin cấu hình kênh chat.
    Ví dụ: gán Page Access Token cho Facebook, API key cho Mailgun.
    config là dict tự do — backend lưu nguyên vào JSONB.
    """
    supabase = get_supabase_client()

    if channel_type not in ("web", "facebook", "email"):
        raise HTTPException(status_code=400, detail="Loại kênh không hợp lệ.")

    from datetime import datetime, timezone
    update_data = {
        "config": payload.config,
        "is_active": payload.is_active,
        "connected_at": datetime.now(timezone.utc).isoformat() if payload.is_active else None,
    }

    result = (
        supabase.table("channels")
        .update(update_data)
        .eq("type", channel_type)
        .execute()
    )

    if not result.data:
        raise HTTPException(status_code=404, detail="Kênh không tồn tại.")

    # Trả về không có config (ẩn secrets)
    channel = result.data[0]
    channel.pop("config", None)

    return APIResponse(
        meta=MetaResponse(code=200, message=f"Kênh {channel_type} đã được cập nhật."),
        data=channel,
    )


@router.delete("/{channel_type}/disconnect", response_model=APIResponse)
def disconnect_channel(
    channel_type: str,
    current_user: dict = Depends(require_super_admin),
):
    """super_admin ngắt kết nối 1 kênh (xóa config, set is_active=false)."""
    supabase = get_supabase_client()

    if channel_type not in ("web", "facebook", "email"):
        raise HTTPException(status_code=400, detail="Loại kênh không hợp lệ.")

    supabase.table("channels").update({
        "config": {},
        "is_active": False,
        "connected_at": None,
    }).eq("type", channel_type).execute()

    return APIResponse(
        meta=MetaResponse(code=200, message=f"Kênh {channel_type} đã bị ngắt kết nối."),
        data=None,
    )
