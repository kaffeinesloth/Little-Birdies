"""
tests/test_orchestrator.py — Unit tests AgentOrchestrator.

Mock tất cả dependencies: classifier, RAG, ticket service, notify service,
conversation manager và DB → test pure routing logic.
"""
from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock

import pytest

from agent.schemas import (
    ConvState, IntentResult, IntentType,
    MessageRole, OrchestratorAction,
)


# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────

def make_intent(
    intent: IntentType,
    confidence: float = 0.90,
    urgency: int = 1,
) -> IntentResult:
    return IntentResult(
        intent=intent,
        confidence=confidence,
        reasoning="test",
        detected_keywords=[],
        urgency_level=urgency,
    )


def make_conversation(state: ConvState = ConvState.AI_HANDLING, messages=None):
    conv = MagicMock()
    conv.state   = state
    conv.channel = "web"
    conv.messages = messages or []
    conv.to_history.return_value = [m for m in (messages or [])]
    return conv


def make_orchestrator(
    intent: IntentResult,
    conv_state: ConvState = ConvState.AI_HANDLING,
    rag_result: dict | None = None,
):
    from agent.orchestrator import AgentOrchestrator

    classifier  = MagicMock()
    classifier.classify = AsyncMock(return_value=intent)

    rag_pipeline = MagicMock()
    rag_pipeline.query = AsyncMock(return_value=rag_result or {
        "text": "Giá 250k bạn nhé!",
        "confidence": "high",
        "should_create_ticket": False,
        "source_docs": ["banggia.pdf"],
    })

    ticket_svc  = MagicMock()
    ticket_svc.create = AsyncMock(return_value={"id": "ticket-001"})

    notify_svc  = MagicMock()
    notify_svc.send_urgent = AsyncMock()

    conv        = make_conversation(state=conv_state)
    conv_mgr    = MagicMock()
    conv_mgr.get_or_create     = AsyncMock(return_value=conv)
    conv_mgr.add_message       = AsyncMock()
    conv_mgr.transition_to_human = AsyncMock()
    conv_mgr.mark_resolved     = AsyncMock()

    db = MagicMock()

    # Patch get_tenant_config
    import db.queries as q
    q.get_tenant_config = AsyncMock(return_value={"shop_name": "Test Shop"})

    return AgentOrchestrator(
        classifier=classifier,
        rag_pipeline=rag_pipeline,
        ticket_svc=ticket_svc,
        notify_svc=notify_svc,
        conv_mgr=conv_mgr,
        db=db,
    )


# ─────────────────────────────────────────────────────────────────────────────
# Tests — Routing
# ─────────────────────────────────────────────────────────────────────────────

class TestRouting:
    @pytest.mark.asyncio
    async def test_faq_returns_rag_reply(self):
        orch   = make_orchestrator(make_intent(IntentType.GENERAL_FAQ))
        result = await orch.process("t1", "conv-1", "Giá bao nhiêu?")

        assert result.reply == "Giá 250k bạn nhé!"
        assert result.state == ConvState.AI_HANDLING
        assert result.action == OrchestratorAction.NONE
        assert result.ticket_id is None

    @pytest.mark.asyncio
    async def test_complaint_creates_ticket_and_handoff(self):
        orch   = make_orchestrator(make_intent(IntentType.COMPLAINT, urgency=2))
        result = await orch.process("t1", "conv-1", "Hàng bị lỗi rồi!")

        assert result.state  == ConvState.HUMAN_HANDLING
        assert result.action == OrchestratorAction.HANDOFF
        assert result.ticket_id == "ticket-001"
        orch._ticket_svc.create.assert_called_once()
        orch._notify_svc.send_urgent.assert_called_once()

    @pytest.mark.asyncio
    async def test_angry_creates_urgent_ticket(self):
        orch   = make_orchestrator(make_intent(IntentType.ANGRY, urgency=3))
        result = await orch.process("t1", "conv-1", "LỪA ĐẢO!!!")

        assert result.state  == ConvState.HUMAN_HANDLING
        assert result.action == OrchestratorAction.HANDOFF
        # Verify urgency=3 được pass vào ticket
        call_kwargs = orch._ticket_svc.create.call_args.kwargs
        assert call_kwargs["urgency"] == 3

    @pytest.mark.asyncio
    async def test_escalation_req_handoff(self):
        orch   = make_orchestrator(make_intent(IntentType.ESCALATION_REQ, urgency=2))
        result = await orch.process("t1", "conv-1", "Cho tôi gặp manager!")

        assert result.state  == ConvState.HUMAN_HANDLING
        assert result.action == OrchestratorAction.HANDOFF

    @pytest.mark.asyncio
    async def test_greeting_returns_canned_response(self):
        orch   = make_orchestrator(make_intent(IntentType.GREETING))
        result = await orch.process("t1", "conv-1", "Xin chào shop!")

        assert result.state  == ConvState.AI_HANDLING
        assert result.action == OrchestratorAction.NONE
        assert result.reply  != ""
        orch._ticket_svc.create.assert_not_called()

    @pytest.mark.asyncio
    async def test_out_of_scope_returns_canned_response(self):
        orch   = make_orchestrator(make_intent(IntentType.OUT_OF_SCOPE))
        result = await orch.process("t1", "conv-1", "Thời tiết hôm nay thế nào?")

        assert result.state == ConvState.AI_HANDLING
        assert "sản phẩm" in result.reply.lower() or "hỗ trợ" in result.reply.lower()

    @pytest.mark.asyncio
    async def test_human_handling_no_auto_reply(self):
        """Khi conv đang ở HUMAN_HANDLING → không reply tự động."""
        orch   = make_orchestrator(
            make_intent(IntentType.GENERAL_FAQ),
            conv_state=ConvState.HUMAN_HANDLING,
        )
        result = await orch.process("t1", "conv-1", "Tin nhắn khi human đang xử lý")

        assert result.reply == ""
        assert result.state == ConvState.HUMAN_HANDLING
        orch._classifier.classify.assert_not_called()   # Không cần classify
        orch._rag.query.assert_not_called()              # Không cần RAG

    @pytest.mark.asyncio
    async def test_low_rag_confidence_escalates_to_human(self):
        """Khi RAG không tìm thấy context → tạo ticket low-priority."""
        orch = make_orchestrator(
            make_intent(IntentType.GENERAL_FAQ),
            rag_result={
                "text": "...",
                "confidence": "low",
                "should_create_ticket": True,
                "source_docs": [],
            },
        )
        result = await orch.process("t1", "conv-1", "Câu hỏi không có trong tài liệu?")

        assert result.state  == ConvState.HUMAN_HANDLING
        assert result.action == OrchestratorAction.HANDOFF
        orch._ticket_svc.create.assert_called_once()
        # Urgency phải là 1 (low priority)
        call_kwargs = orch._ticket_svc.create.call_args.kwargs
        assert call_kwargs["urgency"] == 1


# ─────────────────────────────────────────────────────────────────────────────
# Tests — Message saving
# ─────────────────────────────────────────────────────────────────────────────

class TestMessageSaving:
    @pytest.mark.asyncio
    async def test_faq_saves_user_and_assistant_messages(self):
        orch = make_orchestrator(make_intent(IntentType.GENERAL_FAQ))
        await orch.process("t1", "conv-1", "Giá bao nhiêu?")

        calls = orch._conv_mgr.add_message.call_args_list
        roles = [c.args[1] for c in calls]
        assert MessageRole.USER      in roles
        assert MessageRole.ASSISTANT in roles

    @pytest.mark.asyncio
    async def test_complaint_saves_ack_message(self):
        orch = make_orchestrator(make_intent(IntentType.COMPLAINT, urgency=3))
        result = await orch.process("t1", "conv-1", "Hàng lỗi!")

        # Ack reply phải được lưu
        calls = orch._conv_mgr.add_message.call_args_list
        assistant_calls = [c for c in calls if c.args[1] == MessageRole.ASSISTANT]
        assert len(assistant_calls) == 1
        assert assistant_calls[0].args[2] == result.reply

    @pytest.mark.asyncio
    async def test_human_handling_saves_only_user_message(self):
        orch = make_orchestrator(
            make_intent(IntentType.GENERAL_FAQ),
            conv_state=ConvState.HUMAN_HANDLING,
        )
        await orch.process("t1", "conv-1", "Tin nhắn của khách")

        # Chỉ lưu user message, không lưu assistant
        calls = orch._conv_mgr.add_message.call_args_list
        assert len(calls) == 1
        assert calls[0].args[1] == MessageRole.USER


# ─────────────────────────────────────────────────────────────────────────────
# Tests — History summary
# ─────────────────────────────────────────────────────────────────────────────

class TestHistorySummary:
    def test_summarize_empty_history(self):
        from agent.orchestrator import AgentOrchestrator
        result = AgentOrchestrator._summarize_history([])
        assert result == ""

    def test_summarize_truncates_long_history(self):
        from agent.orchestrator import AgentOrchestrator
        history = [
            {"role": "user",      "content": "Tin nhắn " * 100},
            {"role": "assistant", "content": "Trả lời " * 100},
        ] * 5
        result = AgentOrchestrator._summarize_history(history, max_chars=500)
        assert len(result) <= 500

    def test_summarize_labels_roles(self):
        from agent.orchestrator import AgentOrchestrator
        history = [
            {"role": "user",      "content": "Hỏi về giá"},
            {"role": "assistant", "content": "Giá 250k"},
        ]
        result = AgentOrchestrator._summarize_history(history)
        assert "Khách" in result
        assert "Bot"   in result
