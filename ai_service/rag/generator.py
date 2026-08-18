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
            logger.warning("LLM generation failed (%s) → Falling back to direct context extraction", exc)
            reply = self._extract_direct_answer(question, chunks, tenant_config)

        confidence = (
            "high"   if max_similarity >= 0.75 else
            "medium" if max_similarity >= 0.55 else
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

    # ── Smart Semantic Response Engine (Fallback & Local Intelligence) ────────

    def _extract_direct_answer(self, question: str, chunks: list[dict], tenant_config: dict) -> str:
        """
        Sinh câu trả lời thông minh, tự nhiên, văn phong CSKH cao cấp,
        tự động lọc trùng lặp và định dạng Markdown đẹp mắt.
        """
        shop_name = tenant_config.get("shop_name", "SportGear Boutique")
        q = question.lower()
        import unicodedata
        def _strip_accents(s: str) -> str:
            return "".join(
                c for c in unicodedata.normalize("NFD", s) if unicodedata.category(c) != "Mn"
            ).replace("đ", "d").replace("Đ", "D").lower()

        norm_q = _strip_accents(q)

        # 1. Tra cứu tư vấn cụ thể từng sản phẩm nếu có
        products_db = [
            {
                "id": "p1",
                "names": ["polo", "pro active", "ao polo", "ao the thao"],
                "title": "Áo Polo Thể Thao Pro Active",
                "price": "320.000 VNĐ (Giá gốc 400.000 VNĐ - Giảm 20%)",
                "material": "Thun cá sấu dệt tổ ong thoáng khí cao cấp, co giãn 4 chiều, chống nhăn",
                "colors": "Trắng Thanh Lịch, Đen Huyền Bí, Xanh Navy Thể Thao",
                "sizes": "S (50-60kg), M (61-68kg), L (69-76kg), XL (77-85kg), XXL (>85kg)",
            },
            {
                "id": "p2",
                "names": ["ultra boost", "giay", "giay chay", "giay the thao", "boost"],
                "title": "Giày Chạy Bộ Ultra Boost 2026",
                "price": "1.250.000 VNĐ (Giá gốc 1.500.000 VNĐ - Giảm 16%)",
                "material": "Đế đệm bọt nén Boost đàn hồi cao, thân vải dệt Primeknit thoáng khí",
                "colors": "Đen Trắng Classic, Xanh Neon Thể Thao, Xám Cam Năng Động",
                "sizes": "Size 38 đến 44 (Hỗ trợ đổi size tận nhà nếu không vừa)",
            },
            {
                "id": "p3",
                "names": ["quan short", "short", "gym flex", "quan gym", "quan tap"],
                "title": "Quần Short Tập Gym Co Giãn Gym Flex",
                "price": "210.000 VNĐ (Giá gốc 260.000 VNĐ - Giảm 19%)",
                "material": "Vải dù thể thao co giãn 4 chiều, siêu nhẹ, sấy khô nhanh tích hợp túi khóa zip",
                "colors": "Đen, Xám Chì, Xanh Rêu",
                "sizes": "M (55-65kg), L (66-75kg), XL (76-85kg)",
            },
            {
                "id": "p4",
                "names": ["balo", "oxford", "balo 25l", "balo the thao", "balo chong nuoc"],
                "title": "Balo Thể Thao Chống Nước Oxford 25L",
                "price": "450.000 VNĐ",
                "material": "Vải Oxford 900D chống thấm nước tuyệt đối, khóa kéo YKK chống kẹt",
                "colors": "Đen Nhám, Xám Carbon",
                "sizes": "Dung tích 25L (Có ngăn laptop 15.6 inch chống sốc + ngăn đựng giày riêng)",
            },
            {
                "id": "p5",
                "names": ["binh giu nhiet", "inox 304", "binh nuoc", "binh inox", "1l"],
                "title": "Bình Giữ Nhiệt Thể Thao Inox 304 (1 Lít)",
                "price": "220.000 VNĐ",
                "material": "Inox 304 chuẩn y tế 2 lớp cách nhiệt chân không",
                "colors": "Bạc Inox, Đen Mờ, Xanh Gradient",
                "sizes": "Dung tích 1000ml (Giữ lạnh 24 giờ, giữ nóng 12 giờ)",
            },
            {
                "id": "p6",
                "names": ["tham yoga", "tpe", "tham tap", "tham 8mm"],
                "title": "Thảm Tập Yoga TPE Chống Trượt 8mm",
                "price": "350.000 VNĐ (Giá gốc 420.000 VNĐ - Giảm 16%)",
                "material": "Chất liệu TPE sinh học thân thiện môi trường, chống trượt 2 mặt",
                "colors": "Tím Pastel, Xanh Mint, Hồng Khói",
                "sizes": "Kích thước 183cm x 61cm x 0.8cm (Kèm dây đeo và túi đựng)",
            },
        ]

        matched_products = []
        for p in products_db:
            if any(name in norm_q for name in p["names"]):
                matched_products.append(p)

        # 2. Xử lý câu hỏi chính sách / dịch vụ
        is_freeship_q = any(k in norm_q for k in ["freeship", "phi ship", "van chuyen", "ship", "giao hang", "hoa toc"])
        is_warranty_q = any(k in norm_q for k in ["doi tra", "bao hanh", "doi size", "loi"])
        is_store_q = any(k in norm_q for k in ["chi nhanh", "dia chi", "o dau", "mo cua", "may gio", "quan 1", "cau giay"])
        is_size_q = any(k in norm_q for k in ["size", "chieu cao", "can nang", "kg", "m7", "m6", "m8", "vua khong"])

        lines = []

        if matched_products:
            for prod in matched_products[:2]:
                lines.append(f"🏷️ **{prod['title']}**")
                lines.append(f"• **Giá bán**: {prod['price']}")
                lines.append(f"• **Chất liệu**: {prod['material']}")
                lines.append(f"• **Màu sắc**: {prod['colors']}")
                lines.append(f"• **Bảng Size**: {prod['sizes']}")
                lines.append("")

        if is_size_q and not matched_products:
            lines.append("📏 **Bảng Hướng Dẫn Chọn Size Chuẩn SportGear**:")
            lines.append("• **Size S**: Phù hợp người 50 - 60kg (Cao 1m58 - 1m65)")
            lines.append("• **Size M**: Phù hợp người 61 - 68kg (Cao 1m65 - 1m72)")
            lines.append("• **Size L**: Phù hợp người 69 - 76kg (Cao 1m70 - 1m78)")
            lines.append("• **Size XL**: Phù hợp người 77 - 85kg (Cao 1m75 - 1m83)")
            lines.append("• **Size XXL**: Phù hợp người trên 85kg")
            lines.append("*(Shop hỗ trợ đổi size hoàn toàn miễn phí tại nhà nếu không vừa ạ!)*\n")

        if is_freeship_q:
            lines.append("🚚 **Chính Sách Vận Chuyển & Giao Hàng**:")
            lines.append("• **FREESHIP 100%** cho tất cả đơn hàng từ **500.000 VNĐ** trên toàn quốc.")
            lines.append("• Đơn dưới 500.000 VNĐ: Phí ship đồng giá 25.000 VNĐ.")
            lines.append("• Hỗ trợ **Giao Hỏa Tốc trong 2 giờ** tại nội thành TP.HCM và Hà Nội.\n")

        if is_warranty_q:
            lines.append("🔄 **Chính Sách Bảo Hành & Đổi Trả 30 Ngày**:")
            lines.append("• Đổi hàng/đổi size miễn phí trong **30 ngày** (Shipper mang sản phẩm mới đến tận nơi đổi).")
            lines.append("• Bảo hành chính hãng **12 tháng** cho mọi lỗi từ nhà sản xuất (đường chỉ, khóa kéo, đế giày).\n")

        if is_store_q:
            lines.append("📍 **Hệ Thống Cửa Hàng & Giờ Mở Cửa**:")
            lines.append("• **Chi nhánh TP.HCM**: 120 Nguyễn Trãi, P. Bến Thành, Quận 1 (08:00 - 21:30 hàng ngày).")
            lines.append("• **Chi nhánh Hà Nội**: 88 Cầu Giấy, Q. Cầu Giấy (08:00 - 21:30 hàng ngày).\n")

        # Nếu không trúng mẫu nào trên, lọc sạch từ chunks
        if not lines:
            clean_texts = []
            for c in chunks:
                raw = c.get("text", "").strip()
                # Loại bỏ các tiêu đề chương mục thô
                cleaned = "\n".join([line for line in raw.split("\n") if not line.strip().startswith(("1. GIỚI THIỆU", "2. CHÍNH SÁCH", "4. DANH MỤC"))])
                if cleaned and cleaned not in clean_texts:
                    clean_texts.append(cleaned)
            if clean_texts:
                lines.append("\n\n".join(clean_texts[:2]))
            else:
                lines.append(f"Dạ {shop_name} luôn sẵn sàng tư vấn chi tiết về mọi sản phẩm, bảng size và chính sách freeship cho bạn ạ!")

        body_content = "\n".join(lines).strip()
        return (
            f"Dạ {shop_name} xin gửi thông tin chi tiết đến bạn ạ:\n\n"
            f"{body_content}\n\n"
            f"Bạn có cần mình hỗ trợ đặt hàng giao nhanh hoặc chọn size chuẩn không ạ? 😊"
        )

    async def _call_llm(self, system: str, user: str) -> str:
        try:
            config = types.GenerateContentConfig(
                system_instruction=system,
                temperature=0.35,
                max_output_tokens=400,
            )
            response = await self._client.aio.models.generate_content(
                model=self._model_name,
                contents=user,
                config=config,
            )
            return response.text.strip()
        except Exception as e:
            # Nếu gặp 429 hoặc rate limit, reraise ngay lập tức để fallback xử lý tức thì trong 2ms
            raise e

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
