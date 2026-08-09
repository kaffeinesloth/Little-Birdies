from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from app.schemas.common import DocumentFileType, EmbeddingStatus


class DocumentBase(BaseModel):
    name: str
    file_url: str
    file_type: DocumentFileType
    embedding_status: EmbeddingStatus = EmbeddingStatus.PROCESSING
    chunk_count: int = Field(default=0, ge=0)
    uploaded_by: UUID | None = None


class DocumentCreate(DocumentBase):
    pass


class DocumentUpdate(BaseModel):
    name: str | None = None
    file_url: str | None = None
    file_type: DocumentFileType | None = None
    embedding_status: EmbeddingStatus | None = None
    chunk_count: int | None = Field(default=None, ge=0)


class DocumentRead(DocumentBase):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    created_at: datetime
    updated_at: datetime
