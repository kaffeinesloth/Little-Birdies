from typing import Any

from app.schemas.common import SenderType
from app.schemas.messages import MessageCreate, MessageUpdate
from app.services.supabase_table import SupabaseClient, TableService


class MessageService(TableService):
    def __init__(self, client: SupabaseClient) -> None:
        super().__init__(client, "messages")

    def create_message(self, payload: MessageCreate) -> dict[str, Any]:
        payload.sender_type = SenderType(payload.sender_type)
        return self.create(payload)

    def get_message(self, message_id: str) -> dict[str, Any]:
        return self.get(message_id)

    def update_message(self, message_id: str, payload: MessageUpdate) -> dict[str, Any]:
        return self.update(message_id, payload)

    def list_ticket_messages(self, ticket_id: str) -> list[dict[str, Any]]:
        result = (
            self.client.table(self.table_name)
            .select("*")
            .eq("ticket_id", ticket_id)
            .order("created_at")
            .execute()
        )
        return result.data or []
