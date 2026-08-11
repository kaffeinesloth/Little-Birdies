"""
agent/intent_classifier.py — Phân loại ý định tin nhắn bằng LLM.

Flow:
  message + recent_history
    → build prompt
    → call Gemini Flash với JSON mode
    → parse → IntentResult

Design decisions:
  - Dùng Gemini Flash (không phải Pro) vì classification không cần deep reasoning
  - JSON mode (response_mime_type) để output luôn parseable, không cần regex
  - Retry 3 lần với exponential backoff (Gemini có rate limit)
  - Prompt được đọc từ file prompts/ để dễ chỉnh sửa mà không cần deploy lại
"""
from __future__ import annotations

import json
import logging
from pathlib import Path

from google import genai
from google.genai import types
from tenacity import (
    retry,
    retry_if_exception_type,
    stop_after_attempt,
    wait_exponential,
)

from agent.schemas import IntentResult, IntentType

logger = logging.getLogger(__name__)

# ─────────────────────────────────────────────────────────────────────────────
# Prompt loading
# ─────────────────────────────────────────────────────────────────────────────

_PROMPTS_DIR = Path(__file__).parent.parent / "prompts"


def _load_prompt(filename: str) -> str:
    path = _PROMPTS_DIR / filename
    return path.read_text(encoding="utf-8")


_SYSTEM_PROMPT = _load_prompt("intent_system.txt")

_USER_TEMPLATE = """
Tin nhắn từ khách hàng:
"{message}"

Lịch sử hội thoại gần nhất (nếu có):
{history}

Phân loại intent và trả về JSON:"""


# ─────────────────────────────────────────────────────────────────────────────
# Fallback khi LLM fail
# ─────────────────────────────────────────────────────────────────────────────

_FALLBACK_RESULT = IntentResult(
    intent=IntentType.GENERAL_FAQ,
    confidence=0.40,
    reasoning="Fallback — LLM không khả dụng",
    detected_keywords=[],
    urgency_level=1,
)


# ─────────────────────────────────────────────────────────────────────────────
# Classifier
# ─────────────────────────────────────────────────────────────────────────────

class IntentClassifier:
    """
    Phân loại ý định tin nhắn bằng Gemini Flash.

    Usage:
        classifier = IntentClassifier(api_key="YOUR_KEY")
        result = await classifier.classify("Giá áo này bao nhiêu?")
        print(result.intent)     # IntentType.GENERAL_FAQ
        print(result.confidence) # 0.95
        print(result.requires_human) # False
    """

    def __init__(
        self,
        api_key: str,
        model_name: str = "gemini-3.6-flash",
    ):
        self._client = genai.Client(api_key=api_key)
        self._model_name = model_name
        self._gen_config = types.GenerateContentConfig(
            response_mime_type="application/json",  # Force JSON output
            temperature=0.1,    # Low temp → deterministic classification
            max_output_tokens=300,
        )
        logger.info("IntentClassifier initialized with model: %s", model_name)

    async def classify(
        self,
        message: str,
        recent_history: list[dict[str, str]] | None = None,
    ) -> IntentResult:
        """
        Classify ý định của 1 tin nhắn.

        Args:
            message: Tin nhắn gốc từ khách hàng
            recent_history: List[{role, content}] — chỉ dùng 3 tin gần nhất
                            để tránh inject quá nhiều context vào classification

        Returns:
            IntentResult — luôn trả về (không raise), fallback nếu fail
        """
        history_str = self._format_history(recent_history or [])
        user_content = _USER_TEMPLATE.format(
            message=message,
            history=history_str,
        )

        try:
            result = await self._call_with_retry(
                system=_SYSTEM_PROMPT,
                user=user_content,
            )
            logger.debug(
                "Classified '%s...' → %s (%.2f)",
                message[:50], result.intent, result.confidence,
            )
            return result

        except Exception as exc:
            logger.error(
                "IntentClassifier failed for message '%s...': %s",
                message[:50], exc,
            )
            return _FALLBACK_RESULT

    @retry(
        retry=retry_if_exception_type(Exception),
        stop=stop_after_attempt(3),
        wait=wait_exponential(multiplier=1, min=1, max=8),
        reraise=True,
    )
    async def _call_with_retry(self, system: str, user: str) -> IntentResult:
        """Gọi Gemini Interactions API với retry 3 lần, exponential backoff."""
        full_prompt = f"{system}\n\n{user}"

        interaction = await self._client.aio.interactions.create(
            model=self._model_name,
            input=full_prompt,
            response_format=[{
                "type": "text",
                "mime_type": "application/json",
                "schema": IntentResult.model_json_schema(),
            }],
        )
        raw_text = interaction.output_text.strip()

        return self._parse_response(raw_text)

    def _parse_response(self, raw: str) -> IntentResult:
        """
        Parse JSON response từ Gemini.
        Có xử lý edge case: Gemini đôi khi vẫn bọc trong ```json ... ```
        dù đã dùng JSON mode.
        """
        # Strip markdown fences nếu có (defensive)
        if raw.startswith("```"):
            lines = raw.split("\n")
            raw = "\n".join(lines[1:-1])

        data = json.loads(raw)

        # Normalize intent string (uppercase + trim)
        if "intent" in data:
            data["intent"] = str(data["intent"]).upper().strip()

        # Clamp confidence vào [0, 1]
        if "confidence" in data:
            data["confidence"] = max(0.0, min(1.0, float(data["confidence"])))

        # Clamp urgency_level vào [1, 3]
        if "urgency_level" in data:
            data["urgency_level"] = max(1, min(3, int(data["urgency_level"])))

        return IntentResult(**data)

    @staticmethod
    def _format_history(history: list[dict[str, str]], max_turns: int = 3) -> str:
        """
        Format lịch sử hội thoại để inject vào prompt.
        Chỉ lấy tối đa 3 tin nhắn gần nhất (6 turns = 3 cặp hỏi-đáp).
        """
        if not history:
            return "(Đây là tin nhắn đầu tiên trong cuộc hội thoại)"

        recent = history[-(max_turns * 2):]
        lines = []
        for msg in recent:
            role_label = "Khách" if msg["role"] == "user" else "Bot"
            content = msg["content"][:200]  # Truncate để tránh quá dài
            lines.append(f"  {role_label}: {content}")

        return "\n".join(lines)


# ─────────────────────────────────────────────────────────────────────────────
# Factory function — dùng trong FastAPI Depends()
# ─────────────────────────────────────────────────────────────────────────────

def create_intent_classifier() -> IntentClassifier:
    """Factory cho FastAPI dependency injection."""
    from config import settings
    return IntentClassifier(
        api_key=settings.google_api_key,
        model_name=settings.intent_model,  # default: "gemini-2.0-flash"
    )
