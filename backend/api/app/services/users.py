from datetime import UTC, datetime, timedelta
from typing import Any

from app.schemas.common import UserStatus
from app.schemas.users import UserCreate, UserUpdate
from app.services.supabase_table import SupabaseClient, TableService


class UserService(TableService):
    def __init__(self, client: SupabaseClient) -> None:
        super().__init__(client, "users")

    def create_user(self, payload: UserCreate) -> dict[str, Any]:
        return self.create(payload)

    def get_user(self, user_id: str) -> dict[str, Any]:
        return self.get(user_id)

    def update_user(self, user_id: str, payload: UserUpdate) -> dict[str, Any]:
        return self.update(user_id, payload)

    def update_presence(self, user_id: str, status: UserStatus) -> dict[str, Any]:
        return self.update_user(
            user_id,
            UserUpdate(status=status, last_seen_at=datetime.now(UTC)),
        )

    def heartbeat(self, user_id: str) -> dict[str, Any]:
        return self.update_user(
            user_id,
            UserUpdate(status=UserStatus.ONLINE, last_seen_at=datetime.now(UTC)),
        )

    def mark_stale_online_users_offline(self, stale_after_seconds: int = 30) -> list[dict[str, Any]]:
        cutoff = datetime.now(UTC) - timedelta(seconds=stale_after_seconds)
        result = self.client.table(self.table_name).select("*").execute()
        updated = []
        for user in result.data or []:
            if user.get("status") != UserStatus.ONLINE:
                continue
            last_seen_raw = user.get("last_seen_at")
            if not last_seen_raw:
                continue
            last_seen = datetime.fromisoformat(str(last_seen_raw).replace("Z", "+00:00"))
            if last_seen < cutoff:
                updated.append(self.update_presence(user["id"], UserStatus.OFFLINE))
        return updated
