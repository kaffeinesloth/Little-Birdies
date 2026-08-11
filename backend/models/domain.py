from pydantic import BaseModel, Field
from typing import Optional, List, Any
from datetime import datetime
from uuid import UUID
from enum import Enum


# ============================================================
# Enums
# ============================================================

class TicketSource(str, Enum):
    web = "web"
    facebook = "facebook"
    email = "email"


class TicketStatus(str, Enum):
    open = "open"
    in_progress = "in_progress"
    pending = "pending"
    resolved = "resolved"


class TicketIntent(str, Enum):
    question = "question"
    complaint = "complaint"
    spam = "spam"


class SenderType(str, Enum):
    customer = "customer"
    bot = "bot"
    human = "human"


class UserRole(str, Enum):
    super_admin = "super_admin"
    agent = "agent"


class UserStatus(str, Enum):
    online = "online"
    offline = "offline"
    disabled = "disabled"


class EmbeddingStatus(str, Enum):
    processing = "processing"
    ready = "ready"
    error = "error"


class ChannelType(str, Enum):
    web = "web"
    facebook = "facebook"
    email = "email"


# ============================================================
# Response wrapper
# ============================================================

class MetaResponse(BaseModel):
    code: int
    message: str


class APIResponse(BaseModel):
    meta: MetaResponse
    data: Any = None


# ============================================================
# Ticket models
# ============================================================

class TicketCreate(BaseModel):
    """Dùng bởi AI bot khi tạo ticket mới (qua service role)."""
    customer_id: str
    customer_name: Optional[str] = None
    source: TicketSource
    intent: TicketIntent
    summary: Optional[str] = None


class TicketUpdate(BaseModel):
    """Agent hoặc super_admin cập nhật trạng thái ticket."""
    status: Optional[TicketStatus] = None
    assigned_to: Optional[UUID] = None


class TicketOut(BaseModel):
    id: UUID
    customer_id: str
    customer_name: Optional[str]
    source: TicketSource
    status: TicketStatus
    intent: Optional[TicketIntent]
    summary: Optional[str]
    assigned_to: Optional[UUID]
    created_at: datetime
    resolved_at: Optional[datetime]


# ============================================================
# Message models
# ============================================================

class MessageCreate(BaseModel):
    """Agent hoặc AI gửi tin nhắn reply cho khách."""
    ticket_id: UUID
    content: str = Field(..., min_length=1, max_length=4000)


class IncomingMessage(BaseModel):
    """
    Tin nhắn từ khách hàng gửi vào (qua chat widget hoặc webhook).
    Backend sẽ lưu vào DB rồi chuyển qua AI service xử lý.
    """
    customer_id: str
    customer_name: Optional[str] = None
    source: TicketSource
    content: str = Field(..., min_length=1)


class MessageOut(BaseModel):
    id: UUID
    ticket_id: UUID
    sender_type: SenderType
    sender_id: str
    content: str
    created_at: datetime


# ============================================================
# Document models
# ============================================================

class DocumentOut(BaseModel):
    id: UUID
    name: str
    file_url: str
    file_type: str
    embedding_status: EmbeddingStatus
    chunk_count: Optional[int]
    uploaded_by: UUID
    created_at: datetime


# ============================================================
# Channel models
# ============================================================

class ChannelUpdate(BaseModel):
    """super_admin cập nhật config kênh (token, API key, v.v.)."""
    config: dict
    is_active: bool = True


class ChannelOut(BaseModel):
    id: UUID
    type: ChannelType
    is_active: bool
    connected_at: Optional[datetime]
    # config ẩn đi trong response (chứa secret)


# ============================================================
# User models
# ============================================================

class UserCreate(BaseModel):
    """super_admin mời nhân viên mới."""
    email: str
    full_name: str
    role: UserRole = UserRole.agent


class UserStatusUpdate(BaseModel):
    status: UserStatus


class UserOut(BaseModel):
    id: UUID
    email: str
    full_name: str
    role: UserRole
    status: UserStatus
    avatar_url: Optional[str]
    created_at: datetime
    last_seen_at: Optional[datetime]


# ============================================================
# Dashboard / Stats
# ============================================================

class DashboardStats(BaseModel):
    total_tickets_today: int
    open_tickets: int
    resolved_tickets_today: int
    ai_handled_percent: float          # % ticket AI tự xử lý (không cần agent)
    avg_response_time_sec: Optional[float]
