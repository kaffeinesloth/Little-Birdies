"""
rag/pipeline.py — Facade: kết hợp Retriever + ResponseGenerator thành 1 interface.

AgentOrchestrator chỉ cần gọi pipeline.query() mà không cần biết detail bên trong.
"""
from __future__ import annotations

import logging

from rag.retriever  import Retriever
from rag.generator  import ResponseGenerator

logger = logging.getLogger(__name__)


class RAGPipeline:
    """
    Usage:
        pipeline = RAGPipeline(retriever, generator)
        result = await pipeline.query(
            tenant_id="abc",
            tenant_config={"shop_name": "Shop A"},
            question="Giá sản phẩm bao nhiêu?",
            history=[{"role": "user", "content": "Xin chào"}],
        )
        # result = {text, confidence, should_create_ticket, source_docs}
    """

    def __init__(self, retriever: Retriever, generator: ResponseGenerator):
        self._retriever  = retriever
        self._generator  = generator

    async def query(
        self,
        tenant_id:     str,
        tenant_config: dict,
        question:      str,
        history:       list[dict],
    ) -> dict:
        """
        Full RAG flow: retrieve → generate → return response dict.
        """
        # 1. Retrieve relevant chunks
        chunks, max_similarity = await self._retriever.retrieve(
            tenant_id=tenant_id,
            query=question,
        )

        logger.debug(
            "RAG query: tenant=%s similarity=%.3f chunks=%d",
            tenant_id, max_similarity, len(chunks),
        )

        # 2. Generate response
        return await self._generator.generate(
            tenant_config=tenant_config,
            question=question,
            chunks=chunks,
            history=history,
            max_similarity=max_similarity,
        )
