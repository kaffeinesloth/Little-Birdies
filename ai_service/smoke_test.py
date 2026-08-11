"""
smoke_test.py — Kiểm tra nhanh toàn bộ pipeline với mock (không cần API key).

Chạy: python smoke_test.py
"""
import asyncio
import json
from unittest.mock import AsyncMock, MagicMock, patch


def make_gemini_response(data: dict):
    mock = MagicMock()
    mock.text = json.dumps(data)
    return mock


async def test_intent_classifier():
    print("\n[1] IntentClassifier...")
    from agent.intent_classifier import IntentClassifier

    with patch("agent.intent_classifier.genai.Client"):
        clf = IntentClassifier(api_key="fake")

    clf._client.aio.models.generate_content = AsyncMock(
        return_value=make_gemini_response({
            "intent": "GENERAL_FAQ",
            "confidence": 0.95,
            "reasoning": "Hỏi về giá",
            "detected_keywords": ["giá"],
            "urgency_level": 1,
        })
    )
    result = await clf.classify("Giá sản phẩm bao nhiêu?")
    assert result.intent.value == "GENERAL_FAQ"
    assert result.requires_human is False
    print(f"   OK → intent={result.intent.value}, confidence={result.confidence}")


async def test_rag_pipeline():
    print("\n[2] RAG Pipeline...")
    from rag.retriever import Retriever
    from rag.generator import ResponseGenerator
    from rag.pipeline  import RAGPipeline

    # Mock VectorStore
    vs = MagicMock()
    vs.query.return_value = [
        {"text": "Giá áo polo là 250.000đ", "metadata": {"doc_id": "1", "doc_name": "banggia.pdf"}, "similarity": 0.88}
    ]
    retriever = Retriever(vector_store=vs)

    # Mock Generator
    with patch("rag.generator.genai.Client"):
        generator = ResponseGenerator(api_key="fake")

    mock_resp = MagicMock()
    mock_resp.text = "Giá áo polo là 250k bạn nhé! Bạn cần hỗ trợ thêm không ạ?"
    generator._client.aio.models.generate_content = AsyncMock(return_value=mock_resp)

    pipeline = RAGPipeline(retriever=retriever, generator=generator)
    result   = await pipeline.query(
        tenant_id="shop-001",
        tenant_config={"shop_name": "Shop Test"},
        question="Giá áo polo bao nhiêu?",
        history=[],
    )
    assert "250k" in result["text"]
    assert result["should_create_ticket"] is False
    print(f"   OK → reply='{result['text'][:60]}...'")
    print(f"        confidence={result['confidence']}, source={result['source_docs']}")


async def test_orchestrator_faq():
    print("\n[3] Orchestrator — FAQ flow...")
    from agent.orchestrator import AgentOrchestrator
    from agent.schemas      import ConvState, IntentType, IntentResult
    from agent.conversation import ConversationManager
    from services.ticket    import TicketService
    from services.notify    import NotifyService
    import db.queries as q

    # Mock tất cả dependencies
    conv = MagicMock()
    conv.state   = ConvState.AI_HANDLING
    conv.channel = "web"
    conv.to_history.return_value = []

    conv_mgr = MagicMock()
    conv_mgr.get_or_create = AsyncMock(return_value=conv)
    conv_mgr.add_message   = AsyncMock()
    conv_mgr.transition_to_human = AsyncMock()

    classifier = MagicMock()
    classifier.classify = AsyncMock(return_value=IntentResult(
        intent=IntentType.GENERAL_FAQ,
        confidence=0.92, reasoning="FAQ", detected_keywords=[], urgency_level=1,
    ))

    rag = MagicMock()
    rag.query = AsyncMock(return_value={
        "text": "Giá 250k bạn nhé!",
        "confidence": "high",
        "should_create_ticket": False,
        "source_docs": ["banggia.pdf"],
    })

    ticket_svc = MagicMock(); ticket_svc.create = AsyncMock(return_value={"id": "t-001"})
    notify_svc = MagicMock(); notify_svc.send_urgent = AsyncMock()

    q.get_tenant_config = AsyncMock(return_value={"shop_name": "Test Shop"})

    orch   = AgentOrchestrator(classifier, rag, ticket_svc, notify_svc, conv_mgr, db=MagicMock())
    result = await orch.process("shop-001", "conv-abc", "Giá bao nhiêu?")

    assert result.reply  == "Giá 250k bạn nhé!"
    assert result.state  == ConvState.AI_HANDLING
    assert result.ticket_id is None
    print(f"   OK → reply='{result.reply}', state={result.state.value}")


async def test_orchestrator_complaint():
    print("\n[4] Orchestrator — Complaint flow...")
    from agent.orchestrator import AgentOrchestrator
    from agent.schemas      import ConvState, IntentType, IntentResult
    import db.queries as q

    conv = MagicMock()
    conv.state   = ConvState.AI_HANDLING
    conv.channel = "web"
    conv.to_history.return_value = []

    conv_mgr   = MagicMock()
    conv_mgr.get_or_create       = AsyncMock(return_value=conv)
    conv_mgr.add_message         = AsyncMock()
    conv_mgr.transition_to_human = AsyncMock()

    classifier = MagicMock()
    classifier.classify = AsyncMock(return_value=IntentResult(
        intent=IntentType.ANGRY,
        confidence=0.97, reasoning="Angry", detected_keywords=["LỪA ĐẢO"], urgency_level=3,
    ))

    ticket_svc = MagicMock(); ticket_svc.create = AsyncMock(return_value={"id": "ticket-999"})
    notify_svc = MagicMock(); notify_svc.send_urgent = AsyncMock()
    q.get_tenant_config = AsyncMock(return_value={"shop_name": "Test Shop"})

    orch   = AgentOrchestrator(classifier, MagicMock(), ticket_svc, notify_svc, conv_mgr, db=MagicMock())
    result = await orch.process("shop-001", "conv-xyz", "ĐỒ LỪA ĐẢO!!!")

    assert result.state     == ConvState.HUMAN_HANDLING
    assert result.ticket_id == "ticket-999"
    ticket_svc.create.assert_called_once()
    notify_svc.send_urgent.assert_called_once()
    print(f"   OK → state={result.state.value}, ticket={result.ticket_id}")
    print(f"        reply='{result.reply[:80]}'")


async def main():
    print("=" * 55)
    print("  Smart Helpdesk — Smoke Test (no API key needed)")
    print("=" * 55)

    await test_intent_classifier()
    await test_rag_pipeline()
    await test_orchestrator_faq()
    await test_orchestrator_complaint()

    print("\n" + "=" * 55)
    print("  Tất cả 4 test PASSED ✓")
    print("  Chạy full unit tests: python -m pytest tests/ -v")
    print("=" * 55)


if __name__ == "__main__":
    asyncio.run(main())