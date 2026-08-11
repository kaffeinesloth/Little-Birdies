from collections.abc import Iterator
from uuid import uuid4

from fastapi.testclient import TestClient

from app.core.security import AuthenticatedUser, require_super_admin
from app.db.supabase import get_supabase_client
from app.main import create_app
from app.services.ai_client import AIDocumentProcessResult, get_ai_processor
from tests.fakes import FakeSupabase


class FakeAIProcessor:
    def __init__(self) -> None:
        self.calls: list[dict] = []

    def process_document(
        self,
        *,
        document_id: str,
        file_url: str,
        file_type: str,
        file_name: str | None = None,
        file_size_bytes: int = 0,
    ) -> AIDocumentProcessResult:
        self.calls.append(
            {
                "document_id": document_id,
                "file_url": file_url,
                "file_type": file_type,
                "file_name": file_name,
                "file_size_bytes": file_size_bytes,
            }
        )
        return AIDocumentProcessResult(
            document_id=document_id,
            embedding_status="ready",
            chunk_count=2,
            reason="processed",
        )


def test_upload_document_saves_metadata_and_processes_file() -> None:
    app = create_app()
    fake_db = FakeSupabase()
    fake_ai = FakeAIProcessor()
    user_id = str(uuid4())

    async def user() -> AuthenticatedUser:
        return AuthenticatedUser(
            id=user_id,
            email="owner@example.com",
            role="super_admin",
            status="online",
        )

    app.dependency_overrides[require_super_admin] = user
    app.dependency_overrides[get_supabase_client] = lambda: fake_db
    app.dependency_overrides[get_ai_processor] = lambda: fake_ai

    with TestClient(app) as client:
        response = client.post(
            "/documents/upload",
            files={"file": ("policy.txt", b"Refunds are available within 7 days.", "text/plain")},
        )

    assert response.status_code == 201
    document = response.json()["document"]
    assert document["name"] == "policy.txt"
    assert document["file_type"] == "txt"
    assert document["embedding_status"] == "ready"
    assert document["chunk_count"] == 2
    assert document["uploaded_by"] == user_id
    assert fake_ai.calls[0]["file_name"] == "policy.txt"
    assert fake_ai.calls[0]["file_size_bytes"] == 36


def test_upload_document_rejects_unsupported_file_type() -> None:
    app = create_app()

    async def user() -> AuthenticatedUser:
        return AuthenticatedUser(
            id=str(uuid4()),
            email="owner@example.com",
            role="super_admin",
            status="online",
        )

    app.dependency_overrides[require_super_admin] = user

    with TestClient(app) as client:
        response = client.post(
            "/documents/upload",
            files={"file": ("notes.csv", b"not,supported", "text/csv")},
        )

    assert response.status_code == 400
    assert "Only PDF, DOCX, and TXT" in response.json()["detail"]
