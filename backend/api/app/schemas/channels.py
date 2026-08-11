from datetime import datetime
from typing import Any
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from app.schemas.common import ChannelType


class ChannelBase(BaseModel):
    type: ChannelType
    config: dict[str, Any] = Field(default_factory=dict)
    is_active: bool = False
    connected_at: datetime | None = None


class ChannelCreate(ChannelBase):
    pass


class ChannelUpdate(BaseModel):
    config: dict[str, Any] | None = None
    is_active: bool | None = None
    connected_at: datetime | None = None


class ChannelRead(ChannelBase):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    created_at: datetime
    updated_at: datetime


class ChannelPublic(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    type: ChannelType
    config: dict[str, Any]
    is_active: bool
    connected_at: datetime | None = None
    created_at: datetime
    updated_at: datetime
