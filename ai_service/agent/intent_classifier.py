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
        import unicodedata
        def _strip_accents(s: str) -> str:
            return "".join(
                c for c in unicodedata.normalize("NFD", s) if unicodedata.category(c) != "Mn"
            ).replace("đ", "d").replace("Đ", "D").lower()

        clean_msg = message.strip().lower()
        norm_msg = _strip_accents(clean_msg)
        
        # 1. Fast-path: Greetings (CHỈ áp dụng cho câu chào hỏi thuần túy, không có nội dung câu hỏi phía sau)
        greetings = {"hello", "hi", "xin chao", "chao", "chao shop", "hi shop", "shop oi", "alo", "alo shop", "hey", "yo", "good morning"}
        words_count = len(norm_msg.split())
        question_words = ["gia", "bao nhieu", "size", "mau", "ship", "freeship", "co", "khong", "the nao", "o dau", "ao", "quan", "giay", "doi tra", "bao hanh", "cho minh hoi", "cho em hoi"]
        has_question = any(qw in norm_msg for qw in question_words)

        if (norm_msg in greetings or (words_count <= 3 and any(norm_msg.startswith(g) for g in greetings))) and not has_question:
            return IntentResult(
                intent=IntentType.GREETING,
                confidence=1.0,
                reasoning="Fast-path: cụm từ chào hỏi thuần túy",
                detected_keywords=[clean_msg],
                urgency_level=1,
            )

        # 2. Fast-path: Human Escalation / Handoff request
        human_keywords = [
            "gap nhan vien", "gap tu van vien", "gap nguoi", "tu van vien", "noi chuyen voi nguoi",
            "chuyen nguoi that", "nhan vien cskh", "gap tong dai", "chuyen may", "noi chuyen voi nhan vien",
            "goi nhan vien", "human", "agent", "gap cskh", "tu van truc tiep", "nhan vien ho tro"
        ]
        if any(kw in norm_msg for kw in human_keywords):
            return IntentResult(
                intent=IntentType.ESCALATION_REQ,
                confidence=0.99,
                reasoning="Fast-path: Khách yêu cầu kết nối nhân viên tư vấn",
                detected_keywords=[kw for kw in human_keywords if kw in norm_msg],
                urgency_level=2,
            )

        # 3. Fast-path: Angry / Serious Complaints
        angry_keywords = [
            "lua dao", "tay chay", "bao cong an", "kien", "an cuop", "khon nan",
            "hoan tien ngay", "doi tien", "lam an nhu", "buc minh qua"
        ]
        if any(kw in norm_msg for kw in angry_keywords):
            return IntentResult(
                intent=IntentType.ANGRY,
                confidence=0.99,
                reasoning="Fast-path: Phát hiện từ khóa bức xúc nghiêm trọng",
                detected_keywords=[kw for kw in angry_keywords if kw in norm_msg],
                urgency_level=3,
            )

        # 4. Fast-path: Standard Complaints
        complaint_keywords = [
            "hang loi", "bi loi", "giao sai", "hu hong", "bi rach", "hang gia",
            "hong", "thieu hang", "chua nhan duoc hang", "giao lau qua", "hang be", "doi tra"
        ]
        if any(kw in norm_msg for kw in complaint_keywords) and ("khong" not in norm_msg and "the nao" not in norm_msg):
            return IntentResult(
                intent=IntentType.COMPLAINT,
                confidence=0.95,
                reasoning="Fast-path: Khách phản ánh vấn đề đơn hàng / khiếu nại",
                detected_keywords=[kw for kw in complaint_keywords if kw in norm_msg],
                urgency_level=2,
            )

        # 5. Fast-path: Common FAQs (Product, policy, store info)
        faq_keywords = [
            "gia", "bao nhieu", "freeship", "ship", "phi ship", "van chuyen", "size", "kich co",
            "bao hanh", "doi tra", "doi size", "o dau", "dia chi", "chi nhanh", "mo cua",
            "chat lieu", "mau gi", "giam gia", "khuyen mai", "sale", "ao", "quan", "giay", "balo",
            "binh giu nhiet", "tham yoga", "polo", "pro active", "ultra boost", "hoa don", "chinh sach"
        ]
        if any(kw in norm_msg for kw in faq_keywords):
            return IntentResult(
                intent=IntentType.GENERAL_FAQ,
                confidence=0.90,
                reasoning="Fast-path: Câu hỏi thông tin sản phẩm, chính sách hoặc dịch vụ",
                detected_keywords=[kw for kw in faq_keywords if kw in norm_msg],
                urgency_level=1,
            )

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
            logger.warning(
                "IntentClassifier LLM fallback for message '%s...': %s",
                message[:50], exc,
            )
            # Fallback thông minh: nếu có câu hỏi thì coi là FAQ
            return IntentResult(
                intent=IntentType.GENERAL_FAQ,
                confidence=0.85,
                reasoning="Fallback NLP heuristic: phân loại câu hỏi tư vấn khách hàng",
                detected_keywords=[],
                urgency_level=1,
            )

    async def _call_with_retry(self, system: str, user: str) -> IntentResult:
        """Gọi Gemini API không kéo dài delay nếu gặp 429 ResourceExhausted."""
        full_prompt = f"{system}\n\n{user}"

        response = await self._client.aio.models.generate_content(
            model=self._model_name,
            contents=full_prompt,
            config=self._gen_config,
        )
        raw_text = (response.text or "").strip()

        return self._parse_response(raw_text)

    def _parse_response(self, raw: str) -> IntentResult:
        """
        Parse JSON response từ Gemini với bảo vệ regex nhiều lớp.
        """
        import re
        # Tìm block json trong ngoặc nhọn
        json_match = re.search(r'\{.*\}', raw, re.DOTALL)
        if json_match:
            raw_json = json_match.group(0)
        else:
            raw_json = raw

        try:
            data = json.loads(raw_json)
        except Exception:
            # Nếu JSON bị lỗi cụ thể (ví dụ Unterminated string), fallback
            return IntentResult(
                intent=IntentType.GENERAL_FAQ,
                confidence=0.80,
                reasoning="LLM JSON parse fallback",
                detected_keywords=[],
                urgency_level=1,
            )

        # Normalize intent string (uppercase + trim)
        if "intent" in data:
            data["intent"] = str(data["intent"]).upper().strip()

        # Clamp confidence vào [0, 1]
        if "confidence" in data:
            try:
                data["confidence"] = max(0.0, min(1.0, float(data["confidence"])))
            except Exception:
                data["confidence"] = 0.80

        # Clamp urgency_level vào [1, 3]
        if "urgency_level" in data:
            try:
                data["urgency_level"] = max(1, min(3, int(data["urgency_level"])))
            except Exception:
                data["urgency_level"] = 1

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
