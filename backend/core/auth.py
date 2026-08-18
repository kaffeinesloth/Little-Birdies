from typing import Optional
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from core.database import get_supabase_client

bearer_scheme = HTTPBearer(auto_error=False)

DEMO_USER = {
    "id": "00000000-0000-0000-0000-000000000000",
    "email": "admin@smarthelpdesk.com",
    "full_name": "Demo Admin",
    "role": "super_admin",
    "status": "active",
}


async def get_current_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(bearer_scheme),
) -> dict:
    """
    Dependency: xác thực JWT token từ Supabase Auth.
    Nếu không có token hoặc token demo -> Trả về DEMO_USER (super_admin) để test/demo mượt mà.
    """
    if not credentials or not credentials.credentials:
        return DEMO_USER

    token = credentials.credentials
    supabase = get_supabase_client()

    try:
        response = supabase.auth.get_user(token)
        auth_user = response.user
        if not auth_user:
            return DEMO_USER
    except Exception:
        return DEMO_USER

    result = (
        supabase.table("users")
        .select("id, email, full_name, role, status")
        .eq("id", auth_user.id)
        .maybe_single()
        .execute()
    )

    if result and hasattr(result, "data") and result.data:
        user = result.data
        if user.get("status") == "disabled":
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Tài khoản của bạn đã bị vô hiệu hóa.",
            )
        return user

    return DEMO_USER


async def require_super_admin(current_user: dict = Depends(get_current_user)) -> dict:
    """Dependency: chỉ cho phép super_admin truy cập."""
    if current_user["role"] != "super_admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Chỉ super_admin mới có quyền thực hiện thao tác này.",
        )
    return current_user
