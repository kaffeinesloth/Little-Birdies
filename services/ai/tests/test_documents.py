from pathlib import Path

from fastapi.testclient import TestClient

from app.main import create_app
from app.schemas.common import EmbeddingStatus
from app.services.documents import InMemoryVectorStore, process_document


class MockEmbedder:
    def __init__(self) -> None:
        self.texts: list[str] = []

    def embed(self, texts: list[str]) -> list[list[float]]:
        self.texts = texts
        return [[0.1, 0.2, 0.3] for _ in texts]


def write_txt_fixture(tmp_path: Path) -> Path:
    path = tmp_path / "shipping-policy.txt"
    path.write_text(
        "Shipping Policy\n\n"
        "Orders in Ho Chi Minh City arrive in 1-2 business days. "
        "Orders outside the city arrive in 3-5 business days. "
        "Customers can contact support with their order number for tracking.",
        encoding="utf-8",
    )
    return path


def test_process_txt_document_extracts_chunks_embeds_and_stores(tmp_path: Path) -> None:
    fixture = write_txt_fixture(tmp_path)
    embedder = MockEmbedder()
    store = InMemoryVectorStore()

    response = process_document(
        document_id="doc-1",
        file_url=str(fixture),
        file_type="txt",
        file_name=fixture.name,
        file_size_bytes=fixture.stat().st_size,
        embedder=embedder,
        vector_store=store,
    )

    assert response.embedding_status == EmbeddingStatus.READY
    assert response.chunk_count == 1
    assert response.used_fallback is False
    assert embedder.texts[0].startswith("Shipping Policy")
    assert store.records[0]["metadata"] == {
        "document_id": "doc-1",
        "file_name": "shipping-policy.txt",
        "chunk_index": 0,
        "source_ref": "text",
    }


def test_documents_process_endpoint_enforces_10_mb_boundary(tmp_path: Path) -> None:
    fixture = write_txt_fixture(tmp_path)
    client = TestClient(create_app())

    response = client.post(
        "/documents/process",
        json={
            "document_id": "doc-too-large",
            "file_url": str(fixture),
            "file_type": "txt",
            "file_name": fixture.name,
            "file_size_bytes": 10 * 1024 * 1024 + 1,
        },
    )

    assert response.status_code == 422
    assert "less than or equal to 10485760" in response.text
