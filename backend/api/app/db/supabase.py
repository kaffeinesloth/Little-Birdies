from dataclasses import dataclass
from typing import Any
from urllib.parse import quote

from fastapi import Depends
import httpx

from app.core.config import Settings, get_settings
from app.db.local_supabase import local_supabase
from app.services.supabase_table import SupabaseClient


@dataclass(frozen=True)
class SupabaseConfig:
    url: str | None
    anon_key: str | None
    service_role_key: str | None

    @property
    def is_configured(self) -> bool:
        return bool(self.url and self.service_role_key)


def get_supabase_config(settings: Settings | None = None) -> SupabaseConfig:
    settings = settings or get_settings()
    return SupabaseConfig(
        url=settings.supabase_url,
        anon_key=settings.supabase_anon_key,
        service_role_key=settings.supabase_service_role_key,
    )


def get_supabase_client(settings: Settings = Depends(get_settings)) -> SupabaseClient:
    if settings.local_mock_auth_enabled and settings.app_env != "production":
        return local_supabase
    config = get_supabase_config(settings)
    if not config.is_configured:
        raise RuntimeError("Supabase client is not configured")
    return RestSupabaseClient(config)


@dataclass
class RestResult:
    data: Any


class RestSupabaseQuery:
    def __init__(self, client: "RestSupabaseClient", table_name: str) -> None:
        self.client = client
        self.table_name = table_name
        self.operation = "select"
        self.columns = "*"
        self.values: dict[str, Any] = {}
        self.filters: list[tuple[str, Any]] = []
        self.or_filter: str | None = None
        self.order_by: tuple[str, bool] | None = None

    def select(self, columns: str = "*") -> "RestSupabaseQuery":
        self.operation = "select"
        self.columns = columns
        return self

    def insert(self, values: dict[str, Any]) -> "RestSupabaseQuery":
        self.operation = "insert"
        self.values = values
        return self

    def update(self, values: dict[str, Any]) -> "RestSupabaseQuery":
        self.operation = "update"
        self.values = values
        return self

    def eq(self, column: str, value: Any) -> "RestSupabaseQuery":
        self.filters.append((column, value))
        return self

    def or_(self, filters: str) -> "RestSupabaseQuery":
        self.or_filter = filters
        return self

    def order(self, column: str, desc: bool = False) -> "RestSupabaseQuery":
        self.order_by = (column, desc)
        return self

    def execute(self) -> RestResult:
        params = self._params()
        if self.operation == "insert":
            data = self.client.request("POST", self.table_name, params=params, json_body=self.values)
        elif self.operation == "update":
            data = self.client.request("PATCH", self.table_name, params=params, json_body=self.values)
        else:
            data = self.client.request("GET", self.table_name, params=params)
        return RestResult(data)

    def _params(self) -> dict[str, str]:
        params: dict[str, str] = {}
        if self.operation == "select":
            params["select"] = self.columns
        for column, value in self.filters:
            params[column] = f"eq.{value}"
        if self.or_filter:
            params["or"] = f"({self.or_filter})"
        if self.order_by:
            column, desc = self.order_by
            params["order"] = f"{column}.{'desc' if desc else 'asc'}"
        return params


class RestSupabaseClient:
    def __init__(self, config: SupabaseConfig) -> None:
        self.config = config
        self.base_url = f"{config.url.rstrip('/')}/rest/v1"

    def table(self, name: str) -> RestSupabaseQuery:
        return RestSupabaseQuery(self, name)

    def request(
        self,
        method: str,
        table_name: str,
        *,
        params: dict[str, str],
        json_body: dict[str, Any] | None = None,
    ) -> Any:
        url = f"{self.base_url}/{quote(table_name, safe='')}"
        response = httpx.request(
            method,
            url,
            params=params,
            json=json_body,
            headers=self._headers,
            timeout=10,
        )
        response.raise_for_status()
        if not response.content:
            return []
        return response.json()

    @property
    def _headers(self) -> dict[str, str]:
        key = self.config.service_role_key or ""
        return {
            "apikey": key,
            "authorization": f"Bearer {key}",
            "content-type": "application/json",
            "prefer": "return=representation",
        }
