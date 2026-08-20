"""
rag/retriever.py — Retrieve chunks từ VectorStore + MMR reranking.

MMR (Maximal Marginal Relevance): giảm duplicate chunks từ cùng 1 file,
tăng diversity của context → LLM có nhiều góc nhìn hơn.
"""
from __future__ import annotations

import logging

from config import settings
from rag.vector_store import VectorStore

logger = logging.getLogger(__name__)


class Retriever:
    def __init__(self, vector_store: VectorStore):
        self._vs = vector_store

    async def retrieve(
        self,
        tenant_id: str,
        query: str,
        top_k: int | None = None,
    ) -> tuple[list[dict], float]:
        """
        Retrieve chunks liên quan đến query.

        Returns:
            (chunks, max_similarity)
              chunks          — list[{text, metadata, similarity}] sau MMR
              max_similarity  — score cao nhất, dùng cho confidence check
        """
        k = top_k or settings.retrieval_top_k

        # 1. Vector search
        results = self._vs.query(tenant_id, query, top_k=k)
        if not results:
            logger.debug("No results from vector store for tenant=%s", tenant_id)
            return [], 0.0

        # Keyword boost cho các từ quan trọng
        q_words = [w.lower() for w in query.split() if len(w) > 2]
        for r in results:
            text_lower = r["text"].lower()
            overlap_count = sum(1 for w in q_words if w in text_lower)
            if overlap_count > 0:
                # Tăng điểm tương đồng nếu trùng từ khóa
                r["similarity"] = min(1.0, r["similarity"] + min(0.30, overlap_count * 0.08))

        # Sort lại sau khi boost
        results.sort(key=lambda x: x["similarity"], reverse=True)

        # 2. Filter theo similarity threshold
        threshold = settings.similarity_threshold
        filtered = [r for r in results if r["similarity"] >= threshold]

        if not filtered:
            logger.debug(
                "All results below threshold=%.2f for query='%s...'",
                threshold, query[:40],
            )
            return [], (results[0]["similarity"] if results else 0.0)

        # 3. MMR reranking: chọn tối đa 3 chunks diverse nhất
        diverse = self._mmr(filtered, top_k=3)

        max_sim = max(c["similarity"] for c in diverse)
        logger.debug(
            "Retrieved %d chunks (max_sim=%.3f) for query='%s...'",
            len(diverse), max_sim, query[:40],
        )
        return diverse, max_sim

    # ── MMR ──────────────────────────────────────────────────────────────────

    @staticmethod
    def _mmr(results: list[dict], top_k: int = 3) -> list[dict]:
        """
        Greedy MMR: lấy top-1 trước, sau đó mỗi bước chọn chunk có
        relevance cao nhưng ít overlap (khác doc_id) với chunks đã chọn.

        Đây là MMR đơn giản dựa trên doc_id diversity, không tính
        cosine giữa embeddings (đủ tốt cho demo, không cần phức tạp hơn).
        """
        if len(results) <= top_k:
            return results

        selected = [results[0]]
        candidates = results[1:]

        while len(selected) < top_k and candidates:
            best_score = -1.0
            best_idx   = 0

            for i, cand in enumerate(candidates):
                # Penalty nếu cùng doc_id với chunk đã chọn
                overlap_penalty = 0.15 * sum(
                    1 for s in selected
                    if s["metadata"].get("doc_id") == cand["metadata"].get("doc_id")
                )
                score = cand["similarity"] - overlap_penalty
                if score > best_score:
                    best_score = score
                    best_idx   = i

            selected.append(candidates.pop(best_idx))

        return selected
