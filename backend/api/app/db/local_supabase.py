from __future__ import annotations

import json
import sqlite3
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path
from threading import RLock
from typing import Any
from uuid import uuid4


OWNER_DEMO_ID = "00000000-0000-4000-8000-000000000001"
AGENT_DEMO_ID = "00000000-0000-4000-8000-000000000002"
DEFAULT_DB_PATH = Path(__file__).resolve().parents[3] / "data" / "local_demo.sqlite3"


@dataclass
class LocalResult:
    data: Any


def _now() -> str:
    return datetime.now(UTC).isoformat()


def _json_default(value: Any) -> str:
    if isinstance(value, datetime):
        return value.isoformat()
    return str(value)


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
    def __init__(self, db: "LocalSupabase", name: str) -> None:
        self.db = db
        self.name = name

    def query(self) -> LocalQuery:
        return LocalQuery(self)

    def insert(self, values: dict[str, Any]) -> dict[str, Any]:
        row = {
            "id": str(values.get("id") or uuid4()),
            "created_at": values.get("created_at") or _now(),
            "updated_at": values.get("updated_at") or _now(),
            **values,
        }
        with self.db.lock, self.db.connect() as conn:
            conn.execute(
                """
                insert or replace into local_records(table_name, id, data, created_at, updated_at)
                values (?, ?, ?, ?, ?)
                """,
                (
                    self.name,
                    row["id"],
                    json.dumps(row, default=_json_default),
                    str(row["created_at"]),
                    str(row["updated_at"]),
                ),
            )
            conn.commit()
        return dict(row)

    def update(self, filters: list[tuple[str, Any]], values: dict[str, Any]) -> list[dict[str, Any]]:
        matched = self.select(filters, None, None)
        updated = []
        for row in matched:
            row.update(values)
            row["updated_at"] = _now()
            updated.append(self._save(row))
        return updated

    def select(
        self,
        filters: list[tuple[str, Any]],
        or_filter: str | None,
        order_by: tuple[str, bool] | None,
    ) -> list[dict[str, Any]]:
        rows = self._all_rows()
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
            rows.sort(key=lambda row: str(row.get(column) or ""), reverse=desc)
        return rows

    def _all_rows(self) -> list[dict[str, Any]]:
        with self.db.lock, self.db.connect() as conn:
            records = conn.execute(
                "select data from local_records where table_name = ?",
                (self.name,),
            ).fetchall()
        return [json.loads(record["data"]) for record in records]

    def _save(self, row: dict[str, Any]) -> dict[str, Any]:
        with self.db.lock, self.db.connect() as conn:
            conn.execute(
                """
                update local_records
                set data = ?, updated_at = ?
                where table_name = ? and id = ?
                """,
                (
                    json.dumps(row, default=_json_default),
                    str(row["updated_at"]),
                    self.name,
                    row["id"],
                ),
            )
            conn.commit()
        return dict(row)


class LocalSupabase:
    def __init__(self, db_path: Path = DEFAULT_DB_PATH) -> None:
        self.db_path = db_path
        self.lock = RLock()
        self.db_path.parent.mkdir(parents=True, exist_ok=True)
        self._initialize()

    def connect(self) -> sqlite3.Connection:
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        return conn

    def table(self, name: str) -> LocalQuery:
        return LocalTable(self, name).query()

    def _initialize(self) -> None:
        with self.lock, self.connect() as conn:
            conn.execute(
                """
                create table if not exists local_records (
                    table_name text not null,
                    id text not null,
                    data text not null,
                    created_at text not null,
                    updated_at text not null,
                    primary key (table_name, id)
                )
                """
            )
            conn.execute(
                "create index if not exists local_records_table_idx on local_records(table_name)"
            )
            conn.commit()
        self._seed_demo_users()

    def _seed_demo_users(self) -> None:
        users = LocalTable(self, "users")
        if users.select([("id", OWNER_DEMO_ID)], None, None):
            return
        now = _now()
        users.insert(
            {
                "id": OWNER_DEMO_ID,
                "email": "owner@example.com",
                "full_name": "Shop Owner",
                "role": "super_admin",
                "status": "online",
                "created_at": now,
                "updated_at": now,
            }
        )
        users.insert(
            {
                "id": AGENT_DEMO_ID,
                "email": "agent@example.com",
                "full_name": "Support Agent",
                "role": "agent",
                "status": "online",
                "created_at": now,
                "updated_at": now,
            }
        )


local_supabase = LocalSupabase()
