"""
config.py — Tất cả settings đọc từ .env file.

Copy .env.example thành .env và điền giá trị thực trước khi chạy.
"""
from functools import lru_cache
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    backend_url: str = "http://backend:8000"

    # ── Google AI ──────────────────────────────────────────────────
    google_api_key: str = ""

    # Model names — dùng Flash cho classification (rẻ/nhanh),
    # Pro cho RAG generation (cần reasoning tốt hơn)
    intent_model: str = "gemini-3.6-flash"      # Fast + cheap cho classification
    rag_model: str = "gemini-3.6-flash"          # LLM reasoning cho RAG
    embedding_model: str = "text-embedding-004"  # 768-dim, multilingual

    # ── Supabase ───────────────────────────────────────────────────
    supabase_url: str = ""
    supabase_anon_key: str = ""
    supabase_service_key: str = ""       # Dùng cho server-side operations

    # ── ChromaDB ───────────────────────────────────────────────────
    chroma_persist_dir: str = "./chroma_db"

    # ── Firebase FCM ───────────────────────────────────────────────
    fcm_credentials_path: str = ""       # Path đến service account JSON

    # ── App ────────────────────────────────────────────────────────
    app_name: str = "Smart Helpdesk API"
    debug: bool = False
    api_secret_key: str = "change-me-in-production"

    # ── RAG hyperparameters ────────────────────────────────────────
    chunk_size: int = 512
    chunk_overlap: int = 64
    retrieval_top_k: int = 5
    similarity_threshold: float = 0.35  # Phù hợp với tiếng Việt và local ONNX embeddings

    # ── Intent Classification ──────────────────────────────────────
    intent_confidence_threshold: float = 0.60  # FAQ dưới mức này → handoff


@lru_cache
def get_settings() -> Settings:
    return Settings()


# Export singleton
settings = get_settings()
