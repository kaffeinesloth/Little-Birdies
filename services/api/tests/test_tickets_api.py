from collections.abc import Iterator
from uuid import uuid4

import pytest
from fastapi.testclient import TestClient

from app.core.security import AuthenticatedUser, require_agent_or_super_admin
from app.db.supabase import get_supabase_client
from app.main import create_app
from app.schemas.common import ChannelType
from app.services.outbound import OutboundDeliveryError, OutboundRouter, get_outbound_router
from tests.fakes import FakeSupabase


class FailingOutboundRouter:
    def send_reply(self, ticket: dict, message: dict) -> None:
        raise OutboundDeliveryError("mock provider unavailable")


@pytest.fixture
def client() -> Iterator[TestClient]:
    app = create_app()
    yield TestClient(app)
    app.dependency_overrides.clear()


def override_user(app, *, user_id: str, role: str = "super_admin") -> None:
    async def dependency() -> AuthenticatedUser:
        return AuthenticatedUser(
            id=user_id,
            email=f"{role}@example.com",
            role=role,
            status="online",
        )

    app.dependency_overrides[require_agent_or_super_admin] = dependency


def override_supabase(app, fake: FakeSupabase) -> None:
    def dependency() -> FakeSupabase:
        return fake

    app.dependency_overrides[get_supabase_client] = dependency


def override_outbound(app, router) -> None:
    def dependency():
        return router

    app.dependency_overrides[get_outbound_router] = dependency


def make_ticket(
    *,
    ticket_id: str | None = None,
    assigned_to: str | None = None,
    status: str = "open",
    source: str = "web",
    customer_name: str = "Customer",
    summary: str = "Question about shipping",
) -> dict:
    return {
        "id": ticket_id or str(uuid4()),
        "customer_id": "cust-1",
        "customer_name": customer_name,
        "source": source,
        "status": status,
        "intent": "question",
        "summary": summary,
        "assigned_to": assigned_to,
        "resolved_at": None,
        "created_at": "2026-08-08T10:00:00+00:00",
        "updated_at": "2026-08-08T10:00:00+00:00",
    }


def test_get_tickets_supports_filters_and_pagination(client: TestClient) -> None:
    user_id = str(uuid4())
    fake = FakeSupabase(
        {
            "tickets": [
                make_ticket(status="open", source="web", customer_name="Alice", summary="Shipping fee"),
                make_ticket(status="resolved", source="email", customer_name="Bob", summary="Refund"),
                make_ticket(status="open", source="facebook", customer_name="Carol", summary="Warranty"),
            ]
        }
    )
    override_user(client.app, user_id=user_id, role="super_admin")
    override_supabase(client.app, fake)

    response = client.get("/tickets?status=open&source=web&search=ship&limit=10&offset=0")

    assert response.status_code == 200
    body = response.json()
    assert body["count"] == 1
    assert body["items"][0]["customer_name"] == "Alice"


def test_agent_ticket_list_is_limited_to_assigned_and_open_tickets(client: TestClient) -> None:
    agent_id = str(uuid4())
    other_agent_id = str(uuid4())
    fake = FakeSupabase(
        {
            "tickets": [
                make_ticket(assigned_to=agent_id, status="in_progress"),
                make_ticket(assigned_to=other_agent_id, status="open"),
                make_ticket(assigned_to=other_agent_id, status="resolved"),
            ]
        }
    )
    override_user(client.app, user_id=agent_id, role="agent")
    override_supabase(client.app, fake)

    response = client.get("/tickets")

    assert response.status_code == 200
    statuses = {ticket["status"] for ticket in response.json()["items"]}
    assert statuses == {"in_progress", "open"}


def test_resolve_and_reopen_ticket(client: TestClient) -> None:
    user_id = str(uuid4())
    ticket_id = str(uuid4())
    fake = FakeSupabase({"tickets": [make_ticket(ticket_id=ticket_id, assigned_to=user_id)]})
    override_user(client.app, user_id=user_id, role="agent")
    override_supabase(client.app, fake)

    resolved = client.post(f"/tickets/{ticket_id}/resolve")
    reopened = client.post(f"/tickets/{ticket_id}/reopen")

    assert resolved.status_code == 200
    assert resolved.json()["status"] == "resolved"
    assert resolved.json()["resolved_at"] is not None
    assert reopened.status_code == 200
    assert reopened.json()["status"] == "open"
    assert reopened.json()["resolved_at"] is None


def test_assign_ticket_to_current_agent(client: TestClient) -> None:
    user_id = str(uuid4())
    ticket_id = str(uuid4())
    fake = FakeSupabase({"tickets": [make_ticket(ticket_id=ticket_id)]})
    override_user(client.app, user_id=user_id, role="agent")
    override_supabase(client.app, fake)

    response = client.post(f"/tickets/{ticket_id}/assign", json={"assigned_to": user_id})

    assert response.status_code == 200
    assert response.json()["assigned_to"] == user_id


def test_invalid_ticket_transition_returns_conflict(client: TestClient) -> None:
    user_id = str(uuid4())
    ticket_id = str(uuid4())
    fake = FakeSupabase(
        {"tickets": [make_ticket(ticket_id=ticket_id, assigned_to=user_id, status="resolved")]}
    )
    override_user(client.app, user_id=user_id, role="agent")
    override_supabase(client.app, fake)

    response = client.post(f"/tickets/{ticket_id}/resolve")

    assert response.status_code == 409
    assert "Cannot transition ticket" in response.json()["detail"]


def test_create_human_message_saves_and_routes_web_realtime(client: TestClient) -> None:
    user_id = str(uuid4())
    ticket_id = str(uuid4())
    fake = FakeSupabase(
        {"tickets": [make_ticket(ticket_id=ticket_id, assigned_to=user_id, source="web")]}
    )
    override_user(client.app, user_id=user_id, role="agent")
    override_supabase(client.app, fake)
    override_outbound(client.app, OutboundRouter())

    response = client.post(f"/tickets/{ticket_id}/messages", json={"content": "We can help."})

    assert response.status_code == 201
    body = response.json()
    assert body["message"]["sender_type"] == "human"
    assert body["message"]["sender_id"] == user_id
    assert body["outbound"]["channel"] == ChannelType.WEB
    assert body["outbound"]["realtime_record"]["table"] == "messages"


def test_outbound_failure_returns_useful_error_after_saving_message(client: TestClient) -> None:
    user_id = str(uuid4())
    ticket_id = str(uuid4())
    fake = FakeSupabase(
        {"tickets": [make_ticket(ticket_id=ticket_id, assigned_to=user_id, source="facebook")]}
    )
    override_user(client.app, user_id=user_id, role="agent")
    override_supabase(client.app, fake)
    override_outbound(client.app, FailingOutboundRouter())

    response = client.post(f"/tickets/{ticket_id}/messages", json={"content": "Checking now."})

    assert response.status_code == 502
    assert "Message saved but outbound delivery failed" in response.json()["detail"]
    assert len(fake.tables["messages"].rows) == 1
    assert fake.tables["messages"].rows[0]["sender_type"] == "human"
