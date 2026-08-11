"""
rag/chunker.py — Chia document thành các chunks nhỏ để embed.

Strategy: RecursiveCharacterTextSplitter
  - chunk_size  = 512  tokens (~400 từ tiếng Việt)
  - chunk_overlap = 64  (~12.5%) để giữ ngữ cảnh qua ranh giới chunk
  - Separators theo thứ tự ưu tiên: paragraph → sentence → word
"""
from __future__ import annotations

import logging

from langchain_text_splitters import RecursiveCharacterTextSplitter

logger = logging.getLogger(__name__)


class DocumentChunker:
    def __init__(
        self,
        chunk_size: int = 512,
        chunk_overlap: int = 64,
    ):
        self._splitter = RecursiveCharacterTextSplitter(
            chunk_size=chunk_size,
            chunk_overlap=chunk_overlap,
            # Separators ưu tiên từ thô đến mịn
            separators=["\n\n", "\n", "。", ".", "!", "?", "；", ";", " ", ""],
            length_function=len,
            is_separator_regex=False,
        )

    def chunk(self, text: str, base_metadata: dict) -> list[dict]:
        """
        Chia text thành danh sách chunks với metadata.

        Args:
            text: Text đã extract và clean
            base_metadata: dict gồm ít nhất {doc_id, doc_name, tenant_id}

        Returns:
            list[{text, metadata}]
        """
        if not text.strip():
            logger.warning("Empty text for doc_id=%s, skipping", base_metadata.get("doc_id"))
            return []

        raw_chunks = self._splitter.split_text(text)

        # Bỏ các chunk quá ngắn (< 30 chars) — thường là header/footer rác
        filtered = [c for c in raw_chunks if len(c.strip()) >= 30]

        chunks = [
            {
                "text": chunk,
                "metadata": {
                    **base_metadata,
                    "chunk_index": i,
                    "total_chunks": len(filtered),
                },
            }
            for i, chunk in enumerate(filtered)
        ]

        logger.debug(
            "Chunked doc_id=%s: %d raw → %d filtered chunks",
            base_metadata.get("doc_id"), len(raw_chunks), len(filtered),
        )
        return chunks
