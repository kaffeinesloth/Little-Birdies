from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from app.schemas.common import ChannelType, IntentType, TicketStatus


class TicketBase(BaseModel):
    customer_id: str = Field(min_length=1, max_length=255)
    customer_name: str | None = Field(default=None, max_length=255)
    source: ChannelType
    status: TicketStatus = TicketStatus.OPEN
    intent: IntentType = IntentType.QUESTION
    summary: str | None = Field(default=None, max_length=500)
    assigned_to: UUID | None = None
    resolved_at: datetime | None = None


class TicketCreate(TicketBase):
    pass


class TicketUpdate(BaseModel):
    customer_name: str | None = Field(default=None, max_length=255)
    status: TicketStatus | None = None
    intent: IntentType | None = None
    summary: str | None = Field(default=None, max_length=500)
    assigned_to: UUID | None = None
    resolved_at: datetime | None = None


class TicketAssign(BaseModel):
    assigned_to: UUID


class TicketListResponse(BaseModel):
    items: list[dict]
    limit: int
    offset: int
    count: int


class TicketRead(TicketBase):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    created_at: datetime
    updated_at: datetime
