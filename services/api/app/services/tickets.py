from datetime import UTC, datetime
from typing import Any

from app.schemas.common import ChannelType, TicketStatus, UserRole
from app.schemas.tickets import TicketCreate, TicketUpdate
from app.schemas.users import UserRead
from app.services.exceptions import InvalidTicketTransitionError
from app.services.supabase_table import SupabaseClient, TableService, first_record


ALLOWED_TRANSITIONS: dict[TicketStatus, set[TicketStatus]] = {
    TicketStatus.OPEN: {TicketStatus.IN_PROGRESS, TicketStatus.RESOLVED},
    TicketStatus.IN_PROGRESS: {TicketStatus.RESOLVED},
    TicketStatus.PENDING: {TicketStatus.RESOLVED},
    TicketStatus.RESOLVED: {TicketStatus.OPEN},
}


class TicketService(TableService):
    def __init__(self, client: SupabaseClient) -> None:
        super().__init__(client, "tickets")

    def create_ticket(self, payload: TicketCreate) -> dict[str, Any]:
        return self.create(payload)

    def find_open_or_pending_ticket(self, customer_id: str, source: ChannelType) -> dict[str, Any] | None:
        result = self.client.table(self.table_name).select("*").execute()
        for ticket in result.data or []:
            if (
                ticket.get("customer_id") == customer_id
                and ticket.get("source") == source
                and ticket.get("status") in {TicketStatus.OPEN, TicketStatus.PENDING}
            ):
                return ticket
        return None

    def get_ticket(self, ticket_id: str) -> dict[str, Any]:
        return self.get(ticket_id)

    def update_ticket(self, ticket_id: str, payload: TicketUpdate) -> dict[str, Any]:
        return self.update(ticket_id, payload)

    def list_visible_tickets(
        self,
        user: UserRead,
        *,
        status: TicketStatus | None = None,
        source: ChannelType | None = None,
        assigned_to: str | None = None,
        search: str | None = None,
        limit: int = 20,
        offset: int = 0,
    ) -> list[dict[str, Any]]:
        query = self.client.table(self.table_name).select("*").order("created_at", desc=True)
        if user.role == UserRole.AGENT:
            query = query.or_(f"assigned_to.eq.{user.id},status.eq.open")
        result = query.execute()
        rows = result.data or []
        if status:
            rows = [row for row in rows if row.get("status") == status]
        if source:
            rows = [row for row in rows if row.get("source") == source]
        if assigned_to:
            rows = [row for row in rows if str(row.get("assigned_to")) == assigned_to]
        if search:
            needle = search.casefold()
            rows = [
                row
                for row in rows
                if needle in str(row.get("customer_name") or "").casefold()
                or needle in str(row.get("summary") or "").casefold()
                or needle in str(row.get("customer_id") or "").casefold()
            ]
        return rows[offset : offset + limit]

    def transition_ticket(self, ticket_id: str, target_status: TicketStatus) -> dict[str, Any]:
        ticket = self.get_ticket(ticket_id)
        current_status = TicketStatus(ticket["status"])
        if target_status not in ALLOWED_TRANSITIONS.get(current_status, set()):
            raise InvalidTicketTransitionError(
                f"Cannot transition ticket {ticket_id} from {current_status} to {target_status}"
            )

        values: dict[str, Any] = {"status": target_status.value}
        if target_status == TicketStatus.RESOLVED:
            values["resolved_at"] = datetime.now(UTC).isoformat()
        elif target_status == TicketStatus.OPEN:
            values["resolved_at"] = None

        result = self.client.table(self.table_name).update(values).eq("id", ticket_id).execute()
        return first_record(result.data, self.table_name, ticket_id)

    def start_progress(self, ticket_id: str) -> dict[str, Any]:
        return self.transition_ticket(ticket_id, TicketStatus.IN_PROGRESS)

    def resolve_ticket(self, ticket_id: str) -> dict[str, Any]:
        return self.transition_ticket(ticket_id, TicketStatus.RESOLVED)

    def reopen_ticket(self, ticket_id: str) -> dict[str, Any]:
        return self.transition_ticket(ticket_id, TicketStatus.OPEN)
