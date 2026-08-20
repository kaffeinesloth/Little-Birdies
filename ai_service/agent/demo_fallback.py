"""
Deterministic fallback replies for class demos.

This module is intentionally small and only covers the public SportGear demo
flow. The real LLM/RAG orchestrator remains the primary path when it can be
constructed and run successfully.
"""
from __future__ import annotations

import unicodedata
import re

from agent.schemas import ConvState, OrchestratorAction, ProcessResult


def _normalize(text: str) -> str:
    stripped = "".join(
        c for c in unicodedata.normalize("NFD", text)
        if unicodedata.category(c) != "Mn"
    )
    return stripped.replace("đ", "d").replace("Đ", "D").lower()


_HANDOFF_REPLY = (
    "Dạ SportGear rất xin lỗi vì trải nghiệm chưa tốt này. "
    "Mình đã chuyển ngay cuộc trò chuyện cho nhân viên CSKH để kiểm tra và "
    "hỗ trợ đổi trả/xử lý cho bạn trong ít phút ạ."
)


class DemoFallbackOrchestrator:
    async def process(
        self,
        tenant_id: str,
        conversation_id: str,
        message: str,
        channel: str = "web",
        external_id: str | None = None,
    ) -> ProcessResult:
        norm = _normalize(message)

        if self._needs_handoff(norm):
            return ProcessResult(
                reply=_HANDOFF_REPLY,
                state=ConvState.HUMAN_HANDLING,
                action=OrchestratorAction.HANDOFF,
                metadata={"fallback": True},
            )

        return ProcessResult(
            reply=self._faq_reply(norm),
            state=ConvState.AI_HANDLING,
            action=OrchestratorAction.NONE,
            metadata={"fallback": True},
        )

    @staticmethod
    def _needs_handoff(norm: str) -> bool:
        handoff_keywords = [
            "gap nhan vien", "gap nguoi", "tu van vien", "nhan vien cskh",
            "human", "agent", "goi quan ly", "gap quan ly",
        ]
        complaint_keywords = [
            "bi rach", "hang loi", "bi loi", "hu hong", "giao sai",
            "thieu hang", "chua nhan", "giao lau", "hoan tien", "buc minh",
            "lua dao", "kien", "bao cong an", "xu ly ngay",
        ]
        has_phrase = any(k in norm for k in handoff_keywords + complaint_keywords)
        has_hong_word = re.search(r"(^|\\s)hong($|\\s|[.!?,])", norm) is not None
        return has_phrase or has_hong_word

    @staticmethod
    def _faq_reply(norm: str) -> str:
        lines: list[str] = ["Dạ SportGear xin gửi bạn thông tin nhanh ạ:"]

        if any(k in norm for k in ["polo", "pro active", "ao polo", "ao the thao"]):
            lines.extend([
                "",
                "Áo Polo Thể Thao Pro Active hiện có giá 320.000đ (giá gốc 400.000đ).",
                "Chất liệu thun cá sấu dệt tổ ong thoáng khí, co giãn 4 chiều, chống nhăn.",
                "Size: S 50-60kg, M 61-68kg, L 69-76kg, XL 77-85kg, XXL trên 85kg.",
            ])

        if any(k in norm for k in ["ultra boost", "giay", "boost"]):
            lines.extend([
                "",
                "Giày Chạy Bộ Ultra Boost 2026 hiện có giá 1.250.000đ.",
                "Shop có size 38-44 và hỗ trợ đổi size tận nhà nếu chưa vừa.",
            ])

        if any(k in norm for k in ["size", "chieu cao", "can nang", "kg", "vua"]):
            lines.extend([
                "",
                "Nếu bạn khoảng 69-76kg thì áo SportGear thường hợp size L.",
                "Nếu phân vân giữa 2 size, shop khuyên chọn size lớn hơn để vận động thoải mái.",
            ])

        if any(k in norm for k in ["freeship", "ship", "van chuyen", "giao hang", "hoa toc"]):
            lines.extend([
                "",
                "Đơn từ 500.000đ được freeship toàn quốc.",
                "Đơn dưới 500.000đ ship đồng giá 25.000đ.",
                "Nội thành TP.HCM và Hà Nội có giao hỏa tốc trong 2 giờ.",
            ])

        if any(k in norm for k in ["doi tra", "bao hanh", "doi size", "tra hang"]):
            lines.extend([
                "",
                "Shop hỗ trợ đổi size/đổi mẫu miễn phí trong 30 ngày nếu sản phẩm còn nguyên tem mác.",
                "Sản phẩm được bảo hành 12 tháng cho lỗi kỹ thuật như đường chỉ, khóa kéo, đế giày.",
            ])

        if any(k in norm for k in ["dia chi", "chi nhanh", "mo cua", "o dau", "cua hang"]):
            lines.extend([
                "",
                "Chi nhánh TP.HCM: 120 Nguyễn Trãi, Quận 1, mở cửa 08:00-21:30.",
                "Chi nhánh Hà Nội: 88 Cầu Giấy, mở cửa 08:00-21:30.",
            ])

        if len(lines) == 1:
            lines.extend([
                "",
                "Shop có thể tư vấn giá, size, freeship, đổi trả, bảo hành và tình trạng sản phẩm.",
                "Bạn cho mình biết mẫu sản phẩm hoặc nhu cầu sử dụng để mình tư vấn sát hơn nhé.",
            ])

        lines.append("")
        lines.append("Bạn cần mình hỗ trợ chọn size hoặc tạo đơn giao nhanh không ạ?")
        return "\n".join(lines)


def create_demo_fallback_orchestrator() -> DemoFallbackOrchestrator:
    return DemoFallbackOrchestrator()
