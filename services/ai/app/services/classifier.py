import json
import re
from collections.abc import Callable
from typing import Any

import httpx
from pydantic import ValidationError

from app.core.config import Settings, get_settings
from app.schemas.classification import ClassificationResponse
from app.schemas.common import IntentType


LLM_SYSTEM_PROMPT = (
    "Classify one customer support message. Return JSON only with: "
    "intent question|complaint|spam, confidence 0..1, reason under 12 words."
)
COMPLAINT_KEYWORDS = {
    "angry",
    "refund",
    "broken",
    "cancel",
    "late",
    "complaint",
    "bad service",
    "damaged",
    "not working",
    "terrible",
    "unacceptable",
    "lost order",
    "never arrived",
    "want my money back",
}
SPAM_PATTERNS = [
    re.compile(r"https?://", re.IGNORECASE),
    re.compile(r"\bbit\.ly/", re.IGNORECASE),
    re.compile(r"\btinyurl\.com/", re.IGNORECASE),
    re.compile(r"\bfree money\b", re.IGNORECASE),
    re.compile(r"\bbuy now\b", re.IGNORECASE),
    re.compile(r"\bpromo code\b", re.IGNORECASE),
    re.compile(r"\bclick\b.+\bnow\b", re.IGNORECASE),
    re.compile(r"\bsubscribe\b.+\bchannel\b", re.IGNORECASE),
    re.compile(r"(.)\1{8,}"),
    re.compile(r"\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b.*\bhttps?://", re.IGNORECASE),
]


class LLMClassificationError(Exception):
    """Raised when LLM classification fails or returns invalid output."""


LLMClassifier = Callable[[str, Settings], ClassificationResponse]


def _coerce_llm_response(payload: dict[str, Any]) -> ClassificationResponse:
    try:
        return ClassificationResponse(
            intent=IntentType(payload["intent"]),
            confidence=float(payload["confidence"]),
            reason=str(payload["reason"])[:160],
            used_fallback=False,
        )
    except (KeyError, ValueError, TypeError, ValidationError) as exc:
        raise LLMClassificationError("Invalid LLM classification response") from exc


def _classify_with_openai(message_text: str, settings: Settings) -> ClassificationResponse:
    response = httpx.post(
        "https://api.openai.com/v1/chat/completions",
        headers={"Authorization": f"Bearer {settings.openai_api_key}"},
        json={
            "model": "gpt-4o-mini",
            "temperature": 0,
            "response_format": {"type": "json_object"},
            "messages": [
                {"role": "system", "content": LLM_SYSTEM_PROMPT},
                {"role": "user", "content": message_text[:1200]},
            ],
        },
        timeout=settings.llm_timeout_seconds,
    )
    response.raise_for_status()
    content = response.json()["choices"][0]["message"]["content"]
    return _coerce_llm_response(json.loads(content))


def _classify_with_gemini(message_text: str, settings: Settings) -> ClassificationResponse:
    response = httpx.post(
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent",
        params={"key": settings.gemini_api_key},
        json={
            "generationConfig": {"temperature": 0, "responseMimeType": "application/json"},
            "contents": [
                {
                    "parts": [
                        {"text": f"{LLM_SYSTEM_PROMPT}\nMessage: {message_text[:1200]}"},
                    ]
                }
            ],
        },
        timeout=settings.llm_timeout_seconds,
    )
    response.raise_for_status()
    content = response.json()["candidates"][0]["content"]["parts"][0]["text"]
    return _coerce_llm_response(json.loads(content))


def classify_with_llm(message_text: str, settings: Settings) -> ClassificationResponse:
    try:
        if settings.openai_api_key:
            return _classify_with_openai(message_text, settings)
        if settings.gemini_api_key:
            return _classify_with_gemini(message_text, settings)
    except (httpx.TimeoutException, httpx.HTTPError, KeyError, IndexError, ValueError) as exc:
        raise LLMClassificationError("LLM classification failed") from exc
    raise LLMClassificationError("No LLM provider configured")


def classify_intent(
    message_text: str,
    settings: Settings | None = None,
    llm_classifier: LLMClassifier | None = None,
) -> ClassificationResponse:
    settings = settings or get_settings()
    text = message_text.strip()

    if settings.has_llm_provider:
        try:
            classifier = llm_classifier or classify_with_llm
            return classifier(text, settings)
        except LLMClassificationError:
            return ClassificationResponse(
                intent=IntentType.QUESTION,
                confidence=0.5,
                reason="LLM failed; defaulted to question.",
                used_fallback=True,
            )

    lowered = text.casefold()
    if any(pattern.search(text) for pattern in SPAM_PATTERNS):
        return ClassificationResponse(
            intent=IntentType.SPAM,
            confidence=0.95,
            reason="Fallback classifier matched spam pattern.",
            used_fallback=True,
        )
    if any(keyword in lowered for keyword in COMPLAINT_KEYWORDS):
        return ClassificationResponse(
            intent=IntentType.COMPLAINT,
            confidence=0.87,
            reason="Fallback classifier matched complaint keyword.",
            used_fallback=True,
        )
    return ClassificationResponse(
        intent=IntentType.QUESTION,
        confidence=0.76,
        reason="Fallback classifier defaulted to question.",
        used_fallback=True,
    )
