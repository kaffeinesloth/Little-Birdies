from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict

from app.schemas.common import UserRole, UserStatus


class UserBase(BaseModel):
    email: str
    full_name: str
    role: UserRole = UserRole.AGENT
    status: UserStatus = UserStatus.OFFLINE
    avatar_url: str | None = None
    last_seen_at: datetime | None = None


class UserCreate(UserBase):
    id: UUID


class UserUpdate(BaseModel):
    email: str | None = None
    full_name: str | None = None
    role: UserRole | None = None
    status: UserStatus | None = None
    avatar_url: str | None = None
    last_seen_at: datetime | None = None


class PresenceUpdate(BaseModel):
    status: UserStatus


class UserRead(UserBase):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    created_at: datetime
    updated_at: datetime
