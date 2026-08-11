import hashlib
import hmac
from collections.abc import Iterator

import httpx
import pytest
from fastapi.testclient import TestClient

from app.core.config import Settings, get_settings
from app.db.supabase import get_supabase_client
from app.main import create_app
from app.schemas.common import IntentType
from app.services.ai_client import AIProcessingResult, get_ai_processor
from app.services.email import MailgunEmailProvider, SendGridEmailProvider
from app.services.facebook import FacebookSendApiClient
from app.services.outbound import OutboundDeliveryError
from tests.fakes import FakeSupabase


class FakeAIProcessor:
    def process_message(self, *, source: str, sender_id: str, content: str) -> AIProcessingResult:
        return AIProcessingResult(
            intent=IntentType.QUESTION,
            confidence=0.9,
            answer="A support answer.",
        )


@pytest.fixture
def client() -> Iterator[TestClient]:
    app = create_app()
    app.dependency_overrides[get_supabase_client] = lambda: FakeSupabase()
    app.dependency_overrides[get_ai_processor] = lambda: FakeAIProcessor()
    yield TestClient(app)
    app.dependency_overrides.clear()


def override_settings(client: TestClient, settings: Settings) -> None:
    client.app.dependency_overrides[get_settings] = lambda: settings


def test_facebook_webhook_verification_endpoint(client: TestClient) -> None:
    override_settings(client, Settings(facebook_verify_token="verify-me"))

    response = client.get(
        "/webhooks/facebook",
        params={
            "hub.mode": "subscribe",
            "hub.verify_token": "verify-me",
            "hub.challenge": "challenge-123",
        },
    )

    assert response.status_code == 200
    assert response.text == "challenge-123"


def test_facebook_graph_payload_is_parsed(client: TestClient) -> None:
    payload = {
        "object": "page",
        "entry": [
            {
                "messaging": [
                    {
                        "sender": {"id": "fb-user-1"},
                        "recipient": {"id": "page-1"},
                        "message": {"mid": "m_1", "text": "What is the warranty?"},
                    }
                ]
            }
        ],
    }

    response = client.post("/webhooks/facebook", json=payload)

    assert response.status_code == 200
    body = response.json()
    assert body["action"] == "auto_replied"
    assert body["customer_message"]["sender_id"] == "fb-user-1"
    assert body["ticket"]["source"] == "facebook"


def test_facebook_invalid_signature_is_rejected(client: TestClient) -> None:
    override_settings(client, Settings(facebook_app_secret="secret"))

    response = client.post(
        "/webhooks/facebook",
        headers={"X-Hub-Signature-256": "sha256=bad"},
        json={"sender_id": "fb-user-1", "content": "Hello"},
    )

    assert response.status_code == 400
    assert "Invalid Facebook webhook signature" in response.json()["detail"]


def test_mailgun_inbound_payload_is_parsed_with_signature(client: TestClient) -> None:
    signing_key = "mailgun-signing-key"
    timestamp = "1723090000"
    token = "mailgun-token"
    signature = hmac.new(signing_key.encode(), f"{timestamp}{token}".encode(), hashlib.sha256).hexdigest()
    override_settings(client, Settings(mailgun_webhook_signing_key=signing_key))

    response = client.post(
        "/webhooks/email",
        data={
            "sender": "Alice <alice@example.com>",
            "stripped-text": "Can I get an invoice?",
            "timestamp": timestamp,
            "token": token,
            "signature": signature,
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert body["customer_message"]["sender_id"] == "Alice <alice@example.com>"
    assert body["ticket"]["source"] == "email"


def test_mailgun_invalid_signature_is_rejected(client: TestClient) -> None:
    override_settings(client, Settings(mailgun_webhook_signing_key="mailgun-signing-key"))

    response = client.post(
        "/webhooks/email",
        data={
            "sender": "Alice <alice@example.com>",
            "stripped-text": "Can I get an invoice?",
            "timestamp": "1723090000",
            "token": "mailgun-token",
            "signature": "bad",
        },
    )

    assert response.status_code == 400
    assert "Invalid Mailgun webhook signature" in response.json()["detail"]


def test_sendgrid_inbound_payload_is_parsed(client: TestClient) -> None:
    response = client.post(
        "/webhooks/email?provider=sendgrid",
        json={
            "from": "bob@example.com",
            "text": "Where is my order?",
            "subject": "Order question",
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert body["customer_message"]["sender_id"] == "bob@example.com"
    assert body["intent"] == "question"


def test_facebook_send_api_invalid_token_error() -> None:
    transport = httpx.MockTransport(lambda request: httpx.Response(401, json={"error": "bad token"}))
    client = FacebookSendApiClient(
        Settings(facebook_page_access_token="token"),
        http_client=httpx.Client(transport=transport),
    )

    with pytest.raises(OutboundDeliveryError, match="token rejected"):
        client.send_text("fb-user-1", "Hello")


def test_mailgun_and_sendgrid_api_failure_errors() -> None:
    mailgun = MailgunEmailProvider(
        Settings(mailgun_api_key="key", mailgun_domain="example.com"),
        http_client=httpx.Client(transport=httpx.MockTransport(lambda request: httpx.Response(500))),
    )
    sendgrid = SendGridEmailProvider(
        Settings(sendgrid_api_key="key"),
        http_client=httpx.Client(transport=httpx.MockTransport(lambda request: httpx.Response(500))),
    )

    with pytest.raises(OutboundDeliveryError, match="Mailgun API failed"):
        mailgun.send_reply("alice@example.com", "Subject", "Body")
    with pytest.raises(OutboundDeliveryError, match="SendGrid API failed"):
        sendgrid.send_reply("alice@example.com", "Subject", "Body")
