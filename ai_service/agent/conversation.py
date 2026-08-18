"""
agent/conversation.py — Quản lý conversation state + message history (Supabase).

Conversation lifecycle:
  AI_HANDLING → (complaint detected) → HUMAN_HANDLING → RESOLVED

History: lưu vào DB, lấy N messages gần nhất để inject vào LLM prompt.
"""
from __future__ import annotations

import logging
from uuid import uuid4

from agent.schemas import ConvState, Conversation, Message, MessageRole
import db.queries as q

logger = logging.getLogger(__name__)


class ConversationManager:
    def __init__(self, db):
        self._db = db

    # ── Get or create ─────────────────────────────────────────────────────────

    async def get_or_create(
        self,
        conversation_id: str,
        tenant_id:       str,
        channel:         str,
        external_id:     str | None = None,
    ) -> Conversation:
        """
        Lấy conversation nếu đã tồn tại, tạo mới nếu chưa có.
        Cũng load messages gần nhất (10 messages) vào object.
        """
        raw = await q.get_conversation(self._db, conversation_id)

        if raw:
            messages = await q.get_recent_messages(
                self._db, conversation_id, limit=10
            )
            return Conversation(
                id=raw["id"],
                tenant_id=raw["tenant_id"],
                channel=raw["channel"],
                external_id=raw.get("external_id"),
                state=ConvState(raw["state"]),
                assigned_agent_id=raw.get("assigned_agent_id"),
                messages=[
                    Message(
                        role=MessageRole(m["role"]),
                        content=m["content"],
                    )
                    for m in messages
                ],
            )

        # Tạo mới
        created = await q.create_conversation(
            self._db,
            conversation_id=conversation_id,
            tenant_id=tenant_id,
            channel=channel,
            external_id=external_id,
        )
        logger.info(
            "New conversation created: id=%s tenant=%s channel=%s",
            conversation_id, tenant_id, channel,
        )
        return Conversation(
            id=created["id"],
            tenant_id=created["tenant_id"],
            channel=created["channel"],
            state=ConvState.AI_HANDLING,
            messages=[],
        )

    # ── Message ───────────────────────────────────────────────────────────────

    async def add_message(
        self,
        conversation_id: str,
        role:            MessageRole,
        content:         str,
        intent:          str | None = None,
        confidence:      float | None = None,
    ) -> None:
        await q.add_message(
            self._db,
            conversation_id=conversation_id,
            role=role.value,
            content=content,
            intent=intent,
            confidence=confidence,
        )

    # ── State transitions ─────────────────────────────────────────────────────

    async def transition_to_human(
        self,
        conversation_id: str,
        agent_id:        str | None = None,
    ) -> None:
        await q.update_conversation_state(
            self._db,
            conversation_id=conversation_id,
            state=ConvState.HUMAN_HANDLING.value,
            agent_id=agent_id,
        )
        logger.info("Conversation %s → HUMAN_HANDLING", conversation_id)

    async def mark_resolved(self, conversation_id: str) -> None:
        await q.update_conversation_state(
            self._db,
            conversation_id=conversation_id,
            state=ConvState.RESOLVED.value,
        )
        logger.info("Conversation %s → RESOLVED", conversation_id)
