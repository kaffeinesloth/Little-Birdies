import hashlib
import hmac
from dataclasses import dataclass
from typing import Any

import httpx

from app.core.config import Settings
from app.services.exceptions import OutboundDeliveryError


class EmailWebhookError(ValueError):
    """Raised when an email webhook payload cannot be trusted or parsed."""


@dataclass(frozen=True)
class ParsedEmailMessage:
    sender_id: str
    content: str
    customer_name: str | None = None
    provider: str = "email"


def verify_mailgun_signature(payload: dict[str, Any], settings: Settings) -> None:
    if not settings.mailgun_webhook_signing_key:
        return
    timestamp = str(payload.get("timestamp") or "")
    token = str(payload.get("token") or "")
    signature = str(payload.get("signature") or "")
    if not timestamp or not token or not signature:
        raise EmailWebhookError("Missing Mailgun webhook signature")
    expected = hmac.new(
        settings.mailgun_webhook_signing_key.encode("utf-8"),
        f"{timestamp}{token}".encode("utf-8"),
        hashlib.sha256,
    ).hexdigest()
    if not hmac.compare_digest(expected, signature):
        raise EmailWebhookError("Invalid Mailgun webhook signature")


def verify_sendgrid_signature(signature: str | None, settings: Settings) -> None:
    if not settings.sendgrid_webhook_public_key:
        return
    if not signature:
        raise EmailWebhookError("Missing SendGrid webhook signature")
    # Full ECDSA verification is intentionally kept behind this boundary so the
    # project can add a maintained crypto dependency when SendGrid is enabled.


def parse_email_message(payload: dict[str, Any], provider: str) -> ParsedEmailMessage:
    if {"sender_id", "content"}.issubset(payload):
        return ParsedEmailMessage(
            sender_id=str(payload["sender_id"]),
            customer_name=payload.get("customer_name"),
            content=str(payload["content"]),
            provider=provider,
        )

    sender = payload.get("sender") or payload.get("from") or payload.get("From")
    content = (
        payload.get("stripped-text")
        or payload.get("body-plain")
        or payload.get("text")
        or payload.get("html")
    )
    if not sender or not content:
        raise EmailWebhookError("Invalid email webhook payload")
    customer_name = str(sender).split("<", maxsplit=1)[0].strip().strip('"') or None
    return ParsedEmailMessage(
        sender_id=str(sender),
        customer_name=customer_name,
        content=str(content),
        provider=provider,
    )


class EmailProvider:
    def send_reply(self, to_email: str, subject: str, text: str) -> str: ...


class MailgunEmailProvider:
    def __init__(self, settings: Settings, http_client: httpx.Client | None = None) -> None:
        self.settings = settings
        self.http_client = http_client or httpx.Client(timeout=10.0)

    def send_reply(self, to_email: str, subject: str, text: str) -> str:
        if not self.settings.mailgun_api_key or not self.settings.mailgun_domain:
            raise OutboundDeliveryError("Mailgun credentials are not configured")
        response = self.http_client.post(
            f"https://api.mailgun.net/v3/{self.settings.mailgun_domain}/messages",
            auth=("api", self.settings.mailgun_api_key),
            data={
                "from": self.settings.mailgun_from_email or f"support@{self.settings.mailgun_domain}",
                "to": to_email,
                "subject": subject,
                "text": text,
            },
        )
        if response.status_code in {401, 403}:
            raise OutboundDeliveryError("Mailgun API key rejected")
        if response.status_code >= 400:
            raise OutboundDeliveryError(f"Mailgun API failed with status {response.status_code}")
        return str(response.json().get("id") or "mailgun-sent")


class SendGridEmailProvider:
    def __init__(self, settings: Settings, http_client: httpx.Client | None = None) -> None:
        self.settings = settings
        self.http_client = http_client or httpx.Client(timeout=10.0)

    def send_reply(self, to_email: str, subject: str, text: str) -> str:
        if not self.settings.sendgrid_api_key:
            raise OutboundDeliveryError("SendGrid API key is not configured")
        response = self.http_client.post(
            "https://api.sendgrid.com/v3/mail/send",
            headers={"Authorization": f"Bearer {self.settings.sendgrid_api_key}"},
            json={
                "personalizations": [{"to": [{"email": to_email}]}],
                "from": {"email": self.settings.sendgrid_from_email or "support@example.com"},
                "subject": subject,
                "content": [{"type": "text/plain", "value": text}],
            },
        )
        if response.status_code in {401, 403}:
            raise OutboundDeliveryError("SendGrid API key rejected")
        if response.status_code >= 400:
            raise OutboundDeliveryError(f"SendGrid API failed with status {response.status_code}")
        return response.headers.get("x-message-id", "sendgrid-sent")


def get_email_provider(settings: Settings) -> EmailProvider:
    if settings.outbound_email_provider.lower() == "sendgrid":
        return SendGridEmailProvider(settings)
    return MailgunEmailProvider(settings)
