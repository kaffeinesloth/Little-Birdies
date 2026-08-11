from pydantic import BaseModel, Field, field_validator


class InboundMessageRequest(BaseModel):
    sender_id: str = Field(min_length=1, max_length=255)
    content: str = Field(min_length=1, max_length=4000)
    customer_name: str | None = Field(default=None, max_length=255)

    @field_validator("content")
    @classmethod
    def content_must_not_be_empty(cls, value: str) -> str:
        if not value.strip():
            raise ValueError("Message content cannot be empty")
        return value


class InboundMessageResponse(BaseModel):
    ticket: dict
    customer_message: dict
    bot_message: dict | None = None
    notifications: list[dict] = []
    action: str
    intent: str
