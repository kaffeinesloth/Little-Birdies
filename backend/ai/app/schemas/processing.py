from pydantic import BaseModel, Field, field_validator

from app.schemas.common import IntentType


class ProcessMessageRequest(BaseModel):
    source: str = Field(min_length=1, max_length=32)
    sender_id: str = Field(min_length=1, max_length=255)
    content: str = Field(min_length=1, max_length=4000)

    @field_validator("content")
    @classmethod
    def content_must_not_be_empty(cls, value: str) -> str:
        if not value.strip():
            raise ValueError("content cannot be empty")
        return value


class ProcessMessageResponse(BaseModel):
    intent: IntentType
    confidence: float
    answer: str | None = None
    should_escalate: bool = False
    reason: str
    used_fallback: bool = False
