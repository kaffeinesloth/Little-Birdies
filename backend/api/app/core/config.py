from functools import lru_cache

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    app_name: str = "Smart Helpdesk API"
    app_version: str = "0.1.0"
    app_env: str = "development"
    debug: bool = True
    local_mock_auth_enabled: bool = False
    local_mock_db_enabled: bool = True
    local_sqlite_db_path: str | None = None
    cors_allowed_origins: str = "http://localhost:3000,http://127.0.0.1:3000"
    max_request_body_bytes: int = 10_485_760
    max_document_upload_bytes: int = 10_485_760
    max_message_content_chars: int = 4_000
    public_endpoint_rate_limit: int = 60
    public_endpoint_rate_window_seconds: int = 60

    supabase_url: str | None = None
    supabase_anon_key: str | None = None
    supabase_service_role_key: str | None = None
    supabase_jwt_secret: str | None = None
    supabase_jwt_audience: str = "authenticated"
    supabase_jwt_issuer: str | None = None

    ai_service_url: str = "http://localhost:8001"

    facebook_app_secret: str | None = None
    facebook_page_access_token: str | None = None
    facebook_verify_token: str | None = None

    mailgun_api_key: str | None = None
    mailgun_domain: str | None = None
    mailgun_webhook_signing_key: str | None = None
    mailgun_from_email: str | None = None
    sendgrid_api_key: str | None = None
    sendgrid_webhook_public_key: str | None = None
    sendgrid_from_email: str | None = None
    outbound_email_provider: str = "mailgun"

    fcm_project_id: str | None = None
    fcm_service_account_json: str | None = Field(
        default=None,
        description="Raw Firebase service account JSON or a path, depending on deployment.",
    )

    @property
    def cors_origins(self) -> list[str]:
        return [origin.strip() for origin in self.cors_allowed_origins.split(",") if origin.strip()]


@lru_cache
def get_settings() -> Settings:
    return Settings()
