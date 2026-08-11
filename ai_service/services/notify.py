"""
services/notify.py — Gửi push notification đến nhân viên CSKH qua Firebase FCM.

Staff của mỗi tenant subscribe vào topic "tenant_{tenant_id}".
Hoặc gửi trực tiếp đến từng FCM token (nếu muốn granular hơn).
"""
from __future__ import annotations

import logging

import db.queries as q

logger = logging.getLogger(__name__)

# Urgency → tiêu đề thông báo
_URGENCY_TITLES = {
    3: "🚨 Khẩn! Khách hàng cần hỗ trợ ngay",
    2: "⚠️ Có khiếu nại mới cần xử lý",
    1: "📩 Tin nhắn mới cần xem xét",
}


class NotifyService:
    """
    Gửi FCM push notification đến tất cả staff online của 1 tenant.

    Yêu cầu: firebase-admin đã init với credentials.
    Nếu chưa config FCM → log warning và bỏ qua (không crash).
    """

    def __init__(self, db):
        self._db      = db
        self._enabled = self._init_firebase()

    @staticmethod
    def _init_firebase() -> bool:
        from config import settings
        if not settings.fcm_credentials_path:
            logger.warning("FCM_CREDENTIALS_PATH not set — push notifications disabled")
            return False
        try:
            import firebase_admin
            from firebase_admin import credentials
            if not firebase_admin._apps:   # Chỉ init 1 lần
                cred = credentials.Certificate(settings.fcm_credentials_path)
                firebase_admin.initialize_app(cred)
            return True
        except Exception as exc:
            logger.error("Firebase init failed: %s", exc)
            return False

    async def send_urgent(
        self,
        tenant_id:  str,
        ticket_id:  str,
        urgency:    int,
        preview:    str,
    ) -> None:
        """
        Gửi push đến tất cả staff online của tenant.
        Fail silently — không để lỗi FCM ảnh hưởng đến main flow.
        """
        if not self._enabled:
            logger.debug("FCM disabled — skipping push for ticket=%s", ticket_id)
            return

        try:
            tokens = await q.get_staff_fcm_tokens(self._db, tenant_id)
            if not tokens:
                logger.debug("No online staff tokens for tenant=%s", tenant_id)
                return

            await self._send_to_tokens(tokens, ticket_id, urgency, preview)

        except Exception as exc:
            logger.error("Push notification failed for ticket=%s: %s", ticket_id, exc)

    @staticmethod
    async def _send_to_tokens(
        tokens:    list[str],
        ticket_id: str,
        urgency:   int,
        preview:   str,
    ) -> None:
        from firebase_admin import messaging

        title = _URGENCY_TITLES.get(urgency, _URGENCY_TITLES[1])
        body  = preview[:100] + ("..." if len(preview) > 100 else "")

        # MulticastMessage — gửi đến nhiều token cùng lúc (tối đa 500/batch)
        message = messaging.MulticastMessage(
            tokens=tokens[:500],
            notification=messaging.Notification(title=title, body=body),
            data={
                "ticket_id": ticket_id,
                "urgency":   str(urgency),
                "type":      "NEW_TICKET",
            },
            android=messaging.AndroidConfig(priority="high"),
            apns=messaging.APNSConfig(
                payload=messaging.APNSPayload(
                    aps=messaging.Aps(sound="default", badge=1)
                )
            ),
        )
        resp = messaging.send_each_for_multicast(message)
        logger.info(
            "FCM sent ticket=%s: %d success / %d fail",
            ticket_id, resp.success_count, resp.failure_count,
        )
