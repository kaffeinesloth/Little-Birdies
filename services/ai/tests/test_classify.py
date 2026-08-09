from fastapi.testclient import TestClient

from app.core.config import Settings
from app.main import create_app
from app.schemas.classification import ClassificationResponse
from app.schemas.common import IntentType
from app.services.classifier import LLMClassificationError, classify_intent


def test_classify_uses_deterministic_question_fallback_without_api_key() -> None:
    client = TestClient(create_app())

    response = client.post("/classify", json={"message_text": "What is your return policy?"})

    assert response.status_code == 200
    assert response.json() == {
        "intent": "question",
        "confidence": 0.76,
        "reason": "Fallback classifier defaulted to question.",
        "used_fallback": True,
    }


def test_classify_question_fallback() -> None:
    result = classify_intent("Do you have size M in stock?")

    assert result.intent == IntentType.QUESTION
    assert result.confidence == 0.76
    assert result.reason == "Fallback classifier defaulted to question."
    assert result.used_fallback is True


def test_classify_complaint_fallback() -> None:
    result = classify_intent("My order arrived broken and I want a refund.")

    assert result.intent == IntentType.COMPLAINT
    assert result.confidence == 0.87
    assert "complaint keyword" in result.reason
    assert result.used_fallback is True


def test_classify_spam_fallback() -> None:
    result = classify_intent("CLICK this suspicious link now: https://spam.example/deal")

    assert result.intent == IntentType.SPAM
    assert result.confidence == 0.95
    assert "spam pattern" in result.reason
    assert result.used_fallback is True


def test_classify_uses_llm_when_configured() -> None:
    def fake_llm(message_text: str, settings: Settings) -> ClassificationResponse:
        assert message_text == "This package is late"
        assert settings.openai_api_key == "test-key"
        return ClassificationResponse(
            intent=IntentType.COMPLAINT,
            confidence=0.93,
            reason="LLM saw delivery complaint.",
            used_fallback=False,
        )

    result = classify_intent(
        "This package is late",
        settings=Settings(openai_api_key="test-key"),
        llm_classifier=fake_llm,
    )

    assert result.intent == IntentType.COMPLAINT
    assert result.confidence == 0.93
    assert result.used_fallback is False


def test_classify_llm_timeout_or_error_defaults_to_question() -> None:
    def failing_llm(message_text: str, settings: Settings) -> ClassificationResponse:
        raise LLMClassificationError("timeout")

    result = classify_intent(
        "This package is late",
        settings=Settings(openai_api_key="test-key"),
        llm_classifier=failing_llm,
    )

    assert result.intent == IntentType.QUESTION
    assert result.confidence == 0.5
    assert result.reason == "LLM failed; defaulted to question."
    assert result.used_fallback is True
