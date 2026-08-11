from fastapi import APIRouter, Depends

from app.core.security import AuthenticatedUser, require_agent_or_super_admin
from app.db.supabase import get_supabase_client
from app.schemas.users import PresenceUpdate
from app.services.supabase_table import SupabaseClient
from app.services.users import UserService


router = APIRouter(prefix="/presence", tags=["presence"])


@router.post("/status")
async def update_presence_status(
    payload: PresenceUpdate,
    current_user: AuthenticatedUser = Depends(require_agent_or_super_admin),
    client: SupabaseClient = Depends(get_supabase_client),
) -> dict:
    return UserService(client).update_presence(current_user.id, payload.status)


@router.post("/heartbeat")
async def heartbeat(
    current_user: AuthenticatedUser = Depends(require_agent_or_super_admin),
    client: SupabaseClient = Depends(get_supabase_client),
) -> dict:
    service = UserService(client)
    user = service.heartbeat(current_user.id)
    stale_users = service.mark_stale_online_users_offline(stale_after_seconds=30)
    return {"user": user, "stale_users_marked_offline": len(stale_users)}
