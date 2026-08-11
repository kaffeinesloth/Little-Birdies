from dataclasses import dataclass
from typing import Any, Protocol


@dataclass(frozen=True)
class FCMPushResult:
    recipient_id: str
    delivered: bool
    provider_message_id: str | None = None
    reason: str | None = None


class FCMSender(Protocol):
    def send(self, *, user: dict[str, Any], title: str, body: str, data: dict[str, Any]) -> FCMPushResult: ...


class LocalFCMSender:
    def __init__(self) -> None:
        self.sent: list[dict[str, Any]] = []

    def send(self, *, user: dict[str, Any], title: str, body: str, data: dict[str, Any]) -> FCMPushResult:
        payload = {
            "recipient_id": user["id"],
            "title": title,
            "body": body,
            "data": data,
        }
        self.sent.append(payload)
        return FCMPushResult(
            recipient_id=user["id"],
            delivered=True,
            provider_message_id=f"local-fcm-{user['id']}",
        )


def get_fcm_sender() -> FCMSender:
    return LocalFCMSender()
