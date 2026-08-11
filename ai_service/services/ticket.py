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
        ticket = await q.create_ticket(self._db, {
            "tenant_id":        tenant_id,
            "conversation_id":  conversation_id,
            "channel":          channel,
            "intent":           intent,
            "urgency":          urgency,
            "customer_message": customer_message[:1000],
            "context_summary":  context_summary[:2000],
        })
        logger.info(
            "Ticket created: id=%s urgency=%d intent=%s",
            ticket["id"], urgency, intent,
        )
        return ticket

    async def resolve(self, ticket_id: str, agent_id: str | None = None) -> None:
        await q.update_ticket_status(self._db, ticket_id, "RESOLVED", agent_id)

    async def assign(self, ticket_id: str, agent_id: str) -> None:
        await q.update_ticket_status(self._db, ticket_id, "IN_PROGRESS", agent_id)

    async def get_open(self, tenant_id: str) -> list[dict]:
        return await q.get_open_tickets(self._db, tenant_id)
