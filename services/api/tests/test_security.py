from collections.abc import Iterator

import pytest
from fastapi.testclient import TestClient

from app.core.config import get_settings
from app.main import create_app


@pytest.fixture(autouse=True)
def reset_settings_cache() -> Iterator[None]:
    get_settings.cache_clear()
    yield
    get_settings.cache_clear()


def mock_token(role: str, status: str = "online", user_id: str = "user-1") -> str:
    return f"mock:{user_id}:{role}@example.com:{role}:{status}"


def auth_header(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


def test_missing_token_returns_401(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("APP_ENV", "test")
    monkeypatch.setenv("LOCAL_MOCK_AUTH_ENABLED", "true")
    client = TestClient(create_app())

    response = client.get("/inbox")

    assert response.status_code == 401
    assert response.json()["detail"] == "Missing bearer token"


def test_invalid_token_returns_401_when_jwt_validation_fails(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setenv("APP_ENV", "test")
    monkeypatch.setenv("LOCAL_MOCK_AUTH_ENABLED", "false")
    monkeypatch.setenv("SUPABASE_JWT_SECRET", "test-secret")
    client = TestClient(create_app())

    response = client.get("/inbox", headers=auth_header("not-a-jwt"))

    assert response.status_code == 401
    assert response.json()["detail"] == "Invalid bearer token"


def test_disabled_user_is_rejected(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("APP_ENV", "test")
    monkeypatch.setenv("LOCAL_MOCK_AUTH_ENABLED", "true")
    client = TestClient(create_app())

    response = client.get("/inbox", headers=auth_header(mock_token("agent", "disabled")))

    assert response.status_code == 403
    assert response.json()["detail"] == "User account is disabled"


def test_agent_can_access_agent_routes_but_not_super_admin_routes(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setenv("APP_ENV", "test")
    monkeypatch.setenv("LOCAL_MOCK_AUTH_ENABLED", "true")
    client = TestClient(create_app())
    headers = auth_header(mock_token("agent"))

    inbox_response = client.get("/inbox", headers=headers)
    dashboard_response = client.get("/dashboard", headers=headers)

    assert inbox_response.status_code == 200
    assert inbox_response.json()["scope"] == "inbox"
    assert dashboard_response.status_code == 403
    assert dashboard_response.json()["detail"] == "Super admin permission required"


def test_super_admin_can_access_super_admin_and_agent_routes(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setenv("APP_ENV", "test")
    monkeypatch.setenv("LOCAL_MOCK_AUTH_ENABLED", "true")
    client = TestClient(create_app())
    headers = auth_header(mock_token("super_admin"))

    dashboard_response = client.get("/dashboard", headers=headers)
    inbox_response = client.get("/inbox", headers=headers)

    assert dashboard_response.status_code == 200
    assert dashboard_response.json()["scope"] == "dashboard"
    assert inbox_response.status_code == 200
    assert inbox_response.json()["scope"] == "inbox"


def test_cors_allows_configured_frontend_origin(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("CORS_ALLOWED_ORIGINS", "http://localhost:3000")
    client = TestClient(create_app())

    response = client.options(
        "/health",
        headers={
            "Origin": "http://localhost:3000",
            "Access-Control-Request-Method": "GET",
        },
    )

    assert response.status_code == 200
    assert response.headers["access-control-allow-origin"] == "http://localhost:3000"


def test_message_content_length_is_limited(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("APP_ENV", "test")
    monkeypatch.setenv("LOCAL_MOCK_AUTH_ENABLED", "true")
    client = TestClient(create_app())
    headers = auth_header(mock_token("agent"))

    response = client.post(
        "/tickets/00000000-0000-4000-8000-000000000001/messages",
        headers=headers,
        json={"content": "x" * 4001},
    )

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "validation_error"


def test_public_webhook_rate_limit(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("LOCAL_MOCK_AUTH_ENABLED", "true")
    monkeypatch.setenv("PUBLIC_ENDPOINT_RATE_LIMIT", "1")
    monkeypatch.setenv("PUBLIC_ENDPOINT_RATE_WINDOW_SECONDS", "60")
    client = TestClient(create_app())

    first = client.post(
        "/webhooks/web-message",
        json={"sender_id": "customer-1", "content": "Hello"},
    )
    second = client.post(
        "/webhooks/web-message",
        json={"sender_id": "customer-1", "content": "Hello again"},
    )

    assert first.status_code in {200, 500}
    assert second.status_code == 429
    assert second.json()["error"]["code"] == "rate_limited"
