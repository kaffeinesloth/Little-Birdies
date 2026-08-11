from collections.abc import Iterable
from typing import Any, Protocol

from pydantic import BaseModel

from app.services.exceptions import RecordNotFoundError


class QueryResult(Protocol):
    data: Any


class SupabaseQuery(Protocol):
    def select(self, columns: str = "*") -> "SupabaseQuery": ...

    def insert(self, values: dict[str, Any]) -> "SupabaseQuery": ...

    def update(self, values: dict[str, Any]) -> "SupabaseQuery": ...

    def eq(self, column: str, value: Any) -> "SupabaseQuery": ...

    def or_(self, filters: str) -> "SupabaseQuery": ...

    def order(self, column: str, desc: bool = False) -> "SupabaseQuery": ...

    def execute(self) -> QueryResult: ...


class SupabaseClient(Protocol):
    def table(self, name: str) -> SupabaseQuery: ...


def model_dump_for_supabase(model: BaseModel, *, exclude_unset: bool = False) -> dict[str, Any]:
    return model.model_dump(mode="json", exclude_none=True, exclude_unset=exclude_unset)


def first_record(data: Any, table: str, record_id: str) -> dict[str, Any]:
    if isinstance(data, list) and data:
        return data[0]
    if isinstance(data, dict):
        return data
    raise RecordNotFoundError(f"{table} record not found: {record_id}")


class TableService:
    def __init__(self, client: SupabaseClient, table_name: str) -> None:
        self.client = client
        self.table_name = table_name

    def create(self, payload: BaseModel) -> dict[str, Any]:
        result = self.client.table(self.table_name).insert(model_dump_for_supabase(payload)).execute()
        return first_record(result.data, self.table_name, "created")

    def get(self, record_id: str) -> dict[str, Any]:
        result = (
            self.client.table(self.table_name)
            .select("*")
            .eq("id", record_id)
            .execute()
        )
        return first_record(result.data, self.table_name, record_id)

    def update(self, record_id: str, payload: BaseModel) -> dict[str, Any]:
        values = model_dump_for_supabase(payload, exclude_unset=True)
        result = (
            self.client.table(self.table_name)
            .update(values)
            .eq("id", record_id)
            .execute()
        )
        return first_record(result.data, self.table_name, record_id)

    def list_by_ids(self, record_ids: Iterable[str]) -> list[dict[str, Any]]:
        records = []
        for record_id in record_ids:
            records.append(self.get(record_id))
        return records
