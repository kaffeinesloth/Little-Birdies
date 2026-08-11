from __future__ import annotations

from copy import deepcopy
from dataclasses import dataclass
from datetime import UTC, datetime
from typing import Any
from uuid import uuid4


OWNER_DEMO_ID = "00000000-0000-4000-8000-000000000001"
AGENT_DEMO_ID = "00000000-0000-4000-8000-000000000002"


@dataclass
class LocalResult:
    data: Any


class LocalQuery:
    def __init__(self, table: "LocalTable") -> None:
        self.table = table
        self.operation = "select"
        self.values: dict[str, Any] = {}
        self.filters: list[tuple[str, Any]] = []
        self.or_filter: str | None = None
        self.order_by: tuple[str, bool] | None = None

    def select(self, columns: str = "*") -> "LocalQuery":
        self.operation = "select"
        return self

    def insert(self, values: dict[str, Any]) -> "LocalQuery":
        self.operation = "insert"
        self.values = values
        return self

    def update(self, values: dict[str, Any]) -> "LocalQuery":
        self.operation = "update"
        self.values = values
        return self

    def eq(self, column: str, value: Any) -> "LocalQuery":
        self.filters.append((column, str(value)))
        return self

    def or_(self, filters: str) -> "LocalQuery":
        self.or_filter = filters
        return self

    def order(self, column: str, desc: bool = False) -> "LocalQuery":
        self.order_by = (column, desc)
        return self

    def execute(self) -> LocalResult:
        if self.operation == "insert":
            return LocalResult([self.table.insert(self.values)])
        if self.operation == "update":
            return LocalResult(self.table.update(self.filters, self.values))
        return LocalResult(self.table.select(self.filters, self.or_filter, self.order_by))


class LocalTable:
    def __init__(self, rows: list[dict[str, Any]] | None = None) -> None:
        self.rows = rows or []

    def query(self) -> LocalQuery:
        return LocalQuery(self)

    def insert(self, values: dict[str, Any]) -> dict[str, Any]:
        now = datetime.now(UTC).isoformat()
        row = {
            "id": str(uuid4()),
            "created_at": now,
            "updated_at": now,
            **deepcopy(values),
        }
        self.rows.append(row)
        return deepcopy(row)

    def update(self, filters: list[tuple[str, Any]], values: dict[str, Any]) -> list[dict[str, Any]]:
        matched = self.select(filters, None, None)
        matched_ids = {row["id"] for row in matched}
        updated = []
        for row in self.rows:
            if row["id"] in matched_ids:
                row.update(deepcopy(values))
                row["updated_at"] = datetime.now(UTC).isoformat()
                updated.append(deepcopy(row))
        return updated

    def select(
        self,
        filters: list[tuple[str, Any]],
        or_filter: str | None,
        order_by: tuple[str, bool] | None,
    ) -> list[dict[str, Any]]:
        rows = deepcopy(self.rows)
        for column, value in filters:
            rows = [row for row in rows if str(row.get(column)) == value]
        if or_filter:
            clauses = [clause.split(".eq.", maxsplit=1) for clause in or_filter.split(",")]
            rows = [
                row
                for row in rows
                if any(len(clause) == 2 and str(row.get(clause[0])) == clause[1] for clause in clauses)
            ]
        if order_by:
            column, desc = order_by
            rows.sort(key=lambda row: row.get(column) or "", reverse=desc)
        return rows


class LocalSupabase:
    def __init__(self) -> None:
        now = datetime.now(UTC).isoformat()
        self.tables = {
            "users": LocalTable(
                [
                    {
                        "id": OWNER_DEMO_ID,
                        "email": "owner@example.com",
                        "full_name": "Shop Owner",
                        "role": "super_admin",
                        "status": "online",
                        "created_at": now,
                        "updated_at": now,
                    },
                    {
                        "id": AGENT_DEMO_ID,
                        "email": "agent@example.com",
                        "full_name": "Support Agent",
                        "role": "agent",
                        "status": "online",
                        "created_at": now,
                        "updated_at": now,
                    },
                ]
            ),
            "tickets": LocalTable(),
            "messages": LocalTable(),
            "notifications": LocalTable(),
        }

    def table(self, name: str) -> LocalQuery:
        self.tables.setdefault(name, LocalTable())
        return self.tables[name].query()


local_supabase = LocalSupabase()
