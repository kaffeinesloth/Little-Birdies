from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.schemas.common import SenderType


class MessageBase(BaseModel):
    ticket_id: UUID
    sender_type: SenderType
    sender_id: str
    content: str = Field(min_length=1, max_length=4000)

    @field_validator("content")
    @classmethod
    def content_must_not_be_empty(cls, value: str) -> str:
        if not value.strip():
            raise ValueError("Message content cannot be empty")
        return value


class MessageCreate(MessageBase):
    pass


class HumanMessageCreate(BaseModel):
    content: str = Field(min_length=1, max_length=4000)

    @field_validator("content")
    @classmethod
    def content_must_not_be_empty(cls, value: str) -> str:
        if not value.strip():
            raise ValueError("Message content cannot be empty")
        return value


class HumanMessageResponse(BaseModel):
    message: dict
    outbound: dict


class MessageUpdate(BaseModel):
    content: str | None = Field(default=None, max_length=4000)

    @field_validator("content")
    @classmethod
    def content_must_not_be_empty(cls, value: str | None) -> str | None:
        if value is not None and not value.strip():
            raise ValueError("Message content cannot be empty")
        return value


class MessageRead(MessageBase):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    created_at: datetime
    updated_at: datetime
