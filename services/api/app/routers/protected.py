from fastapi import APIRouter, Depends

from app.core.security import (
    AuthenticatedUser,
    require_agent_or_super_admin,
    require_super_admin,
)


router = APIRouter(tags=["protected"])


@router.get("/dashboard")
async def dashboard(
    current_user: AuthenticatedUser = Depends(require_super_admin),
) -> dict[str, str]:
    return {"status": "ok", "scope": "dashboard", "user_id": current_user.id}


@router.post("/documents/upload")
async def upload_document(
    current_user: AuthenticatedUser = Depends(require_super_admin),
) -> dict[str, str]:
    return {"status": "ok", "scope": "knowledge_base", "user_id": current_user.id}


@router.get("/staff")
async def staff_management(
    current_user: AuthenticatedUser = Depends(require_super_admin),
) -> dict[str, str]:
    return {"status": "ok", "scope": "staff", "user_id": current_user.id}


@router.get("/channels")
async def channel_settings(
    current_user: AuthenticatedUser = Depends(require_super_admin),
) -> dict[str, str]:
    return {"status": "ok", "scope": "channels", "user_id": current_user.id}


@router.get("/inbox")
async def inbox(
    current_user: AuthenticatedUser = Depends(require_agent_or_super_admin),
) -> dict[str, str]:
    return {"status": "ok", "scope": "inbox", "user_id": current_user.id}

