from dataclasses import dataclass
from typing import Any, Protocol

from app.core.config import Settings, get_settings
from app.schemas.common import ChannelType
from app.services.email import get_email_provider
from app.services.exceptions import OutboundDeliveryError
from app.services.facebook import FacebookSendApiClient


@dataclass(frozen=True)
class OutboundDeliveryResult:
    channel: ChannelType
    delivered: bool
    provider_message_id: str | None = None
    realtime_record: dict[str, Any] | None = None


class ChannelSender(Protocol):
    def send(self, ticket: dict[str, Any], message: dict[str, Any]) -> OutboundDeliveryResult: ...


class WebRealtimeSender:
    def send(self, ticket: dict[str, Any], message: dict[str, Any]) -> OutboundDeliveryResult:
        realtime_record = {
            "event": "INSERT",
            "schema": "public",
            "table": "messages",
            "record": message,
        }
        return OutboundDeliveryResult(
            channel=ChannelType.WEB,
            delivered=True,
            provider_message_id=str(message["id"]),
            realtime_record=realtime_record,
        )


class LocalFacebookSender:
    def send(self, ticket: dict[str, Any], message: dict[str, Any]) -> OutboundDeliveryResult:
        return OutboundDeliveryResult(
            channel=ChannelType.FACEBOOK,
            delivered=True,
            provider_message_id=f"local-facebook-{message['id']}",
        )


class LocalEmailSender:
    def send(self, ticket: dict[str, Any], message: dict[str, Any]) -> OutboundDeliveryResult:
        return OutboundDeliveryResult(
            channel=ChannelType.EMAIL,
            delivered=True,
            provider_message_id=f"local-email-{message['id']}",
        )


class FacebookMessengerSender:
    def __init__(self, client: FacebookSendApiClient) -> None:
        self.client = client

    def send(self, ticket: dict[str, Any], message: dict[str, Any]) -> OutboundDeliveryResult:
        recipient_id = str(ticket.get("customer_id") or "")
        if not recipient_id:
            raise OutboundDeliveryError("Facebook recipient id is missing")
        provider_message_id = self.client.send_text(recipient_id, str(message["content"]))
        return OutboundDeliveryResult(
            channel=ChannelType.FACEBOOK,
            delivered=True,
            provider_message_id=provider_message_id,
        )


class EmailReplySender:
    def __init__(self, provider) -> None:
        self.provider = provider

    def send(self, ticket: dict[str, Any], message: dict[str, Any]) -> OutboundDeliveryResult:
        recipient = str(ticket.get("customer_id") or "")
        if not recipient:
            raise OutboundDeliveryError("Email recipient is missing")
        provider_message_id = self.provider.send_reply(
            recipient,
            f"Re: Support ticket {ticket.get('id', '')}",
            str(message["content"]),
        )
        return OutboundDeliveryResult(
            channel=ChannelType.EMAIL,
            delivered=True,
            provider_message_id=provider_message_id,
        )


class OutboundRouter:
    def __init__(self, senders: dict[ChannelType, ChannelSender] | None = None) -> None:
        self.senders = senders or {
            ChannelType.WEB: WebRealtimeSender(),
            ChannelType.FACEBOOK: LocalFacebookSender(),
            ChannelType.EMAIL: LocalEmailSender(),
        }

    def send_reply(
        self, ticket: dict[str, Any], message: dict[str, Any]
    ) -> OutboundDeliveryResult:
        source = ChannelType(ticket["source"])
        sender = self.senders[source]
        result = sender.send(ticket, message)
        if not result.delivered:
            raise OutboundDeliveryError(f"Outbound delivery failed for {source}")
        return result


def build_default_senders(settings: Settings) -> dict[ChannelType, ChannelSender]:
    facebook_sender: ChannelSender = (
        FacebookMessengerSender(FacebookSendApiClient(settings))
        if settings.facebook_page_access_token
        else LocalFacebookSender()
    )
    email_sender: ChannelSender = (
        EmailReplySender(get_email_provider(settings))
        if (
            (settings.outbound_email_provider.lower() == "sendgrid" and settings.sendgrid_api_key)
            or (
                settings.outbound_email_provider.lower() != "sendgrid"
                and settings.mailgun_api_key
                and settings.mailgun_domain
            )
        )
        else LocalEmailSender()
    )
    return {
        ChannelType.WEB: WebRealtimeSender(),
        ChannelType.FACEBOOK: facebook_sender,
        ChannelType.EMAIL: email_sender,
    }


def get_outbound_router() -> OutboundRouter:
    settings = get_settings()
    return OutboundRouter(build_default_senders(settings))
