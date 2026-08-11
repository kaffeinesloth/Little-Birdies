"""
rag/vector_store.py — Wrapper ChromaDB với Google text-embedding-004.

Multi-tenant: mỗi shop có 1 collection riêng biệt → data isolation.
Embedding: dùng google.genai SDK mới (sync) để tương thích với ChromaDB.
"""
from __future__ import annotations

import logging
from typing import TYPE_CHECKING

import chromadb
from chromadb import EmbeddingFunction, Embeddings

if TYPE_CHECKING:
    from chromadb import Collection

logger = logging.getLogger(__name__)


# ─────────────────────────────────────────────────────────────────────────────
# Custom Embedding Function (sync, tương thích ChromaDB interface)
# ─────────────────────────────────────────────────────────────────────────────

class GoogleEmbeddingFunction(EmbeddingFunction):
    """
    Wraps google.genai (new SDK) thành ChromaDB EmbeddingFunction.
    ChromaDB gọi sync nên dùng client sync (không phải aio).
    """

    def __init__(self, api_key: str, model: str = "text-embedding-004"):
        from google import genai
        self._client = genai.Client(api_key=api_key)
        self._model = model

    def __call__(self, input: list[str]) -> Embeddings:
        embeddings: Embeddings = []
        for text in input:
            response = self._client.models.embed_content(
                model=self._model,
                contents=text,
            )
            # response.embeddings[0].values → List[float]
            embeddings.append(response.embeddings[0].values)
        return embeddings


# ─────────────────────────────────────────────────────────────────────────────
# VectorStore
# ─────────────────────────────────────────────────────────────────────────────

class VectorStore:
    """
    ChromaDB persistent store với 1 collection / tenant.

    Usage:
        vs = VectorStore(api_key=..., persist_dir="./chroma_db")
        vs.add_chunks(tenant_id="abc", chunks=[...])
        results = vs.query(tenant_id="abc", query_text="giá bao nhiêu?")
    """

    def __init__(
        self,
        api_key: str,
        embedding_model: str = "text-embedding-004",
        persist_dir: str = "./chroma_db",
    ):
        self._client = chromadb.PersistentClient(path=persist_dir)
        self._embed_fn = GoogleEmbeddingFunction(api_key=api_key, model=embedding_model)
        logger.info("VectorStore initialized at %s", persist_dir)

    # ── Collection management ─────────────────────────────────────────────

    def _collection(self, tenant_id: str) -> "Collection":
        """Get hoặc tạo collection riêng cho tenant."""
        return self._client.get_or_create_collection(
            name=f"tenant_{tenant_id}",
            embedding_function=self._embed_fn,
            metadata={"hnsw:space": "cosine"},  # Dùng cosine similarity
        )

    # ── Write ─────────────────────────────────────────────────────────────

    def add_chunks(self, tenant_id: str, chunks: list[dict]) -> int:
        """
        Thêm danh sách chunks vào collection của tenant.

        Returns: số chunks đã thêm thành công
        """
        if not chunks:
            return 0

        collection = self._collection(tenant_id)

        ids       = [f"{c['metadata']['doc_id']}_{c['metadata']['chunk_index']}" for c in chunks]
        documents = [c["text"] for c in chunks]
        metadatas = [c["metadata"] for c in chunks]

        collection.add(ids=ids, documents=documents, metadatas=metadatas)
        logger.info("Added %d chunks for tenant=%s", len(chunks), tenant_id)
        return len(chunks)

    def delete_document(self, tenant_id: str, doc_id: str) -> int:
        """Xóa tất cả chunks của 1 document (khi user xóa tài liệu)."""
        collection = self._collection(tenant_id)
        existing = collection.get(where={"doc_id": doc_id})
        if not existing["ids"]:
            return 0
        collection.delete(ids=existing["ids"])
        logger.info("Deleted %d chunks for doc_id=%s", len(existing["ids"]), doc_id)
        return len(existing["ids"])

    def delete_tenant(self, tenant_id: str) -> None:
        """Reset toàn bộ knowledge base của 1 tenant."""
        try:
            self._client.delete_collection(f"tenant_{tenant_id}")
            logger.info("Deleted collection for tenant=%s", tenant_id)
        except Exception:
            pass  # Collection chưa tồn tại → bỏ qua

    # ── Read ──────────────────────────────────────────────────────────────

    def query(
        self,
        tenant_id: str,
        query_text: str,
        top_k: int = 5,
    ) -> list[dict]:
        """
        Tìm các chunks liên quan nhất bằng cosine similarity.

        Returns:
            list[{text, metadata, similarity}] — đã sort giảm dần theo similarity
        """
        collection = self._collection(tenant_id)

        # Nếu collection rỗng → trả về ngay
        if collection.count() == 0:
            logger.debug("Collection empty for tenant=%s", tenant_id)
            return []

        results = collection.query(
            query_texts=[query_text],
            n_results=min(top_k, collection.count()),
            include=["documents", "metadatas", "distances"],
        )

        return self._format(results)

    def count(self, tenant_id: str) -> int:
        """Số chunks đang có trong collection."""
        return self._collection(tenant_id).count()

    # ── Helpers ───────────────────────────────────────────────────────────

    @staticmethod
    def _format(raw: dict) -> list[dict]:
        docs      = raw["documents"][0]
        metas     = raw["metadatas"][0]
        distances = raw["distances"][0]   # cosine distance (0 = identical, 2 = opposite)

        return [
            {
                "text":       doc,
                "metadata":   meta,
                "similarity": round(1 - dist, 4),   # distance → similarity
            }
            for doc, meta, dist in zip(docs, metas, distances)
        ]
