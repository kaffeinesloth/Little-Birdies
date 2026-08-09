from collections.abc import Iterator
from uuid import uuid4

import pytest
from fastapi.testclient import TestClient

from app.db.supabase import get_supabase_client
from app.main import create_app
from app.schemas.common import IntentType
from app.services.ai_client import AIProcessingError, AIProcessingResult, get_ai_processor
from tests.fakes import FakeSupabase


class FakeAIProcessor:
    def __init__(self, result: AIProcessingResult) -> None:
        self.result = result

    def process_message(self, *, source: str, sender_id: str, content: str) -> AIProcessingResult:
        return self.result


class TimeoutAIProcessor:
    def process_message(self, *, source: str, sender_id: str, content: str) -> AIProcessingResult:
        raise AIProcessingError("timeout")


@pytest.fixture
def client() -> Iterator[TestClient]:
    app = create_app()
    yield TestClient(app)
    app.dependency_overrides.clear()


def override_supabase(app, fake: FakeSupabase) -> None:
    def dependency() -> FakeSupabase:
        return fake

    app.dependency_overrides[get_supabase_client] = dependency


def override_ai(app, ai_processor) -> None:
    def dependency():
        return ai_processor

    app.dependency_overrides[get_ai_processor] = dependency


def online_agent() -> dict:
    return {
        "id": str(uuid4()),
        "email": "agent@example.com",
        "full_name": "Agent",
        "role": "agent",
        "status": "online",
        "created_at": "2026-08-08T10:00:00+00:00",
        "updated_at": "2026-08-08T10:00:00+00:00",
    }


def test_question_auto_reply_saves_customer_and_bot_messages(client: TestClient) -> None:
    fake = FakeSupabase()
    override_supabase(client.app, fake)
    override_ai(
        client.app,
        FakeAIProcessor(
            AIProcessingResult(
                intent=IntentType.QUESTION,
                confidence=0.91,
                answer="Shipping takes 2-3 business days.",
            )
        ),
    )

    response = client.post(
        "/webhooks/web-message",
        json={"sender_id": "customer-1", "customer_name": "Alice", "content": "How long is shipping?"},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["action"] == "auto_replied"
    assert body["intent"] == "question"
    assert body["bot_message"]["sender_type"] == "bot"
    assert [message["sender_type"] for message in fake.tables["messages"].rows] == ["customer", "bot"]


def test_complaint_escalation_updates_ticket_and_notifies_online_agents(
    client: TestClient,
) -> None:
    agent = online_agent()
    fake = FakeSupabase({"users": [agent]})
    override_supabase(client.app, fake)
    override_ai(
        client.app,
        FakeAIProcessor(
            AIProcessingResult(
                intent=IntentType.COMPLAINT,
                confidence=0.88,
                answer="I am sorry about that. A staff member will help right away.",
                should_escalate=True,
                reason="Customer complaint detected.",
            )
        ),
    )

    response = client.post(
        "/webhooks/facebook",
        json={"sender_id": "fb-1", "customer_name": "Bob", "content": "My order is late and I am angry."},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["action"] == "escalated"
    assert body["ticket"]["status"] == "pending"
    assert body["ticket"]["intent"] == "complaint"
    assert body["bot_message"]["content"].startswith("I am sorry")
    assert len(body["notifications"]) == 1
    assert fake.tables["notifications"].rows[0]["recipient_id"] == agent["id"]


def test_spam_is_ignored_after_classification(client: TestClient) -> None:
    fake = FakeSupabase({"users": [online_agent()]})
    override_supabase(client.app, fake)
    override_ai(
        client.app,
        FakeAIProcessor(
            AIProcessingResult(
                intent=IntentType.SPAM,
                confidence=0.99,
                reason="Promotional spam.",
            )
        ),
    )

    response = client.post(
        "/webhooks/email",
        json={"sender_id": "spam@example.com", "content": "CLICK http://spam.example now"},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["action"] == "ignored_spam"
    assert body["ticket"]["intent"] == "spam"
    assert body["ticket"]["status"] == "resolved"
    assert body["bot_message"] is None
    assert fake.tables.get("notifications") is None
    assert [message["sender_type"] for message in fake.tables["messages"].rows] == ["customer"]


def test_ai_timeout_fallback_defaults_to_question_and_escalates(client: TestClient) -> None:
    agent = online_agent()
    fake = FakeSupabase({"users": [agent]})
    override_supabase(client.app, fake)
    override_ai(client.app, TimeoutAIProcessor())

    response = client.post(
        "/webhooks/web-message",
        json={"sender_id": "customer-2", "content": "What is your warranty policy?"},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["action"] == "escalated"
    assert body["intent"] == "question"
    assert body["ticket"]["status"] == "pending"
    assert "AI service unavailable" in body["ticket"]["summary"]
    assert body["bot_message"]["sender_type"] == "bot"
    assert "staff member" in body["bot_message"]["content"]
    assert len(body["notifications"]) == 1
    assert [message["sender_type"] for message in fake.tables["messages"].rows] == ["customer", "bot"]
