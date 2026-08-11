from datetime import UTC, datetime
from uuid import uuid4

import pytest
from pydantic import ValidationError

from app.schemas import (
    ChannelCreate,
    ChannelType,
    DocumentCreate,
    DocumentFileType,
    MessageCreate,
    NotificationCreate,
    SenderType,
    TicketCreate,
    TicketStatus,
    UserCreate,
    UserRead,
    UserRole,
    UserStatus,
    UserUpdate,
)
from app.services import (
    ChannelService,
    DocumentService,
    MessageService,
    NotificationService,
    TicketService,
    UserService,
)
from app.services.exceptions import InvalidTicketTransitionError
from tests.fakes import FakeSupabase


def user_read(user_id: str, role: UserRole) -> UserRead:
    now = datetime.now(UTC)
    return UserRead(
        id=user_id,
        email="agent@example.com",
        full_name="Agent",
        role=role,
        status=UserStatus.ONLINE,
        created_at=now,
        updated_at=now,
    )


def test_core_table_services_create_read_update_records() -> None:
    client = FakeSupabase()
    user_id = uuid4()

    created_user = UserService(client).create_user(
        UserCreate(
            id=user_id,
            email="owner@example.com",
            full_name="Owner",
            role=UserRole.SUPER_ADMIN,
        )
    )
    assert created_user["email"] == "owner@example.com"
    assert UserService(client).get_user(created_user["id"])["id"] == created_user["id"]

    updated_user = UserService(client).update_user(
        created_user["id"],
        payload=UserUpdate(full_name="Shop Owner"),
    )
    assert updated_user["full_name"] == "Shop Owner"

    ticket = TicketService(client).create_ticket(
        TicketCreate(customer_id="cust-1", source=ChannelType.WEB)
    )
    message = MessageService(client).create_message(
        MessageCreate(
            ticket_id=ticket["id"],
            sender_type=SenderType.CUSTOMER,
            sender_id="cust-1",
            content="What is the shipping fee?",
        )
    )
    assert message["sender_type"] == "customer"

    document = DocumentService(client).create_document(
        DocumentCreate(
            name="Policy",
            file_url="https://example.com/policy.pdf",
            file_type=DocumentFileType.PDF,
            uploaded_by=user_id,
        )
    )
    assert document["embedding_status"] == "processing"

    channel = ChannelService(client).create_channel(
        ChannelCreate(type=ChannelType.FACEBOOK, config={"page_id": "123"})
    )
    assert channel["type"] == "facebook"

    notification = NotificationService(client).create_notification(
        NotificationCreate(
            ticket_id=ticket["id"],
            recipient_id=user_id,
            title="Urgent ticket",
            body="A customer needs help.",
        )
    )
    assert notification["is_read"] is False


def test_ticket_role_visibility_queries_match_project_rules() -> None:
    agent_id = str(uuid4())
    other_agent_id = str(uuid4())
    client = FakeSupabase(
        {
            "tickets": [
                {
                    "id": str(uuid4()),
                    "assigned_to": agent_id,
                    "status": "in_progress",
                    "created_at": "2026-08-08T10:00:00+00:00",
                },
                {
                    "id": str(uuid4()),
                    "assigned_to": other_agent_id,
                    "status": "open",
                    "created_at": "2026-08-08T11:00:00+00:00",
                },
                {
                    "id": str(uuid4()),
                    "assigned_to": other_agent_id,
                    "status": "resolved",
                    "created_at": "2026-08-08T12:00:00+00:00",
                },
            ]
        }
    )

    service = TicketService(client)

    super_admin_rows = service.list_visible_tickets(user_read(str(uuid4()), UserRole.SUPER_ADMIN))
    assert len(super_admin_rows) == 3

    agent_rows = service.list_visible_tickets(user_read(agent_id, UserRole.AGENT))
    assert {row["status"] for row in agent_rows} == {"in_progress", "open"}
    assert client.tables["tickets"].last_or_filter == f"assigned_to.eq.{agent_id},status.eq.open"


def test_ticket_transitions_enforce_allowed_workflow() -> None:
    ticket_id = str(uuid4())
    client = FakeSupabase(
        {
            "tickets": [
                {
                    "id": ticket_id,
                    "status": "open",
                    "created_at": "2026-08-08T10:00:00+00:00",
                    "updated_at": "2026-08-08T10:00:00+00:00",
                }
            ]
        }
    )
    service = TicketService(client)

    started = service.start_progress(ticket_id)
    assert started["status"] == TicketStatus.IN_PROGRESS

    resolved = service.resolve_ticket(ticket_id)
    assert resolved["status"] == TicketStatus.RESOLVED
    assert resolved["resolved_at"] is not None

    reopened = service.reopen_ticket(ticket_id)
    assert reopened["status"] == TicketStatus.OPEN
    assert reopened["resolved_at"] is None

    with pytest.raises(InvalidTicketTransitionError):
        service.reopen_ticket(ticket_id)


def test_message_creation_rejects_invalid_sender_type_and_empty_content() -> None:
    with pytest.raises(ValidationError):
        MessageCreate(
            ticket_id=uuid4(),
            sender_type="system",
            sender_id="internal",
            content="hello",
        )

    with pytest.raises(ValidationError):
        MessageCreate(
            ticket_id=uuid4(),
            sender_type=SenderType.HUMAN,
            sender_id="agent-1",
            content="   ",
        )


def test_channel_public_view_redacts_secret_config_values() -> None:
    client = FakeSupabase()
    service = ChannelService(client)
    channel = service.create_channel(
        ChannelCreate(
            type=ChannelType.EMAIL,
            config={
                "inbound_address": "support@example.com",
                "sendgrid_api_key": "real-secret",
                "webhook_signing_key": "another-secret",
            },
            is_active=True,
        )
    )

    public_channel = service.to_public_channel(channel)

    assert public_channel.config["inbound_address"] == "support@example.com"
    assert public_channel.config["sendgrid_api_key"] == "***"
    assert public_channel.config["webhook_signing_key"] == "***"
