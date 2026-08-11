from uuid import UUID

from fastapi import APIRouter, Body, Depends, HTTPException, Query, status

from app.core.security import AuthenticatedUser, require_agent_or_super_admin
from app.db.supabase import get_supabase_client
from app.schemas.common import ChannelType, SenderType, TicketStatus, UserRole, UserStatus
from app.schemas.messages import HumanMessageCreate, MessageCreate as MessageServiceCreate
from app.schemas.tickets import TicketAssign, TicketUpdate
from app.schemas.users import UserRead
from app.services.exceptions import InvalidTicketTransitionError, RecordNotFoundError
from app.services.messages import MessageService
from app.services.outbound import OutboundDeliveryError, OutboundRouter, get_outbound_router
from app.services.supabase_table import SupabaseClient
from app.services.tickets import TicketService


router = APIRouter(prefix="/tickets", tags=["tickets"])


def _as_user_read(current_user: AuthenticatedUser) -> UserRead:
    return UserRead(
        id=UUID(current_user.id),
        email=current_user.email or "",
        full_name="",
        role=UserRole(current_user.role),
        status=UserStatus(current_user.status),
        created_at="1970-01-01T00:00:00+00:00",
        updated_at="1970-01-01T00:00:00+00:00",
    )


def _is_visible(ticket: dict, current_user: AuthenticatedUser) -> bool:
    if current_user.role == UserRole.SUPER_ADMIN:
        return True
    return ticket.get("status") == TicketStatus.OPEN or str(ticket.get("assigned_to")) == current_user.id


def _get_visible_ticket(
    service: TicketService,
    ticket_id: str,
    current_user: AuthenticatedUser,
) -> dict:
    try:
        ticket = service.get_ticket(ticket_id)
    except RecordNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Ticket not found") from exc
    if not _is_visible(ticket, current_user):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Ticket is not visible to this user")
    return ticket


@router.get("")
async def list_tickets(
    status_filter: TicketStatus | None = Query(default=None, alias="status"),
    source: ChannelType | None = None,
    assigned_to: UUID | None = None,
    search: str | None = None,
    limit: int = Query(default=20, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    current_user: AuthenticatedUser = Depends(require_agent_or_super_admin),
    client: SupabaseClient = Depends(get_supabase_client),
) -> dict:
    service = TicketService(client)
    items = service.list_visible_tickets(
        _as_user_read(current_user),
        status=status_filter,
        source=source,
        assigned_to=str(assigned_to) if assigned_to else None,
        search=search,
        limit=limit,
        offset=offset,
    )
    return {"items": items, "limit": limit, "offset": offset, "count": len(items)}


@router.get("/{ticket_id}")
async def get_ticket(
    ticket_id: str,
    current_user: AuthenticatedUser = Depends(require_agent_or_super_admin),
    client: SupabaseClient = Depends(get_supabase_client),
) -> dict:
    return _get_visible_ticket(TicketService(client), ticket_id, current_user)


@router.patch("/{ticket_id}")
async def update_ticket(
    ticket_id: str,
    payload: TicketUpdate,
    current_user: AuthenticatedUser = Depends(require_agent_or_super_admin),
    client: SupabaseClient = Depends(get_supabase_client),
) -> dict:
    service = TicketService(client)
    _get_visible_ticket(service, ticket_id, current_user)
    return service.update_ticket(ticket_id, payload)


@router.post("/{ticket_id}/assign")
async def assign_ticket(
    ticket_id: str,
    payload: TicketAssign,
    current_user: AuthenticatedUser = Depends(require_agent_or_super_admin),
    client: SupabaseClient = Depends(get_supabase_client),
) -> dict:
    service = TicketService(client)
    _get_visible_ticket(service, ticket_id, current_user)
    return service.update_ticket(ticket_id, TicketUpdate(assigned_to=payload.assigned_to))


@router.post("/{ticket_id}/resolve")
async def resolve_ticket(
    ticket_id: str,
    current_user: AuthenticatedUser = Depends(require_agent_or_super_admin),
    client: SupabaseClient = Depends(get_supabase_client),
) -> dict:
    service = TicketService(client)
    _get_visible_ticket(service, ticket_id, current_user)
    try:
        return service.resolve_ticket(ticket_id)
    except InvalidTicketTransitionError as exc:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(exc)) from exc


@router.post("/{ticket_id}/reopen")
async def reopen_ticket(
    ticket_id: str,
    current_user: AuthenticatedUser = Depends(require_agent_or_super_admin),
    client: SupabaseClient = Depends(get_supabase_client),
) -> dict:
    service = TicketService(client)
    _get_visible_ticket(service, ticket_id, current_user)
    try:
        return service.reopen_ticket(ticket_id)
    except InvalidTicketTransitionError as exc:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(exc)) from exc


@router.get("/{ticket_id}/messages")
async def list_ticket_messages(
    ticket_id: str,
    current_user: AuthenticatedUser = Depends(require_agent_or_super_admin),
    client: SupabaseClient = Depends(get_supabase_client),
) -> dict:
    _get_visible_ticket(TicketService(client), ticket_id, current_user)
    messages = MessageService(client).list_ticket_messages(ticket_id)
    return {"items": messages, "count": len(messages)}


@router.post("/{ticket_id}/messages", status_code=status.HTTP_201_CREATED)
async def create_human_message(
    ticket_id: str,
    payload: HumanMessageCreate = Body(..., embed=False),
    current_user: AuthenticatedUser = Depends(require_agent_or_super_admin),
    client: SupabaseClient = Depends(get_supabase_client),
    outbound_router: OutboundRouter = Depends(get_outbound_router),
) -> dict:
    ticket = _get_visible_ticket(TicketService(client), ticket_id, current_user)
    message = MessageService(client).create_message(
        payload=MessageServiceCreate(
            ticket_id=UUID(ticket_id),
            sender_type=SenderType.HUMAN,
            sender_id=current_user.id,
            content=payload.content,
        )
    )
    try:
        outbound = outbound_router.send_reply(ticket, message)
    except OutboundDeliveryError as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Message saved but outbound delivery failed: {exc}",
        ) from exc
    return {"message": message, "outbound": outbound.__dict__}
