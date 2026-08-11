"""
rag/generator.py — Generate câu trả lời từ retrieved chunks + LLM.

Flow:
  chunks + history + question
    → assemble context
    → build prompt (system + user)
    → Gemini generate
    → return {text, confidence, should_create_ticket}
"""
from __future__ import annotations

import logging
from datetime import datetime
from pathlib import Path

from google import genai
from google.genai import types
from tenacity import retry, retry_if_exception_type, stop_after_attempt, wait_exponential

from config import settings

logger = logging.getLogger(__name__)

# ── Prompts ──────────────────────────────────────────────────────────────────

_PROMPTS_DIR = Path(__file__).parent.parent / "prompts"
_SYSTEM_TEMPLATE = (_PROMPTS_DIR / "rag_system.txt").read_text(encoding="utf-8")

_USER_TEMPLATE = """
--- TÀI LIỆU THAM KHẢO ---
{context}
--------------------------

LỊCH SỬ HỘI THOẠI:
{history}

KHÁCH HỎI: {question}

Trả lời:"""

# Khi không tìm thấy thông tin liên quan
_LOW_CONFIDENCE_REPLY = (
    "Cảm ơn bạn đã liên hệ! Câu hỏi này mình cần kiểm tra thêm để trả lời "
    "chính xác cho bạn. Mình sẽ chuyển đến nhân viên hỗ trợ ngay nhé, "
    "thường trong 5–10 phút sẽ có người liên hệ lại! 🙏"
)


# ── Generator ────────────────────────────────────────────────────────────────

class ResponseGenerator:
    """
    Sinh câu trả lời từ context RAG + lịch sử hội thoại.

    Returns dict:
      text                — câu trả lời gửi cho khách
      confidence          — "high" | "medium" | "low"
      should_create_ticket — True nếu không có context đủ tốt → cần human
      source_docs         — tên các tài liệu nguồn
    """

    def __init__(self, api_key: str, model_name: str | None = None):
        self._client     = genai.Client(api_key=api_key)
        self._model_name = model_name or settings.rag_model
        self._gen_config = types.GenerateContentConfig(
            temperature=0.3,        # Thấp → factual, ít sáng tác
            max_output_tokens=512,
        )

    async def generate(
        self,
        tenant_config: dict,
        question: str,
        chunks: list[dict],
        history: list[dict],
        max_similarity: float,
    ) -> dict:
        # Không đủ context → trả lời cố định và tạo ticket
        if not chunks or max_similarity < settings.similarity_threshold:
            logger.info(
                "Low confidence (%.3f) for question='%s...' → low_confidence reply",
                max_similarity, question[:50],
            )
            return {
                "text": _LOW_CONFIDENCE_REPLY,
                "confidence": "low",
                "should_create_ticket": True,
                "source_docs": [],
            }

        system_prompt = _SYSTEM_TEMPLATE.format(
            shop_name=tenant_config.get("shop_name", "Shop"),
            current_time=datetime.now().strftime("%H:%M %d/%m/%Y"),
        )
        context     = self._build_context(chunks)
        history_str = self._format_history(history)
        user_prompt = _USER_TEMPLATE.format(
            context=context,
            history=history_str,
            question=question,
        )

        try:
            reply = await self._call_llm(system_prompt, user_prompt)
        except Exception as exc:
            logger.error("LLM generation failed: %s", exc)
            return {
                "text": _LOW_CONFIDENCE_REPLY,
                "confidence": "low",
                "should_create_ticket": True,
                "source_docs": [],
            }

        confidence = (
            "high"   if max_similarity >= 0.80 else
            "medium" if max_similarity >= 0.65 else
            "low"
        )

        return {
            "text":                reply,
            "confidence":          confidence,
            "should_create_ticket": False,
            "source_docs": list({
                c["metadata"].get("doc_name", "Unknown")
                for c in chunks
            }),
        }

    # ── LLM call ─────────────────────────────────────────────────────────────

    @retry(
        retry=retry_if_exception_type(Exception),
        stop=stop_after_attempt(3),
        wait=wait_exponential(multiplier=1, min=1, max=8),
        reraise=True,
    )
    async def _call_llm(self, system: str, user: str) -> str:
        interaction = await self._client.aio.interactions.create(
            model=self._model_name,
            input=f"{system}\n\n{user}",
        )
        return interaction.output_text.strip()

    # ── Helpers ──────────────────────────────────────────────────────────────

    @staticmethod
    def _build_context(chunks: list[dict]) -> str:
        parts = []
        for i, chunk in enumerate(chunks, 1):
            doc_name = chunk["metadata"].get("doc_name", "Tài liệu")
            parts.append(f"[{i}] Từ '{doc_name}':\n{chunk['text']}")
        return "\n\n".join(parts)

    @staticmethod
    def _format_history(history: list[dict], max_turns: int = 5) -> str:
        if not history:
            return "(Đây là tin nhắn đầu tiên)"
        recent = history[-(max_turns * 2):]
        lines  = []
        for msg in recent:
            label = "Khách" if msg["role"] == "user" else "Bot"
            lines.append(f"{label}: {msg['content'][:300]}")
        return "\n".join(lines)
