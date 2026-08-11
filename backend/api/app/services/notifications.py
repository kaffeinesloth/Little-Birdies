from datetime import UTC, datetime
from typing import Any

from app.schemas.notifications import NotificationCreate, NotificationUpdate
from app.services.fcm import FCMSender, LocalFCMSender
from app.services.supabase_table import SupabaseClient, TableService


class NotificationService(TableService):
    def __init__(self, client: SupabaseClient, fcm_sender: FCMSender | None = None) -> None:
        super().__init__(client, "notifications")
        self.fcm_sender = fcm_sender or LocalFCMSender()

    def create_notification(self, payload: NotificationCreate) -> dict[str, Any]:
        return self.create(payload)

    def get_notification(self, notification_id: str) -> dict[str, Any]:
        return self.get(notification_id)

    def update_notification(
        self, notification_id: str, payload: NotificationUpdate
    ) -> dict[str, Any]:
        return self.update(notification_id, payload)

    def create_for_online_agents(
        self,
        *,
        ticket_id: str,
        title: str,
        body: str,
    ) -> list[dict[str, Any]]:
        return self.create_urgent_ticket_notifications(
            ticket_id=ticket_id,
            title=title,
            body=body,
        )

    def _staff_users(self) -> list[dict[str, Any]]:
        users_result = self.client.table("users").select("*").execute()
        return [
            user
            for user in users_result.data or []
            if user.get("role") in {"agent", "super_admin"} and user.get("status") != "disabled"
        ]

    def create_urgent_ticket_notifications(
        self,
        *,
        ticket_id: str,
        title: str,
        body: str,
    ) -> list[dict[str, Any]]:
        staff_users = self._staff_users()
        online_users = [user for user in staff_users if user.get("status") == "online"]
        recipients = online_users or staff_users
        notifications = []
        for user in recipients:
            sent_at = datetime.now(UTC) if user in online_users else None
            notifications.append(
                self.create_notification(
                    NotificationCreate(
                        ticket_id=ticket_id,
                        recipient_id=user["id"],
                        title=title,
                        body=body,
                        sent_at=sent_at,
                    )
                )
            )
            if user in online_users:
                self.fcm_sender.send(
                    user=user,
                    title=title,
                    body=body,
                    data={"ticket_id": ticket_id, "type": "urgent_ticket"},
                )
        return notifications
