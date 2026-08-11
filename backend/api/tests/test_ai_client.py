import httpx
import pytest

from app.core.config import Settings
from app.schemas.common import IntentType
from app.services.ai_client import AIProcessingError, HTTPAIClient


def response(payload: dict, status_code: int = 200) -> httpx.Response:
    return httpx.Response(
        status_code=status_code,
        json=payload,
        request=httpx.Request("POST", "http://ai.test"),
    )


def test_ai_client_calls_classify_endpoint(monkeypatch: pytest.MonkeyPatch) -> None:
    calls = []

    def fake_post(url: str, json: dict, timeout: float) -> httpx.Response:
        calls.append((url, json, timeout))
        return response({"intent": "complaint", "confidence": 0.9, "reason": "late order"})

    monkeypatch.setattr(httpx, "post", fake_post)

    result = HTTPAIClient(Settings(ai_service_url="http://ai.test"), timeout_seconds=2).classify(
        "My order is late"
    )

    assert result.intent == IntentType.COMPLAINT
    assert calls == [("http://ai.test/classify", {"message_text": "My order is late"}, 2)]


def test_ai_client_classifier_timeout_defaults_to_question_and_continues_rag(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    calls = []

    def fake_post(url: str, json: dict, timeout: float) -> httpx.Response:
        calls.append(url)
        if url.endswith("/classify"):
            raise httpx.TimeoutException("classifier timeout")
        return response(
            {
                "answer": "Warranty lasts 12 months.",
                "confidence": 0.82,
                "should_escalate": False,
                "citations": [{"document_id": "doc-1"}],
            }
        )

    monkeypatch.setattr(httpx, "post", fake_post)

    result = HTTPAIClient(Settings(ai_service_url="http://ai.test")).process_message(
        source="web",
        sender_id="customer-1",
        content="What is the warranty?",
    )

    assert calls == ["http://ai.test/classify", "http://ai.test/rag/answer"]
    assert result.intent == IntentType.QUESTION
    assert result.answer == "Warranty lasts 12 months."
    assert result.should_escalate is False
    assert result.citations == [{"document_id": "doc-1"}]


def test_ai_client_complete_processing_failure_raises_clear_error(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    def fake_post(url: str, json: dict, timeout: float) -> httpx.Response:
        if url.endswith("/classify"):
            return response({"intent": "question", "confidence": 0.7, "reason": "question"})
        raise httpx.ConnectError("rag unavailable")

    monkeypatch.setattr(httpx, "post", fake_post)

    with pytest.raises(AIProcessingError, match="AI request failed: /rag/answer"):
        HTTPAIClient(Settings(ai_service_url="http://ai.test")).process_message(
            source="web",
            sender_id="customer-1",
            content="What is the warranty?",
        )


def test_ai_client_calls_process_message_and_document_endpoints(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    calls = []

    def fake_post(url: str, json: dict, timeout: float) -> httpx.Response:
        calls.append((url, json))
        if url.endswith("/process-message"):
            return response(
                {
                    "intent": "question",
                    "confidence": 0.8,
                    "answer": "Yes.",
                    "should_escalate": False,
                    "reason": "answered",
                }
            )
        return response(
            {
                "document_id": "doc-1",
                "embedding_status": "ready",
                "chunk_count": 3,
                "reason": "processed",
            }
        )

    monkeypatch.setattr(httpx, "post", fake_post)
    client = HTTPAIClient(Settings(ai_service_url="http://ai.test"))

    message = client.process_full_message(source="web", sender_id="c1", content="Hello")
    document = client.process_document(
        document_id="doc-1",
        file_url="/tmp/policy.txt",
        file_type="txt",
        file_name="policy.txt",
        file_size_bytes=42,
    )

    assert message.answer == "Yes."
    assert document.embedding_status == "ready"
    assert calls == [
        (
            "http://ai.test/process-message",
            {"source": "web", "sender_id": "c1", "content": "Hello"},
        ),
        (
            "http://ai.test/documents/process",
            {
                "document_id": "doc-1",
                "file_url": "/tmp/policy.txt",
                "file_type": "txt",
                "file_name": "policy.txt",
                "file_size_bytes": 42,
            },
        ),
    ]
