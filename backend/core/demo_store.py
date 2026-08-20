from __future__ import annotations

from datetime import datetime, timezone
from threading import Lock
from typing import Any
from uuid import uuid4


_LOCK = Lock()
_TICKETS: dict[str, dict[str, Any]] = {}
_MESSAGES: dict[str, list[dict[str, Any]]] = {}


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _message(ticket_id: str, sender_type: str, sender_id: str, content: str) -> dict[str, Any]:
    return {
        "id": str(uuid4()),
        "ticket_id": ticket_id,
        "sender_type": sender_type,
        "sender_id": sender_id,
        "content": content,
        "created_at": _now(),
    }


def _ticket(
    *,
    customer_id: str,
    customer_name: str,
    source: str,
    status: str,
    intent: str,
    summary: str,
) -> dict[str, Any]:
    timestamp = _now()
    return {
        "id": str(uuid4()),
        "customer_id": customer_id,
        "customer_name": customer_name,
        "source": source,
        "status": status,
        "intent": intent,
        "summary": summary,
        "context_summary": summary,
        "created_at": timestamp,
        "updated_at": timestamp,
        "resolved_at": None,
    }


def _ensure_seeded() -> None:
    if _TICKETS:
        return

    samples = [
        {
            "customer_id": "demo_web_customer",
            "customer_name": "Khách Hàng Web (SportGear Store)",
            "source": "web",
            "status": "open",
            "intent": "complaint",
            "summary": "Sản phẩm áo Polo bị lỗi rách chỉ ở nách, khách yêu cầu đổi ngay trong ngày.",
            "messages": [
                ("customer", "demo_web_customer", "Chào shop, áo Polo Pro Active mình mới nhận bị rách chỉ ở phần nách, shop đổi mới giúp mình nhé!"),
                ("bot", "ai-bot", "Dạ SportGear rất tiếc về sự cố này ạ! Em đã chuyển ticket cho nhân viên CSKH hỗ trợ đổi mới tận nhà miễn phí trong 30 ngày."),
            ],
        },
        {
            "customer_id": "demo_facebook_customer",
            "customer_name": "Nguyễn Văn Tuấn (Facebook)",
            "source": "facebook",
            "status": "in_progress",
            "intent": "question",
            "summary": "Tư vấn chọn size giày chạy bộ Ultra Boost 2026 cho người chân bè.",
            "messages": [
                ("customer", "demo_facebook_customer", "Giày Ultra Boost 2026 chân bè ngang 10cm thì nên đi size 42 hay 43 shop?"),
                ("bot", "ai-bot", "Dạ với form chân bè ngang, bạn nên tăng 1 size lên 43 để chạy bộ thoải mái hơn ạ."),
            ],
        },
        {
            "customer_id": "demo_email_customer",
            "customer_name": "Trần Thị Mai (Email)",
            "source": "email",
            "status": "open",
            "intent": "question",
            "summary": "Hỏi điều kiện miễn phí vận chuyển toàn quốc và mã giảm giá đơn 1 triệu.",
            "messages": [
                ("customer", "demo_email_customer", "Shop cho mình hỏi đơn hàng trên 1 triệu có được freeship và tặng quà gì không?"),
                ("bot", "ai-bot", "Dạ mọi đơn hàng từ 500.000đ đều được FREESHIP 100% toàn quốc. Đơn từ 1.000.000đ shop tặng thêm bình giữ nhiệt ạ."),
            ],
        },
    ]

    for sample in samples:
        ticket = _ticket(
            customer_id=sample["customer_id"],
            customer_name=sample["customer_name"],
            source=sample["source"],
            status=sample["status"],
            intent=sample["intent"],
            summary=sample["summary"],
        )
        _TICKETS[ticket["id"]] = ticket
        _MESSAGES[ticket["id"]] = [
            _message(ticket["id"], sender, sender_id, content)
            for sender, sender_id, content in sample["messages"]
        ]


def list_tickets() -> list[dict[str, Any]]:
    with _LOCK:
        _ensure_seeded()
        return sorted(_TICKETS.values(), key=lambda item: item["created_at"], reverse=True)


def dashboard_stats() -> dict[str, Any]:
    with _LOCK:
        _ensure_seeded()
        tickets = list(_TICKETS.values())
        total = len(tickets)
        open_count = sum(1 for ticket in tickets if ticket["status"] in {"open", "pending"})
        in_progress = sum(1 for ticket in tickets if ticket["status"] == "in_progress")
        resolved = sum(1 for ticket in tickets if ticket["status"] == "resolved")
        question_count = sum(1 for ticket in tickets if ticket.get("intent") in {"question", None})
        channels = {
            "web": sum(1 for ticket in tickets if ticket["source"] == "web"),
            "facebook": sum(1 for ticket in tickets if ticket["source"] == "facebook"),
            "email": sum(1 for ticket in tickets if ticket["source"] == "email"),
        }
        return {
            "total_tickets": max(total, 1),
            "open_tickets": open_count,
            "in_progress_tickets": in_progress,
            "resolved_tickets": resolved,
            "ai_handled_percent": round((question_count / total * 100) if total else 91.5, 1),
            "avg_response_time": "0.4s",
            "satisfaction_score": "4.9/5.0",
            "saved_salary": f"{max(6, int(total * 1.8))}.500.000đ/tháng",
            "estimated_revenue": f"{max(12, total * 3.5):.1f}.000.000đ",
            "channels": channels,
        }


def get_ticket_detail(ticket_id: str) -> dict[str, Any] | None:
    with _LOCK:
        _ensure_seeded()
        ticket = _TICKETS.get(ticket_id)
        if not ticket:
            return None
        return {"ticket": ticket, "messages": list(_MESSAGES.get(ticket_id, []))}


def create_or_reuse_ticket(
    *,
    customer_id: str,
    customer_name: str | None,
    source: str,
    content: str,
) -> str:
    with _LOCK:
        _ensure_seeded()
        for ticket in sorted(_TICKETS.values(), key=lambda item: item["created_at"], reverse=True):
            if (
                ticket["customer_id"] == customer_id
                and ticket["source"] == source
                and ticket["status"] in {"open", "in_progress"}
            ):
                ticket["summary"] = content[:120]
                ticket["context_summary"] = content[:120]
                ticket["updated_at"] = _now()
                return ticket["id"]

        ticket = _ticket(
            customer_id=customer_id,
            customer_name=customer_name or "Khách Hàng SportGear",
            source=source,
            status="open",
            intent="question",
            summary=content[:120],
        )
        _TICKETS[ticket["id"]] = ticket
        _MESSAGES[ticket["id"]] = []
        return ticket["id"]


def add_message(ticket_id: str, sender_type: str, sender_id: str, content: str) -> dict[str, Any]:
    with _LOCK:
        _ensure_seeded()
        msg = _message(ticket_id, sender_type, sender_id, content)
        _MESSAGES.setdefault(ticket_id, []).append(msg)
        if ticket_id in _TICKETS:
            _TICKETS[ticket_id]["updated_at"] = msg["created_at"]
        return msg


def add_bot_reply_once(ticket_id: str, content: str) -> bool:
    text = content.strip()
    if not text:
        return False
    with _LOCK:
        _ensure_seeded()
        existing = any(
            msg["sender_type"] == "bot" and msg["content"].strip() == text
            for msg in _MESSAGES.get(ticket_id, [])
        )
        if existing:
            return False
    add_message(ticket_id, "bot", "ai-bot", text)
    return True


def update_ticket(ticket_id: str, **updates: Any) -> dict[str, Any] | None:
    with _LOCK:
        _ensure_seeded()
        ticket = _TICKETS.get(ticket_id)
        if not ticket:
            return None
        ticket.update(updates)
        ticket["updated_at"] = _now()
        if updates.get("status") == "resolved" and not ticket.get("resolved_at"):
            ticket["resolved_at"] = _now()
        return ticket


def fallback_ai_reply(content: str) -> tuple[str, str, str]:
    text = content.lower()
    if any(keyword in text for keyword in ["rách", "rach", "bị lỗi", "bi loi", "bực", "buc", "xử lý ngay", "xu ly ngay"]):
        return (
            "HANDOFF",
            "complaint",
            "Dạ SportGear rất xin lỗi vì trải nghiệm này ạ. Em đã chuyển ticket cho nhân viên CSKH xử lý ngay và hỗ trợ đổi mới miễn phí cho mình.",
        )
    if any(keyword in text for keyword in ["polo", "pro active", "size l", "áo", "ao"]):
        return (
            "ANSWER",
            "question",
            "Dạ Áo Polo Pro Active hiện có giá 399.000đ, đang đủ size M/L/XL. Size L phù hợp khoảng 65-75kg và được đổi size miễn phí trong 30 ngày ạ.",
        )
    if any(keyword in text for keyword in ["freeship", "free ship", "ship", "vận chuyển", "van chuyen"]):
        return (
            "ANSWER",
            "question",
            "Dạ SportGear freeship toàn quốc cho đơn từ 500.000đ. Đơn dưới 500.000đ phí ship đồng giá 25.000đ, nội thành có hỗ trợ giao hỏa tốc 2 giờ ạ.",
        )
    return (
        "ANSWER",
        "question",
        "Dạ SportGear đã nhận tin nhắn của bạn. Em có thể hỗ trợ thông tin sản phẩm, size, freeship, đổi trả và bảo hành ạ.",
    )
