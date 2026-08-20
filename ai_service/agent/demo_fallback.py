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
    "We are sorry about this experience. Your conversation has been transferred "
    "to a SportGear support agent, who will review the issue and help with the "
    "return or resolution shortly."
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
            "live agent", "human agent", "support agent", "speak to someone",
            "manager", "representative",
            "gap nhan vien", "gap nguoi", "tu van vien", "nhan vien cskh",
            "human", "agent", "goi quan ly", "gap quan ly",
        ]
        complaint_keywords = [
            "torn", "defective", "damaged", "broken", "wrong item",
            "missing item", "not received", "late delivery", "refund",
            "angry", "scam", "lawsuit", "police", "fix this now",
            "bi rach", "hang loi", "bi loi", "hu hong", "giao sai",
            "thieu hang", "chua nhan", "giao lau", "hoan tien", "buc minh",
            "lua dao", "kien", "bao cong an", "xu ly ngay",
        ]
        has_phrase = any(k in norm for k in handoff_keywords + complaint_keywords)
        has_hong_word = re.search(r"(^|\\s)hong($|\\s|[.!?,])", norm) is not None
        return has_phrase or has_hong_word

    @staticmethod
    def _faq_reply(norm: str) -> str:
        lines: list[str] = ["Here is the relevant SportGear information:"]

        if any(k in norm for k in ["polo", "pro active", "sports polo", "ao polo", "ao the thao"]):
            lines.extend([
                "",
                "The Polo Pro Active is 320,000 VND (regular price 400,000 VND).",
                "It uses breathable honeycomb pique with four-way stretch and wrinkle resistance.",
                "Sizes: S 50–60 kg, M 61–68 kg, L 69–76 kg, XL 77–85 kg, XXL over 85 kg.",
            ])

        if any(k in norm for k in ["ultra boost", "shoe", "shoes", "giay", "boost"]):
            lines.extend([
                "",
                "The Ultra Boost 2026 Running Shoes are 1,250,000 VND.",
                "Sizes 38–44 are available, with at-home size exchanges if the fit is not right.",
            ])

        if any(k in norm for k in ["size", "height", "weight", "fit", "chieu cao", "can nang", "kg", "vua"]):
            lines.extend([
                "",
                "For a body weight around 69–76 kg, SportGear tops generally fit best in size L.",
                "If you are between sizes, choose the larger size for more comfortable movement.",
            ])

        if any(k in norm for k in ["free shipping", "freeship", "shipping", "delivery", "ship", "van chuyen", "giao hang", "hoa toc"]):
            lines.extend([
                "",
                "Orders of 500,000 VND or more receive free nationwide shipping.",
                "Orders below 500,000 VND have a flat 25,000 VND shipping fee.",
                "Two-hour express delivery is available in central Ho Chi Minh City and Hanoi.",
            ])

        if any(k in norm for k in ["return", "exchange", "warranty", "doi tra", "bao hanh", "doi size", "tra hang"]):
            lines.extend([
                "",
                "Size and model exchanges are free within 30 days when the original tags remain attached.",
                "Products include a 12-month warranty for technical defects such as seams, zippers, and soles.",
            ])

        if any(k in norm for k in ["address", "location", "store", "opening hours", "dia chi", "chi nhanh", "mo cua", "o dau", "cua hang"]):
            lines.extend([
                "",
                "Ho Chi Minh City store: 120 Nguyen Trai Street, District 1, open 08:00–21:30.",
                "Hanoi store: 88 Cau Giay Street, open 08:00–21:30.",
            ])

        if len(lines) == 1:
            lines.extend([
                "",
                "I can help with prices, sizes, shipping, returns, warranties, and product availability.",
                "Tell me which product you are considering or how you plan to use it for a more specific recommendation.",
            ])

        lines.append("")
        lines.append("Would you like help choosing a size or arranging fast delivery?")
        return "\n".join(lines)


def create_demo_fallback_orchestrator() -> DemoFallbackOrchestrator:
    return DemoFallbackOrchestrator()
