from fastapi import APIRouter, Depends, HTTPException, Query
from uuid import UUID
from typing import Optional

from core.auth import get_current_user, require_super_admin
from core.database import get_supabase_admin
from models.domain import (
    APIResponse, MetaResponse,
    UserCreate, UserStatusUpdate, UserOut,
    UserStatus,
)

router = APIRouter()


@router.get("/me", response_model=APIResponse)
def get_me(current_user: dict = Depends(get_current_user)):
    """Lấy thông tin profile của user hiện tại."""
    return APIResponse(
        meta=MetaResponse(code=200, message="Success"),
        data=current_user,
    )


@router.patch("/me/status", response_model=APIResponse)
def update_my_status(
    payload: UserStatusUpdate,
    current_user: dict = Depends(get_current_user),
):
    """
    Agent bật/tắt trạng thái Online/Offline để nhận Ticket mới.
    Không cho phép set status=disabled (disabled chỉ super_admin mới làm được).
    """
    if payload.status == UserStatus.disabled:
        raise HTTPException(
            status_code=403,
            detail="Bạn không thể tự vô hiệu hóa tài khoản của mình.",
        )

    supabase = get_supabase_admin()
    from datetime import datetime, timezone

    update_data = {"status": payload.status.value}
    if payload.status == UserStatus.online:
        update_data["last_seen_at"] = datetime.now(timezone.utc).isoformat()

    supabase.table("users").update(update_data).eq("id", current_user["id"]).execute()

    return APIResponse(
        meta=MetaResponse(
            code=200,
            message=f"Trạng thái đã chuyển sang {payload.status.value}.",
        ),
        data={"status": payload.status.value},
    )


@router.patch("/me/fcm-token", response_model=APIResponse)
def update_fcm_token(
    body: dict,
    current_user: dict = Depends(get_current_user),
):
    """Mobile app cập nhật FCM token sau khi đăng nhập."""
    token = body.get("fcm_token")
    if not token:
        raise HTTPException(status_code=400, detail="fcm_token là bắt buộc.")

    supabase = get_supabase_admin()
    supabase.table("users").update({"fcm_token": token}).eq("id", current_user["id"]).execute()

    return APIResponse(
        meta=MetaResponse(code=200, message="FCM token đã được cập nhật."),
        data=None,
    )


# ---- Super Admin quản lý agents ----

@router.get("", response_model=APIResponse)
def list_users(
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    search: Optional[str] = None,
    current_user: dict = Depends(require_super_admin),
):
    """super_admin xem danh sách tất cả agents."""
    supabase = get_supabase_admin()
    offset = (page - 1) * limit

    query = supabase.table("users").select(
        "id, email, full_name, role, status, avatar_url, created_at, last_seen_at",
        count="exact",
    )

    if search:
        query = query.or_(f"email.ilike.%{search}%,full_name.ilike.%{search}%")

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


@router.post("", response_model=APIResponse, status_code=201)
def invite_agent(
    payload: UserCreate,
    current_user: dict = Depends(require_super_admin),
):
    """
    super_admin tạo tài khoản agent mới bằng cách gửi invite email.
    Supabase Auth sẽ gửi email mời đặt mật khẩu.
    Trigger on_auth_user_created sẽ tự tạo record trong public.users.
    """
    supabase = get_supabase_admin()

    try:
        response = supabase.auth.admin.invite_user_by_email(
            payload.email,
            options={
                "data": {
                    "full_name": payload.full_name,
                    "role": payload.role.value,
                }
            },
        )
    except Exception as e:
        error_msg = str(e)
        if "already registered" in error_msg.lower():
            raise HTTPException(status_code=409, detail="Email đã tồn tại trong hệ thống.")
        raise HTTPException(status_code=500, detail=f"Không thể tạo tài khoản: {error_msg}")

    return APIResponse(
        meta=MetaResponse(
            code=201,
            message=f"Email mời đã được gửi đến {payload.email}.",
        ),
        data={"email": payload.email, "role": payload.role.value},
    )


@router.patch("/{user_id}/status", response_model=APIResponse)
def update_user_status(
    user_id: UUID,
    payload: UserStatusUpdate,
    current_user: dict = Depends(require_super_admin),
):
    """super_admin vô hiệu hóa / kích hoạt lại tài khoản agent."""
    if str(user_id) == current_user["id"]:
        raise HTTPException(
            status_code=400,
            detail="Không thể thay đổi trạng thái tài khoản của chính mình.",
        )

    supabase = get_supabase_admin()

    result = (
        supabase.table("users")
        .update({"status": payload.status.value})
        .eq("id", str(user_id))
        .execute()
    )

    if not result.data:
        raise HTTPException(status_code=404, detail="Người dùng không tồn tại.")

    return APIResponse(
        meta=MetaResponse(
            code=200,
            message=f"Trạng thái tài khoản đã được đổi thành {payload.status.value}.",
        ),
        data=None,
    )
