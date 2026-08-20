"""
agent/schemas.py — Pydantic models cho AI layer.

Đây là "ngôn ngữ chung" giữa các module:
  IntentClassifier → IntentResult
  AgentOrchestrator → ProcessResult
  ConversationManager → Conversation, Message
"""
from __future__ import annotations

from datetime import datetime
from enum import Enum
from typing import Any
from uuid import UUID

from pydantic import BaseModel, Field


# ─────────────────────────────────────────────────────────────────────────────
# Intent Classification
# ─────────────────────────────────────────────────────────────────────────────

class IntentType(str, Enum):
    GENERAL_FAQ    = "GENERAL_FAQ"     # Hỏi giá, lịch, chính sách, thông tin sp
    COMPLAINT      = "COMPLAINT"       # Khiếu nại về sp / dịch vụ
    ANGRY          = "ANGRY"           # Tin nhắn tức giận, xúc phạm
    ESCALATION_REQ = "ESCALATION_REQ"  # Chủ động yêu cầu gặp người thật
    GREETING       = "GREETING"        # Chào hỏi đơn thuần
    OUT_OF_SCOPE   = "OUT_OF_SCOPE"   # Ngoài phạm vi hỗ trợ


class IntentResult(BaseModel):
    intent: IntentType
    confidence: float = Field(ge=0.0, le=1.0, description="Confidence score [0, 1]")
    reasoning: str = Field(description="Giải thích ngắn gọn tại sao classify như vậy")
    detected_keywords: list[str] = Field(default_factory=list)
    urgency_level: int = Field(
        ge=1, le=3,
        description="1=thấp, 2=trung, 3=khẩn (ảnh hưởng priority của ticket)"
    )

    # Intents nào cần chuyển sang human ngay lập tức
    @property
    def requires_human(self) -> bool:
        return self.intent in {
            IntentType.COMPLAINT,
            IntentType.ANGRY,
            IntentType.ESCALATION_REQ,
        }


# ─────────────────────────────────────────────────────────────────────────────
# Conversation State Machine
# ─────────────────────────────────────────────────────────────────────────────

class ConvState(str, Enum):
    AI_HANDLING    = "AI_HANDLING"    # AI đang xử lý, chưa có human
    HUMAN_HANDLING = "HUMAN_HANDLING" # Đã handoff sang nhân viên thật
    RESOLVED       = "RESOLVED"       # Đã giải quyết xong


class MessageRole(str, Enum):
    USER      = "user"
    ASSISTANT = "assistant"
    SYSTEM    = "system"


class Message(BaseModel):
    id: str | UUID | None = None
    conversation_id: str | UUID | None = None
    role: MessageRole
    content: str
    intent: IntentType | None = None    # Chỉ có khi role=user
    confidence: float | None = None
    created_at: datetime = Field(default_factory=datetime.now)

    def to_history_dict(self) -> dict[str, str]:
        """Format để đưa vào LLM prompt."""
        return {"role": self.role.value, "content": self.content}


class Conversation(BaseModel):
    id: str | UUID
    tenant_id: str | UUID
    channel: str                          # "web" | "facebook" | "email"
    external_id: str | None = None        # FB sender_id, email address, etc.
    state: ConvState = ConvState.AI_HANDLING
    assigned_agent_id: str | UUID | None = None
    messages: list[Message] = Field(default_factory=list)
    created_at: datetime = Field(default_factory=datetime.now)
    updated_at: datetime = Field(default_factory=datetime.now)

    def recent_messages(self, n: int = 10) -> list[Message]:
        """Sliding window — tránh overflow context limit của LLM."""
        return self.messages[-n:]

    def to_history(self, n: int = 10) -> list[dict[str, str]]:
        """Dạng list[{role, content}] để pass vào classifier/generator."""
        return [m.to_history_dict() for m in self.recent_messages(n)]


# ─────────────────────────────────────────────────────────────────────────────
# Orchestrator I/O
# ─────────────────────────────────────────────────────────────────────────────

class OrchestratorAction(str, Enum):
    NONE        = "NONE"       # Chỉ reply, không action đặc biệt
    HANDOFF     = "HANDOFF"   # Chuyển sang human agent
    NOTIFY      = "NOTIFY"    # Gửi push notification (kèm HANDOFF)


class ProcessResult(BaseModel):
    """Kết quả trả về từ AgentOrchestrator.process()."""
    reply: str                              # Text gửi cho khách (rỗng nếu human đang handle)
    state: ConvState
    action: OrchestratorAction = OrchestratorAction.NONE
    ticket_id: str | None = None
    intent_result: IntentResult | None = None
    rag_confidence: str | None = None       # "high" | "medium" | "low" | None
    source_docs: list[str] = Field(default_factory=list)
    metadata: dict[str, Any] = Field(default_factory=dict)


# ─────────────────────────────────────────────────────────────────────────────
# API Request / Response models (dùng trong routers/)
# ─────────────────────────────────────────────────────────────────────────────

class ChatMessagePayload(BaseModel):
    tenant_id: str
    conversation_id: str
    message: str = Field(min_length=1, max_length=4000)
    channel: str = Field(default="web", pattern="^(web|facebook|email)$")


class ChatMessageResponse(BaseModel):
    reply: str
    state: ConvState
    ticket_id: str | None = None
    action: OrchestratorAction


class DocumentUploadResponse(BaseModel):
    doc_id: str
    status: str
    message: str


class HealthResponse(BaseModel):
    status: str = "ok"
    version: str = "0.1.0"
    provider: str = "fallback"
    model: str | None = None
    runtime_ready: bool = True
