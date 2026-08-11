import httpx

from app.core.config import Settings
from app.db.supabase import RestSupabaseClient, get_supabase_client


def test_get_supabase_client_returns_rest_adapter_when_mock_disabled() -> None:
    client = get_supabase_client(
        Settings(
            local_mock_auth_enabled=False,
            supabase_url="https://project.supabase.co",
            supabase_service_role_key="service-key",
        )
    )

    assert isinstance(client, RestSupabaseClient)


def test_rest_adapter_sends_postgrest_select(monkeypatch) -> None:
    calls = []

    def fake_request(method, url, *, params, json, headers, timeout):
        calls.append(
            {
                "method": method,
                "url": url,
                "params": params,
                "json": json,
                "headers": headers,
                "timeout": timeout,
            }
        )
        return httpx.Response(
            200,
            json=[{"id": "ticket-1"}],
            request=httpx.Request(method, url),
        )

    monkeypatch.setattr(httpx, "request", fake_request)
    client = RestSupabaseClient(
        get_supabase_client(
            Settings(
                local_mock_auth_enabled=False,
                supabase_url="https://project.supabase.co",
                supabase_service_role_key="service-key",
            )
        ).config
    )

    result = (
        client.table("tickets")
        .select("*")
        .eq("status", "open")
        .or_("assigned_to.eq.agent-1,status.eq.open")
        .order("created_at", desc=True)
        .execute()
    )

    assert result.data == [{"id": "ticket-1"}]
    assert calls == [
        {
            "method": "GET",
            "url": "https://project.supabase.co/rest/v1/tickets",
            "params": {
                "select": "*",
                "status": "eq.open",
                "or": "(assigned_to.eq.agent-1,status.eq.open)",
                "order": "created_at.desc",
            },
            "json": None,
            "headers": {
                "apikey": "service-key",
                "authorization": "Bearer service-key",
                "content-type": "application/json",
                "prefer": "return=representation",
            },
            "timeout": 10,
        }
    ]
