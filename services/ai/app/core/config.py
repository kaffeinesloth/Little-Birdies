from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    app_name: str = "Smart Helpdesk AI Service"
    app_version: str = "0.1.0"
    app_env: str = "development"
    debug: bool = True
    cors_allowed_origins: str = "http://localhost:3000,http://127.0.0.1:3000"
    max_request_body_bytes: int = 10 * 1024 * 1024
    max_message_content_chars: int = 4000

    openai_api_key: str | None = None
    gemini_api_key: str | None = None
    embedding_model: str = "text-embedding-3-small"
    chroma_db_path: str = "./chroma"
    chroma_db_host: str | None = None
    rag_confidence_threshold: float = 0.72
    llm_timeout_seconds: float = 5.0

    @property
    def has_llm_provider(self) -> bool:
        return bool(self.openai_api_key or self.gemini_api_key)

    @property
    def cors_origins(self) -> list[str]:
        return [origin.strip() for origin in self.cors_allowed_origins.split(",") if origin.strip()]


@lru_cache
def get_settings() -> Settings:
    return Settings()
