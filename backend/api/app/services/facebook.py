import hmac
import hashlib
from dataclasses import dataclass
from typing import Any

import httpx

from app.core.config import Settings
from app.services.exceptions import OutboundDeliveryError


class FacebookWebhookError(ValueError):
    """Raised when a Facebook webhook payload cannot be trusted or parsed."""


@dataclass(frozen=True)
class ParsedFacebookMessage:
    sender_id: str
    content: str
    customer_name: str | None = None


def verify_facebook_signature(signature: str | None, raw_body: bytes, settings: Settings) -> None:
    if not settings.facebook_app_secret:
        return
    if not signature or not signature.startswith("sha256="):
        raise FacebookWebhookError("Missing Facebook webhook signature")
    expected = hmac.new(
        settings.facebook_app_secret.encode("utf-8"),
        raw_body,
        hashlib.sha256,
    ).hexdigest()
    supplied = signature.removeprefix("sha256=")
    if not hmac.compare_digest(expected, supplied):
        raise FacebookWebhookError("Invalid Facebook webhook signature")


def parse_facebook_message(payload: dict[str, Any]) -> ParsedFacebookMessage | None:
    if {"sender_id", "content"}.issubset(payload):
        return ParsedFacebookMessage(
            sender_id=str(payload["sender_id"]),
            customer_name=payload.get("customer_name"),
            content=str(payload["content"]),
        )

    entries = payload.get("entry")
    if not isinstance(entries, list):
        raise FacebookWebhookError("Invalid Facebook webhook payload")
    for entry in entries:
        events = entry.get("messaging") if isinstance(entry, dict) else None
        if not isinstance(events, list):
            continue
        for event in events:
            if not isinstance(event, dict) or event.get("message", {}).get("is_echo"):
                continue
            sender_id = event.get("sender", {}).get("id")
            text = event.get("message", {}).get("text")
            if sender_id and text:
                return ParsedFacebookMessage(sender_id=str(sender_id), content=str(text))
    return None


class FacebookSendApiClient:
    graph_url = "https://graph.facebook.com/v20.0/me/messages"

    def __init__(self, settings: Settings, http_client: httpx.Client | None = None) -> None:
        self.settings = settings
        self.http_client = http_client or httpx.Client(timeout=10.0)

    def send_text(self, recipient_id: str, text: str) -> str:
        if not self.settings.facebook_page_access_token:
            raise OutboundDeliveryError("Facebook page access token is not configured")
        response = self.http_client.post(
            self.graph_url,
            params={"access_token": self.settings.facebook_page_access_token},
            json={
                "recipient": {"id": recipient_id},
                "messaging_type": "RESPONSE",
                "message": {"text": text},
            },
        )
        if response.status_code in {400, 401, 403}:
            raise OutboundDeliveryError("Facebook token rejected by Send API")
        if response.status_code >= 400:
            raise OutboundDeliveryError(f"Facebook Send API failed with status {response.status_code}")
        data = response.json()
        return str(data.get("message_id") or data.get("recipient_id") or "facebook-sent")
