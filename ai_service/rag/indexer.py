"""
rag/indexer.py — Background task: upload → extract → chunk → embed → store.

Chạy async bằng FastAPI BackgroundTasks sau khi API trả response upload.
Update trạng thái trong Supabase: INDEXING → DONE / FAILED.
"""
from __future__ import annotations

import logging
import os
import tempfile

logger = logging.getLogger(__name__)


class DocumentIndexer:
    """
    Điều phối toàn bộ pipeline indexing cho 1 document.

    Gọi sau khi file đã được lưu vào Supabase Storage.
    """

    def __init__(self, vector_store, db_queries):
        from rag.extractors import TextExtractor
        from rag.chunker    import DocumentChunker
        self._vs        = vector_store
        self._db        = db_queries
        self._extractor = TextExtractor()
        self._chunker   = DocumentChunker()

    async def index_document(
        self,
        tenant_id:  str,
        doc_id:     str,
        file_path:  str,    # Local path (đã download từ storage)
        file_name:  str,
        mime_type:  str,
    ) -> None:
        """
        Entry point cho background task.
        Update DB status sau khi xong (DONE hoặc FAILED).
        """
        logger.info("Indexing started: doc_id=%s tenant=%s file=%s", doc_id, tenant_id, file_name)

        try:
            # 1. Extract text
            text = self._extractor.extract(file_path, mime_type)
            if not text.strip():
                raise ValueError("Extracted text is empty — file có thể bị lỗi hoặc scan-only PDF")

            # 2. Chunk
            chunks = self._chunker.chunk(
                text=text,
                base_metadata={
                    "doc_id":    doc_id,
                    "doc_name":  file_name,
                    "tenant_id": tenant_id,
                },
            )
            if not chunks:
                raise ValueError("No valid chunks produced")

            # 3. Embed + store vào ChromaDB
            stored = self._vs.add_chunks(tenant_id=tenant_id, chunks=chunks)

            # 4. Update DB: DONE
            await self._db.update_document_status(
                doc_id=doc_id,
                status="DONE",
                chunks_count=stored,
            )
            logger.info(
                "Indexing DONE: doc_id=%s, %d chunks stored", doc_id, stored
            )

        except Exception as exc:
            logger.error("Indexing FAILED: doc_id=%s error=%s", doc_id, exc, exc_info=True)
            await self._db.update_document_status(
                doc_id=doc_id,
                status="FAILED",
                error_message=str(exc)[:500],
            )

        finally:
            # Dọn file temp nếu cần
            if os.path.exists(file_path) and tempfile.gettempdir() in file_path:
                os.remove(file_path)
