from collections.abc import Iterator
from datetime import UTC, datetime, timedelta
from uuid import uuid4

import pytest
from fastapi.testclient import TestClient

from app.core.security import AuthenticatedUser, require_agent_or_super_admin
from app.db.supabase import get_supabase_client
from app.main import create_app
from app.schemas.common import IntentType
from app.services.ai_client import AIProcessingResult
from app.services.fcm import MockFCMSender
from app.services.notifications import NotificationService
from app.services.orchestrator import InboundOrchestrator
from tests.fakes import FakeSupabase


class ComplaintAIProcessor:
    def process_message(self, *, source: str, sender_id: str, content: str) -> AIProcessingResult:
        return AIProcessingResult(
            intent=IntentType.COMPLAINT,
            confidence=0.9,
            answer="I am sorry. A staff member will help right away.",
            should_escalate=True,
            reason="Complaint detected.",
        )


@pytest.fixture
def client() -> Iterator[TestClient]:
    app = create_app()
    yield TestClient(app)
    app.dependency_overrides.clear()


def staff_user(*, status: str, role: str = "agent", user_id: str | None = None) -> dict:
    now = datetime.now(UTC).isoformat()
    return {
        "id": user_id or str(uuid4()),
        "email": f"{role}-{status}@example.com",
        "full_name": f"{role} {status}",
        "role": role,
        "status": status,
        "last_seen_at": now,
        "created_at": now,
        "updated_at": now,
    }


def override_user(app, *, user_id: str, role: str = "agent") -> None:
    async def dependency() -> AuthenticatedUser:
        return AuthenticatedUser(id=user_id, email="agent@example.com", role=role, status="online")

    app.dependency_overrides[require_agent_or_super_admin] = dependency


def override_supabase(app, fake: FakeSupabase) -> None:
    def dependency() -> FakeSupabase:
        return fake

    app.dependency_overrides[get_supabase_client] = dependency


def test_online_agents_and_super_admins_are_notified_with_fcm() -> None:
    agent = staff_user(status="online")
    owner = staff_user(status="online", role="super_admin")
    offline = staff_user(status="offline")
    disabled = staff_user(status="disabled")
    fake = FakeSupabase({"users": [agent, owner, offline, disabled]})
    fcm = MockFCMSender()

    notifications = NotificationService(fake, fcm).create_urgent_ticket_notifications(
        ticket_id=str(uuid4()),
        title="Urgent support ticket",
        body="Customer needs help.",
    )

    assert {notification["recipient_id"] for notification in notifications} == {agent["id"], owner["id"]}
    assert {push["recipient_id"] for push in fcm.sent} == {agent["id"], owner["id"]}
    assert all(notification["sent_at"] is not None for notification in notifications)


def test_no_online_agents_stores_notifications_for_later_and_ticket_stays_pending() -> None:
    offline_agent = staff_user(status="offline")
    offline_owner = staff_user(status="offline", role="super_admin")
    fake = FakeSupabase({"users": [offline_agent, offline_owner]})

    result = InboundOrchestrator(fake, ComplaintAIProcessor()).process_inbound_message(
        source="web",
        sender_id="customer-1",
        content="My order is broken and I want a refund.",
        customer_name="Alice",
    )

    assert result.ticket["status"] == "pending"
    assert {notification["recipient_id"] for notification in result.notifications} == {
        offline_agent["id"],
        offline_owner["id"],
    }
    assert all(notification.get("sent_at") is None for notification in result.notifications)


def test_notification_persistence_excludes_disabled_users() -> None:
    active = staff_user(status="offline")
    disabled = staff_user(status="disabled")
    fake = FakeSupabase({"users": [active, disabled]})

    notifications = NotificationService(fake).create_urgent_ticket_notifications(
        ticket_id=str(uuid4()),
        title="Urgent",
        body="Needs review.",
    )

    assert len(fake.tables["notifications"].rows) == 1
    assert notifications[0]["recipient_id"] == active["id"]


def test_current_user_can_update_presence_and_heartbeat_marks_stale_users_offline(
    client: TestClient,
) -> None:
    current_user_id = str(uuid4())
    stale_user = staff_user(
        status="online",
        user_id=str(uuid4()),
    )
    stale_user["last_seen_at"] = (datetime.now(UTC) - timedelta(seconds=45)).isoformat()
    current_user = staff_user(status="offline", user_id=current_user_id)
    fake = FakeSupabase({"users": [current_user, stale_user]})
    override_user(client.app, user_id=current_user_id)
    override_supabase(client.app, fake)

    status_response = client.post("/presence/status", json={"status": "online"})
    heartbeat_response = client.post("/presence/heartbeat")

    assert status_response.status_code == 200
    assert status_response.json()["status"] == "online"
    assert heartbeat_response.status_code == 200
    assert heartbeat_response.json()["stale_users_marked_offline"] == 1
    assert fake.tables["users"].rows[1]["status"] == "offline"
