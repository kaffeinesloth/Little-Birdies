from typing import Any

from app.schemas.documents import DocumentCreate, DocumentUpdate
from app.services.supabase_table import SupabaseClient, TableService


class DocumentService(TableService):
    def __init__(self, client: SupabaseClient) -> None:
        super().__init__(client, "documents")

    def create_document(self, payload: DocumentCreate) -> dict[str, Any]:
        return self.create(payload)

    def get_document(self, document_id: str) -> dict[str, Any]:
        return self.get(document_id)

    def update_document(self, document_id: str, payload: DocumentUpdate) -> dict[str, Any]:
        return self.update(document_id, payload)

    def list_documents(self, *, limit: int = 50) -> list[dict[str, Any]]:
        result = (
            self.client.table(self.table_name)
            .select("*")
            .order("created_at", desc=True)
            .execute()
        )
        if not isinstance(result.data, list):
            return []
        return result.data[:limit]
