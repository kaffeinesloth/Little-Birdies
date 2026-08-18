"""
services/ticket.py — Tạo và quản lý tickets trong Supabase.
"""
from __future__ import annotations

import logging

import db.queries as q

logger = logging.getLogger(__name__)


class TicketService:
    def __init__(self, db):
        self._db = db

    async def create(
        self,
        tenant_id:       str,
        conversation_id: str,
        channel:         str,
        intent:          str,
        urgency:         int,
        customer_message: str,
        context_summary: str = "",
    ) -> dict:
        norm_intent = "complaint" if str(intent).upper() in ["COMPLAINT", "ANGRY", "ESCALATION_REQ"] else "question"
        norm_source = channel if channel in ["web", "facebook", "email"] else "web"
        ticket = await q.create_ticket(self._db, {
            "customer_id":      conversation_id,
            "customer_name":    "Khách Hàng",
            "source":           norm_source,
            "intent":           norm_intent,
            "summary":          context_summary[:500] if context_summary else customer_message[:500],
        })
        logger.info(
            "Ticket created: id=%s urgency=%d intent=%s",
            ticket.get("id"), urgency, intent,
        )
        return ticket

    async def resolve(self, ticket_id: str, agent_id: str | None = None) -> None:
        await q.update_ticket_status(self._db, ticket_id, "RESOLVED", agent_id)

    async def assign(self, ticket_id: str, agent_id: str) -> None:
        await q.update_ticket_status(self._db, ticket_id, "IN_PROGRESS", agent_id)

    async def get_open(self, tenant_id: str) -> list[dict]:
        return await q.get_open_tickets(self._db, tenant_id)
