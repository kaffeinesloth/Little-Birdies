from __future__ import annotations

from copy import deepcopy
from dataclasses import dataclass
from datetime import UTC, datetime
from typing import Any
from uuid import uuid4


@dataclass
class FakeResult:
    data: Any


class FakeQuery:
    def __init__(self, table: "FakeTable") -> None:
        self.table = table
        self.operation = "select"
        self.values: dict[str, Any] = {}
        self.filters: list[tuple[str, Any]] = []
        self.or_filter: str | None = None
        self.order_by: tuple[str, bool] | None = None

    def select(self, columns: str = "*") -> "FakeQuery":
        self.operation = "select"
        return self

    def insert(self, values: dict[str, Any]) -> "FakeQuery":
        self.operation = "insert"
        self.values = values
        return self

    def update(self, values: dict[str, Any]) -> "FakeQuery":
        self.operation = "update"
        self.values = values
        return self

    def eq(self, column: str, value: Any) -> "FakeQuery":
        self.filters.append((column, str(value)))
        return self

    def or_(self, filters: str) -> "FakeQuery":
        self.or_filter = filters
        self.table.last_or_filter = filters
        return self

    def order(self, column: str, desc: bool = False) -> "FakeQuery":
        self.order_by = (column, desc)
        return self

    def execute(self) -> FakeResult:
        if self.operation == "insert":
            return FakeResult([self.table.insert(self.values)])
        if self.operation == "update":
            return FakeResult(self.table.update(self.filters, self.values))
        return FakeResult(self.table.select(self.filters, self.or_filter, self.order_by))


class FakeTable:
    def __init__(self, rows: list[dict[str, Any]] | None = None) -> None:
        self.rows = rows or []
        self.last_or_filter: str | None = None

    def query(self) -> FakeQuery:
        return FakeQuery(self)

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
        for row in self.rows:
            if any(row["id"] == item["id"] for item in matched):
                row.update(deepcopy(values))
                row["updated_at"] = datetime.now(UTC).isoformat()
        return deepcopy(matched and [row for row in self.rows if row["id"] == matched[0]["id"]])

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


class FakeSupabase:
    def __init__(self, tables: dict[str, list[dict[str, Any]]] | None = None) -> None:
        self.tables = {name: FakeTable(rows) for name, rows in (tables or {}).items()}

    def table(self, name: str) -> FakeQuery:
        self.tables.setdefault(name, FakeTable())
        return self.tables[name].query()
