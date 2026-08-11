from pydantic import BaseModel, Field, field_validator

from app.schemas.common import IntentType


class ClassificationRequest(BaseModel):
    message_text: str = Field(min_length=1, max_length=4000)

    @field_validator("message_text")
    @classmethod
    def message_text_must_not_be_empty(cls, value: str) -> str:
        if not value.strip():
            raise ValueError("message_text cannot be empty")
        return value


class ClassificationResponse(BaseModel):
    intent: IntentType
    confidence: float
    reason: str
    used_fallback: bool = False
