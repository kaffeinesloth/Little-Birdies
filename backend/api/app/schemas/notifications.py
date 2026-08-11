from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict


class NotificationBase(BaseModel):
    ticket_id: UUID
    recipient_id: UUID
    title: str
    body: str
    is_read: bool = False
    sent_at: datetime | None = None


class NotificationCreate(NotificationBase):
    pass


class NotificationUpdate(BaseModel):
    title: str | None = None
    body: str | None = None
    is_read: bool | None = None
    sent_at: datetime | None = None


class NotificationRead(NotificationBase):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    created_at: datetime
    updated_at: datetime
