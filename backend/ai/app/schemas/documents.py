from typing import Any

from pydantic import BaseModel, Field, field_validator

from app.schemas.common import DocumentFileType, EmbeddingStatus


MAX_DOCUMENT_BYTES = 10 * 1024 * 1024


class DocumentProcessRequest(BaseModel):
    document_id: str
    file_url: str
    file_type: DocumentFileType
    file_name: str | None = None
    file_size_bytes: int = Field(ge=0, le=MAX_DOCUMENT_BYTES)

    @field_validator("file_url")
    @classmethod
    def file_url_must_not_be_empty(cls, value: str) -> str:
        if not value.strip():
            raise ValueError("file_url cannot be empty")
        return value


class DocumentProcessResponse(BaseModel):
    document_id: str
    embedding_status: EmbeddingStatus
    chunk_count: int = Field(default=0, ge=0)
    reason: str | None = None
    used_fallback: bool = False
    chunks: list[dict[str, Any]] = Field(default_factory=list)
