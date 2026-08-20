from __future__ import annotations

from datetime import datetime, timezone
import re
from threading import Lock
from typing import Any
import unicodedata
from uuid import uuid4


_LOCK = Lock()
_TICKETS: dict[str, dict[str, Any]] = {}
_MESSAGES: dict[str, list[dict[str, Any]]] = {}


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _normalize(value: str) -> str:
    stripped = "".join(
        character
        for character in unicodedata.normalize("NFD", value)
        if unicodedata.category(character) != "Mn"
    )
    return stripped.replace("đ", "d").replace("Đ", "D").lower()


def _contains_phrase(text: str, phrases: list[str]) -> bool:
    return any(
        re.search(rf"(?<!\w){re.escape(phrase)}(?!\w)", text) is not None
        for phrase in phrases
    )


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
            "customer_name": "Web Customer (SportGear Store)",
            "source": "web",
            "status": "open",
            "intent": "complaint",
            "summary": "The Polo arrived with a torn underarm seam; the customer requests a same-day replacement.",
            "messages": [
                ("customer", "demo_web_customer", "Hi, my new Polo Pro Active arrived with a torn underarm seam. Could you replace it?"),
                ("bot", "ai-bot", "We are sorry about that. The ticket was transferred to a support agent for a free at-home replacement under the 30-day policy."),
            ],
        },
        {
            "customer_id": "demo_facebook_customer",
            "customer_name": "Tuan Nguyen (Facebook)",
            "source": "facebook",
            "status": "in_progress",
            "intent": "question",
            "summary": "Size advice for Ultra Boost 2026 running shoes for wide feet.",
            "messages": [
                ("customer", "demo_facebook_customer", "For 10 cm wide feet, should I choose size 42 or 43 in the Ultra Boost 2026?"),
                ("bot", "ai-bot", "For wide feet, we recommend sizing up to 43 for more comfort while running."),
            ],
        },
        {
            "customer_id": "demo_email_customer",
            "customer_name": "Mai Tran (Email)",
            "source": "email",
            "status": "open",
            "intent": "question",
            "summary": "Asked about free nationwide shipping and promotions for a 1,000,000 VND order.",
            "messages": [
                ("customer", "demo_email_customer", "Does an order over 1,000,000 VND include free shipping or a gift?"),
                ("bot", "ai-bot", "Orders from 500,000 VND receive free nationwide shipping. Orders from 1,000,000 VND also include an insulated bottle."),
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
            "saved_salary": f"{max(6, int(total * 1.8))},500,000 VND/month",
            "estimated_revenue": f"{max(12, total * 3.5):.1f} million VND",
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
            customer_name=customer_name or "SportGear Customer",
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


def delete_resolved_ticket(ticket_id: str) -> str:
    """Delete a resolved demo ticket and all of its messages."""
    with _LOCK:
        _ensure_seeded()
        ticket = _TICKETS.get(ticket_id)
        if not ticket:
            return "not_found"
        if ticket.get("status") != "resolved":
            return "not_resolved"
        del _TICKETS[ticket_id]
        _MESSAGES.pop(ticket_id, None)
        return "deleted"


def fallback_ai_reply(content: str) -> tuple[str, str, str]:
    text = _normalize(content)
    if _contains_phrase(text, ["torn", "defective", "damaged", "fix this now", "rach", "bi loi", "buc", "xu ly ngay"]):
        return (
            "HANDOFF",
            "complaint",
            "We are sorry about this experience. The ticket was transferred to a support agent for immediate review and a free replacement where eligible.",
        )
    if _contains_phrase(text, ["polo", "pro active", "size l", "ao"]):
        return (
            "ANSWER",
            "question",
            "The Polo Pro Active is 399,000 VND and is available in M, L, and XL. Size L suits approximately 65–75 kg, with free size exchanges within 30 days.",
        )
    if _contains_phrase(text, ["ultra boost", "shoe", "shoes", "giay", "boost"]):
        return (
            "ANSWER",
            "question",
            "The Ultra Boost 2026 Running Shoes are 1,250,000 VND, available in sizes 38–44, with at-home size exchanges.",
        )
    if _contains_phrase(text, ["free shipping", "freeship", "free ship", "shipping", "ship", "van chuyen"]):
        return (
            "ANSWER",
            "question",
            "SportGear provides free nationwide shipping from 500,000 VND. Below that amount, shipping is 25,000 VND, with two-hour delivery available in central city areas.",
        )
    return (
        "ANSWER",
        "question",
        "SportGear received your message. I can help with products, sizing, shipping, returns, and warranties.",
    )
