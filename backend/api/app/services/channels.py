from typing import Any

from app.schemas.channels import ChannelCreate, ChannelPublic, ChannelUpdate
from app.services.supabase_table import SupabaseClient, TableService


SECRET_CONFIG_KEYS = {
    "api_key",
    "app_secret",
    "access_token",
    "page_access_token",
    "webhook_signing_key",
    "service_account_json",
    "sendgrid_api_key",
    "mailgun_api_key",
    "fcm_service_account_json",
}


def redact_channel_config(config: dict[str, Any]) -> dict[str, Any]:
    redacted: dict[str, Any] = {}
    for key, value in config.items():
        if key.lower() in SECRET_CONFIG_KEYS:
            redacted[key] = "***"
        else:
            redacted[key] = value
    return redacted


class ChannelService(TableService):
    def __init__(self, client: SupabaseClient) -> None:
        super().__init__(client, "channels")

    def create_channel(self, payload: ChannelCreate) -> dict[str, Any]:
        return self.create(payload)

    def get_channel(self, channel_id: str) -> dict[str, Any]:
        return self.get(channel_id)

    def update_channel(self, channel_id: str, payload: ChannelUpdate) -> dict[str, Any]:
        return self.update(channel_id, payload)

    def to_public_channel(self, record: dict[str, Any]) -> ChannelPublic:
        safe_record = {**record, "config": redact_channel_config(record.get("config") or {})}
        return ChannelPublic.model_validate(safe_record)
