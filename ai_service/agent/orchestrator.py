"""
agent/orchestrator.py — Entry point cho mọi tin nhắn vào hệ thống.

Flow:
  message → check state → classify intent → route:
    ├── HUMAN_HANDLING   → forward only (không reply tự động)
    ├── COMPLAINT/ANGRY  → create ticket → push notify → ack reply
    ├── ESCALATION_REQ   → create ticket → push notify → ack reply
    ├── GREETING         → canned response
    ├── OUT_OF_SCOPE     → canned response
    └── GENERAL_FAQ      → RAG pipeline → generate response
                              └── low confidence → create ticket (low priority)
"""
from __future__ import annotations

import logging

from agent.conversation    import ConversationManager
from agent.intent_classifier import IntentClassifier
from agent.schemas         import (
    ConvState, IntentResult, IntentType,
    MessageRole, OrchestratorAction, ProcessResult,
)
from rag.pipeline          import RAGPipeline
from services.ticket       import TicketService
from services.notify       import NotifyService
import db.queries as q

logger = logging.getLogger(__name__)

# ── Canned responses ─────────────────────────────────────────────────────────

_GREETING_REPLY = "Xin chào! Mình có thể giúp gì cho bạn hôm nay? 😊"

_OUT_OF_SCOPE_REPLY = (
    "Xin lỗi, mình chỉ có thể hỗ trợ các vấn đề liên quan đến sản phẩm "
    "và dịch vụ của shop. Bạn có câu hỏi nào khác không ạ?"
)

_COMPLAINT_ACK = {
    3: (
        "Mình rất xin lỗi về sự bất tiện này! 🙏 Mình đã chuyển ngay đến nhân viên "
        "phụ trách và họ sẽ liên hệ với bạn trong vài phút. "
        "Bạn vui lòng chờ mình một chút nhé!"
    ),
    2: (
        "Cảm ơn bạn đã phản hồi! Mình đã ghi nhận và chuyển đến nhân viên hỗ trợ ngay. "
        "Thường trong 5–10 phút sẽ có người liên hệ lại với bạn. 😊"
    ),
    1: (
        "Cảm ơn bạn đã liên hệ! Mình cần chuyển câu hỏi này đến bộ phận chuyên trách "
        "để hỗ trợ bạn tốt hơn. Bạn vui lòng chờ trong giây lát nhé!"
    ),
}


class AgentOrchestrator:
    """
    Điều phối toàn bộ AI pipeline cho 1 tin nhắn vào.

    Inject qua FastAPI Depends() — xem dependencies.py.
    """

    def __init__(
        self,
        classifier:   IntentClassifier,
        rag_pipeline: RAGPipeline,
        ticket_svc:   TicketService,
        notify_svc:   NotifyService,
        conv_mgr:     ConversationManager,
        db,
    ):
        self._classifier   = classifier
        self._rag          = rag_pipeline
        self._ticket_svc   = ticket_svc
        self._notify_svc   = notify_svc
        self._conv_mgr     = conv_mgr
        self._db           = db

    # ── Main entry point ─────────────────────────────────────────────────────

    async def process(
        self,
        tenant_id:       str,
        conversation_id: str,
        message:         str,
        channel:         str = "web",
        external_id:     str | None = None,
    ) -> ProcessResult:
        """
        Xử lý 1 tin nhắn từ khách hàng.

        Returns ProcessResult với reply text và action cần thực hiện.
        """

        # 1. Load / tạo conversation
        conv = await self._conv_mgr.get_or_create(
            conversation_id=conversation_id,
            tenant_id=tenant_id,
            channel=channel,
            external_id=external_id,
        )

        # 2. Nếu human đang xử lý → chỉ lưu message, không reply tự động
        if conv.state == ConvState.HUMAN_HANDLING:
            await self._conv_mgr.add_message(
                conversation_id, MessageRole.USER, message
            )
            logger.debug(
                "Human handling conv=%s — message saved, no auto-reply",
                conversation_id,
            )
            return ProcessResult(
                reply="",
                state=ConvState.HUMAN_HANDLING,
                action=OrchestratorAction.NONE,
            )

        # 3. Classify intent
        intent_result: IntentResult = await self._classifier.classify(
            message=message,
            recent_history=conv.to_history(n=6),
        )
        logger.info(
            "Intent: %s (%.2f) conv=%s",
            intent_result.intent, intent_result.confidence, conversation_id,
        )

        # 4. Route theo intent
        if intent_result.requires_human:
            return await self._handle_complaint(
                tenant_id, conversation_id, message, conv, intent_result, channel
            )

        if intent_result.intent == IntentType.GREETING:
            return await self._handle_canned(
                conversation_id, message, intent_result, _GREETING_REPLY
            )

        if intent_result.intent == IntentType.OUT_OF_SCOPE:
            return await self._handle_canned(
                conversation_id, message, intent_result, _OUT_OF_SCOPE_REPLY
            )

        # GENERAL_FAQ → RAG
        return await self._handle_faq(
            tenant_id, conversation_id, message, conv, intent_result
        )

    # ── Route handlers ───────────────────────────────────────────────────────

    async def _handle_complaint(
        self,
        tenant_id:       str,
        conversation_id: str,
        message:         str,
        conv,
        intent_result:   IntentResult,
        channel:         str,
    ) -> ProcessResult:
        """Tạo ticket + push notify + reply ack."""

        # Tóm tắt context cho staff
        context_summary = self._summarize_history(conv.to_history())

        # Tạo ticket
        ticket = await self._ticket_svc.create(
            tenant_id=tenant_id,
            conversation_id=conversation_id,
            channel=channel,
            intent=intent_result.intent.value,
            urgency=intent_result.urgency_level,
            customer_message=message,
            context_summary=context_summary,
        )

        # Push notification cho staff
        await self._notify_svc.send_urgent(
            tenant_id=tenant_id,
            ticket_id=ticket["id"],
            urgency=intent_result.urgency_level,
            preview=message,
        )

        # Chuyển conversation state → HUMAN_HANDLING
        await self._conv_mgr.transition_to_human(conversation_id)

        # Lưu messages
        await self._conv_mgr.add_message(
            conversation_id, MessageRole.USER, message,
            intent=intent_result.intent.value,
            confidence=intent_result.confidence,
        )
        ack = _COMPLAINT_ACK.get(intent_result.urgency_level, _COMPLAINT_ACK[1])
        await self._conv_mgr.add_message(
            conversation_id, MessageRole.ASSISTANT, ack
        )

        return ProcessResult(
            reply=ack,
            state=ConvState.HUMAN_HANDLING,
            action=OrchestratorAction.HANDOFF,
            ticket_id=ticket["id"],
            intent_result=intent_result,
        )

    async def _handle_faq(
        self,
        tenant_id:       str,
        conversation_id: str,
        message:         str,
        conv,
        intent_result:   IntentResult,
    ) -> ProcessResult:
        """RAG pipeline → generate response."""

        # Lấy tenant config (shop_name, persona, ...)
        tenant_config = await q.get_tenant_config(self._db, tenant_id)

        # RAG query
        rag_result = await self._rag.query(
            tenant_id=tenant_id,
            tenant_config=tenant_config,
            question=message,
            history=conv.to_history(),
        )

        # Nếu RAG confidence thấp → tạo ticket low-priority + handoff
        if rag_result["should_create_ticket"]:
            return await self._handle_complaint(
                tenant_id=tenant_id,
                conversation_id=conversation_id,
                message=message,
                conv=conv,
                intent_result=IntentResult(
                    intent=IntentType.GENERAL_FAQ,
                    confidence=0.0,
                    reasoning="Low RAG confidence — escalate to human",
                    detected_keywords=[],
                    urgency_level=1,
                ),
                channel=conv.channel,
            )

        # Lưu messages vào DB
        await self._conv_mgr.add_message(
            conversation_id, MessageRole.USER, message,
            intent=intent_result.intent.value,
            confidence=intent_result.confidence,
        )
        await self._conv_mgr.add_message(
            conversation_id, MessageRole.ASSISTANT, rag_result["text"]
        )

        return ProcessResult(
            reply=rag_result["text"],
            state=ConvState.AI_HANDLING,
            action=OrchestratorAction.NONE,
            intent_result=intent_result,
            rag_confidence=rag_result["confidence"],
            source_docs=rag_result["source_docs"],
        )

    async def _handle_canned(
        self,
        conversation_id: str,
        message:         str,
        intent_result:   IntentResult,
        reply_text:      str,
    ) -> ProcessResult:
        """Trả lời cố định, không cần RAG."""
        await self._conv_mgr.add_message(
            conversation_id, MessageRole.USER, message,
            intent=intent_result.intent.value,
            confidence=intent_result.confidence,
        )
        await self._conv_mgr.add_message(
            conversation_id, MessageRole.ASSISTANT, reply_text
        )
        return ProcessResult(
            reply=reply_text,
            state=ConvState.AI_HANDLING,
            intent_result=intent_result,
        )

    # ── Helpers ──────────────────────────────────────────────────────────────

    @staticmethod
    def _summarize_history(history: list[dict], max_chars: int = 500) -> str:
        """Tóm tắt lịch sử để show cho staff trong ticket."""
        if not history:
            return ""
        lines = []
        for msg in history[-6:]:
            label = "Khách" if msg["role"] == "user" else "Bot"
            lines.append(f"{label}: {msg['content'][:200]}")
        summary = "\n".join(lines)
        return summary[:max_chars]
