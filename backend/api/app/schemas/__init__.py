"""Pydantic schemas for API requests and responses."""

from app.schemas.channels import ChannelCreate, ChannelPublic, ChannelRead, ChannelUpdate
from app.schemas.common import (
    ChannelType,
    DocumentFileType,
    EmbeddingStatus,
    IntentType,
    SenderType,
    TicketStatus,
    UserRole,
    UserStatus,
)
from app.schemas.documents import DocumentCreate, DocumentRead, DocumentUpdate
from app.schemas.messages import HumanMessageCreate, HumanMessageResponse, MessageCreate, MessageRead, MessageUpdate
from app.schemas.notifications import NotificationCreate, NotificationRead, NotificationUpdate
from app.schemas.tickets import TicketAssign, TicketCreate, TicketListResponse, TicketRead, TicketUpdate
from app.schemas.users import PresenceUpdate, UserCreate, UserRead, UserUpdate
from app.schemas.webhooks import InboundMessageRequest, InboundMessageResponse

__all__ = [
    "ChannelCreate",
    "ChannelPublic",
    "ChannelRead",
    "ChannelType",
    "ChannelUpdate",
    "DocumentCreate",
    "DocumentFileType",
    "DocumentRead",
    "DocumentUpdate",
    "EmbeddingStatus",
    "IntentType",
    "InboundMessageRequest",
    "InboundMessageResponse",
    "HumanMessageCreate",
    "HumanMessageResponse",
    "MessageCreate",
    "MessageRead",
    "MessageUpdate",
    "NotificationCreate",
    "NotificationRead",
    "NotificationUpdate",
    "PresenceUpdate",
    "SenderType",
    "TicketCreate",
    "TicketAssign",
    "TicketListResponse",
    "TicketRead",
    "TicketStatus",
    "TicketUpdate",
    "UserCreate",
    "UserRead",
    "UserRole",
    "UserStatus",
    "UserUpdate",
]
