from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from core.database import get_supabase_client

bearer_scheme = HTTPBearer()


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme),
) -> dict:
    """
    Dependency: xác thực JWT token từ Supabase Auth.
    Trả về dict user { id, email, role, status } hoặc raise 401.
    """
    token = credentials.credentials
    supabase = get_supabase_client()

    try:
        # Verify token với Supabase
        response = supabase.auth.get_user(token)
        auth_user = response.user
        if not auth_user:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Token không hợp lệ hoặc đã hết hạn.",
            )
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token không hợp lệ hoặc đã hết hạn.",
        )

    # Lấy thông tin role từ bảng public.users
    result = (
        supabase.table("users")
        .select("id, email, full_name, role, status")
        .eq("id", auth_user.id)
        .single()
        .execute()
    )

    if not result.data:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Tài khoản không tồn tại trong hệ thống.",
        )

    user = result.data
    if user["status"] == "disabled":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Tài khoản của bạn đã bị vô hiệu hóa.",
        )

    return user


async def require_super_admin(current_user: dict = Depends(get_current_user)) -> dict:
    """Dependency: chỉ cho phép super_admin truy cập."""
    if current_user["role"] != "super_admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Chỉ super_admin mới có quyền thực hiện thao tác này.",
        )
    return current_user
