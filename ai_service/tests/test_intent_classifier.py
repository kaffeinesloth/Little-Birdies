"""
tests/test_intent_classifier.py

Test IntentClassifier với 2 loại test:
  1. Unit tests (mock LLM) — chạy không cần API key, fast
  2. Integration tests (real LLM) — chạy khi có GOOGLE_API_KEY, đánh dấu @pytest.mark.integration

Chạy chỉ unit tests (mặc định):
  pytest tests/test_intent_classifier.py -v

Chạy cả integration tests:
  pytest tests/test_intent_classifier.py -v -m integration
"""
from __future__ import annotations

import json
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from agent.intent_classifier import IntentClassifier, _FALLBACK_RESULT
from agent.schemas import IntentResult, IntentType


# ─────────────────────────────────────────────────────────────────────────────
# Fixtures & helpers
# ─────────────────────────────────────────────────────────────────────────────

def make_gemini_response(data: dict) -> MagicMock:
    """Tạo mock response giống generate_content API trả về."""
    mock = MagicMock()
    mock.text = json.dumps(data)
    return mock


def make_classifier() -> IntentClassifier:
    """Tạo classifier mà không cần gọi genai.Client thật."""
    with patch("agent.intent_classifier.genai.Client"):
        clf = IntentClassifier(api_key="fake-key", model_name="gemini-2.0-flash")
    return clf


def result_for(
    intent: str,
    confidence: float = 0.92,
    urgency: int = 1,
    keywords: list[str] | None = None,
) -> dict:
    return {
        "intent": intent,
        "confidence": confidence,
        "reasoning": "Test reasoning",
        "detected_keywords": keywords or [],
        "urgency_level": urgency,
    }


# ─────────────────────────────────────────────────────────────────────────────
# Unit tests — GENERAL_FAQ
# ─────────────────────────────────────────────────────────────────────────────

def mock_llm(clf: IntentClassifier, data: dict) -> None:
    """Helper: patch _client.aio.models.generate_content để trả về data dict."""
    mock_resp = make_gemini_response(data)
    clf._client.aio.models.generate_content = AsyncMock(return_value=mock_resp)


class TestGeneralFAQ:
    @pytest.mark.asyncio
    async def test_price_question(self):
        clf = make_classifier()
        mock_llm(clf, result_for("GENERAL_FAQ", keywords=["giá"]))

        result = await clf.classify("Giá áo này bao nhiêu vậy shop?")

        assert result.intent == IntentType.GENERAL_FAQ
        assert result.confidence > 0.5
        assert not result.requires_human
        assert result.urgency_level == 1

    @pytest.mark.asyncio
    async def test_delivery_question(self):
        clf = make_classifier()
        mock_llm(clf, result_for("GENERAL_FAQ", keywords=["giao hàng", "ship"]))

        result = await clf.classify("Shop giao hàng tới quận 7 mất mấy ngày?")

        assert result.intent == IntentType.GENERAL_FAQ
        assert not result.requires_human

    @pytest.mark.asyncio
    async def test_return_policy_question(self):
        clf = make_classifier()
        mock_llm(clf, result_for("GENERAL_FAQ", keywords=["đổi trả"]))

        result = await clf.classify("Chính sách đổi trả của shop như thế nào ạ?")

        assert result.intent == IntentType.GENERAL_FAQ


# ─────────────────────────────────────────────────────────────────────────────
# Unit tests — COMPLAINT
# ─────────────────────────────────────────────────────────────────────────────

class TestComplaint:
    @pytest.mark.asyncio
    async def test_wrong_item_received(self):
        clf = make_classifier()
        mock_llm(clf, result_for("COMPLAINT", confidence=0.95, urgency=2, keywords=["sai hàng"]))

        result = await clf.classify("Shop giao nhầm hàng rồi, tôi order size L mà nhận size S")

        assert result.intent == IntentType.COMPLAINT
        assert result.requires_human
        assert result.urgency_level >= 2

    @pytest.mark.asyncio
    async def test_damaged_product(self):
        clf = make_classifier()
        mock_llm(clf, result_for("COMPLAINT", confidence=0.90, urgency=2, keywords=["hỏng", "lỗi"]))

        result = await clf.classify("Hàng nhận được bị hỏng, hộp méo hết rồi")

        assert result.intent == IntentType.COMPLAINT
        assert result.requires_human

    @pytest.mark.asyncio
    async def test_refund_request_is_urgent(self):
        clf = make_classifier()
        mock_llm(clf, result_for("COMPLAINT", confidence=0.96, urgency=3, keywords=["hoàn tiền"]))

        result = await clf.classify("Tôi yêu cầu hoàn tiền ngay, shop bán hàng kém chất lượng")

        assert result.intent == IntentType.COMPLAINT
        assert result.requires_human
        assert result.urgency_level == 3


class TestAngry:
    @pytest.mark.asyncio
    async def test_all_caps_angry(self):
        clf = make_classifier()
        mock_llm(clf, result_for("ANGRY", confidence=0.97, urgency=3, keywords=["!!!", "LỪA ĐẢO"]))

        result = await clf.classify("ĐỒ LỪA ĐẢO!!! TÔI SẼ BÁO CÁO SHOP NÀY!!!")

        assert result.intent == IntentType.ANGRY
        assert result.requires_human
        assert result.urgency_level == 3

    @pytest.mark.asyncio
    async def test_threat_to_leave_bad_review(self):
        clf = make_classifier()
        mock_llm(clf, result_for("ANGRY", confidence=0.93, urgency=3, keywords=["review 1 sao"]))

        result = await clf.classify("Phục vụ tệ quá, tôi sẽ review 1 sao khắp nơi!")

        assert result.intent == IntentType.ANGRY
        assert result.requires_human


class TestEscalationRequest:
    @pytest.mark.asyncio
    async def test_ask_for_manager(self):
        clf = make_classifier()
        mock_llm(clf, result_for("ESCALATION_REQ", urgency=2))

        result = await clf.classify("Cho tôi gặp quản lý được không?")

        assert result.intent == IntentType.ESCALATION_REQ
        assert result.requires_human

    @pytest.mark.asyncio
    async def test_ask_for_real_human(self):
        clf = make_classifier()
        mock_llm(clf, result_for("ESCALATION_REQ", urgency=2))

        result = await clf.classify("Bot không hiểu tôi, tôi muốn nói chuyện với người thật")

        assert result.intent == IntentType.ESCALATION_REQ
        assert result.requires_human


class TestGreeting:
    @pytest.mark.asyncio
    async def test_simple_hello(self):
        clf = make_classifier()
        mock_llm(clf, result_for("GREETING", confidence=0.99, urgency=1))

        result = await clf.classify("Xin chào shop!")

        assert result.intent == IntentType.GREETING
        assert not result.requires_human
        assert result.urgency_level == 1

    @pytest.mark.asyncio
    async def test_hey_shop(self):
        clf = make_classifier()
        mock_llm(clf, result_for("GREETING", confidence=0.98))

        result = await clf.classify("Shop ơi cho hỏi")

        assert result.intent == IntentType.GREETING


class TestOutOfScope:
    @pytest.mark.asyncio
    async def test_unrelated_question(self):
        clf = make_classifier()
        mock_llm(clf, result_for("OUT_OF_SCOPE", confidence=0.95, urgency=1))

        result = await clf.classify("Hôm nay thời tiết Hà Nội như thế nào?")

        assert result.intent == IntentType.OUT_OF_SCOPE
        assert not result.requires_human


class TestErrorHandling:
    @pytest.mark.asyncio
    async def test_api_error_returns_fallback(self):
        """Khi Gemini API fail → trả về FALLBACK, không raise exception."""
        clf = make_classifier()
        clf._client.aio.models.generate_content = AsyncMock(
            side_effect=Exception("API timeout")
        )
        result = await clf.classify("Test message")
        assert result == _FALLBACK_RESULT
        assert result.intent == IntentType.GENERAL_FAQ

    @pytest.mark.asyncio
    async def test_invalid_json_response_returns_fallback(self):
        """Khi Gemini trả về JSON lỗi → fallback."""
        clf = make_classifier()
        bad_resp = MagicMock()
        bad_resp.text = "không phải JSON"
        clf._client.aio.models.generate_content = AsyncMock(return_value=bad_resp)
        result = await clf.classify("Test message")
        assert result == _FALLBACK_RESULT

    @pytest.mark.asyncio
    async def test_markdown_fenced_json_is_parsed(self):
        """Defensive: strip ```json fences."""
        clf = make_classifier()
        raw_data = result_for("GENERAL_FAQ")
        fenced_resp = MagicMock()
        fenced_resp.text = f"```json\n{json.dumps(raw_data)}\n```"
        clf._client.aio.models.generate_content = AsyncMock(return_value=fenced_resp)
        result = await clf.classify("Giá sao?")
        assert result.intent == IntentType.GENERAL_FAQ

    @pytest.mark.asyncio
    async def test_confidence_clamped_to_valid_range(self):
        """Confidence ngoài [0, 1] phải được clamp."""
        clf = make_classifier()
        data = result_for("COMPLAINT")
        data["confidence"] = 1.5
        mock_llm(clf, data)
        result = await clf.classify("Test")
        assert 0.0 <= result.confidence <= 1.0


# ─────────────────────────────────────────────────────────────────────────────
# Unit tests — History formatting
# ─────────────────────────────────────────────────────────────────────────────

class TestHistoryFormatting:
    def test_empty_history(self):
        clf = make_classifier()
        result = clf._format_history([])
        assert "first message" in result.lower()

    def test_history_is_truncated_to_3_turns(self):
        """Chỉ lấy 3 cặp hỏi-đáp gần nhất (6 messages)."""
        clf = make_classifier()
        history = [
            {"role": "user",      "content": f"Message {i}"}
            for i in range(10)
        ]
        result = clf._format_history(history)

        # Chỉ có 6 message gần nhất (messages 4-9)
        assert "Message 9" in result
        assert "Message 4" in result
        assert "Message 0" not in result   # Bị bỏ qua

    def test_long_content_is_truncated(self):
        """Content > 200 chars phải được truncate để tránh inject quá nhiều."""
        clf = make_classifier()
        long_msg = "A" * 500
        history = [{"role": "user", "content": long_msg}]
        result = clf._format_history(history)

        # Content bị truncate ở 200 chars
        assert len(result) < 500 + 50   # +50 cho prefix "Khách: "


# ─────────────────────────────────────────────────────────────────────────────
# Integration tests — chỉ chạy khi có GOOGLE_API_KEY thực
# ─────────────────────────────────────────────────────────────────────────────

@pytest.mark.integration
class TestIntegration:
    """
    Chạy với: pytest -m integration
    Cần có GOOGLE_API_KEY trong .env
    """

    @pytest.fixture(autouse=True)
    def classifier(self):
        import os
        from dotenv import load_dotenv
        load_dotenv()
        api_key = os.getenv("GOOGLE_API_KEY")
        if not api_key:
            pytest.skip("GOOGLE_API_KEY không có trong .env")
        self.clf = IntentClassifier(api_key=api_key)

    @pytest.mark.asyncio
    async def test_real_faq_classification(self):
        result = await self.clf.classify("Giá áo polo này bao nhiêu tiền?")
        assert result.intent == IntentType.GENERAL_FAQ
        assert result.confidence > 0.7

    @pytest.mark.asyncio
    async def test_real_complaint_classification(self):
        result = await self.clf.classify("Hàng giao bị lỗi, tôi muốn đổi lại")
        assert result.intent == IntentType.COMPLAINT
        assert result.requires_human

    @pytest.mark.asyncio
    async def test_real_angry_classification(self):
        result = await self.clf.classify("LỪA ĐẢO!!! HOÀN TIỀN NGAY!!!")
        assert result.intent == IntentType.ANGRY
        assert result.urgency_level == 3

    @pytest.mark.asyncio
    async def test_real_greeting(self):
        result = await self.clf.classify("Hello shop!")
        assert result.intent == IntentType.GREETING

    @pytest.mark.asyncio
    async def test_real_escalation(self):
        result = await self.clf.classify("Cho tôi nói chuyện với người thật, không phải bot")
        assert result.intent == IntentType.ESCALATION_REQ
