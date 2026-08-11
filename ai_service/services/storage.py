"""
services/storage.py — Upload/download/delete files qua Supabase Storage.

Bucket: "knowledge-docs" (tạo thủ công trong Supabase dashboard).
Path:   {tenant_id}/{doc_id}/{filename}
"""
from __future__ import annotations

import logging
import os
import tempfile
from uuid import uuid4

logger = logging.getLogger(__name__)

_BUCKET = "knowledge-docs"


class StorageService:
    def __init__(self, db):
        self._db = db

    async def upload(
        self,
        tenant_id: str,
        file_bytes: bytes,
        file_name:  str,
        mime_type:  str,
    ) -> tuple[str, str]:
        """
        Upload file lên Supabase Storage.

        Returns:
            (doc_id, storage_path)
        """
        doc_id       = str(uuid4())
        storage_path = f"{tenant_id}/{doc_id}/{file_name}"

        await self._db.storage.from_(_BUCKET).upload(
            path=storage_path,
            file=file_bytes,
            file_options={"content-type": mime_type},
        )
        logger.info("Uploaded to storage: %s", storage_path)
        return doc_id, storage_path

    async def download_to_temp(self, storage_path: str) -> str:
        """
        Download file về temp file local.

        Returns: local file path (caller phải xóa sau khi dùng)
        """
        data = await self._db.storage.from_(_BUCKET).download(storage_path)

        suffix = os.path.splitext(storage_path)[-1] or ".bin"
        with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
            tmp.write(data)
            tmp_path = tmp.name

        logger.debug("Downloaded %s → %s", storage_path, tmp_path)
        return tmp_path

    async def delete(self, storage_path: str) -> None:
        await self._db.storage.from_(_BUCKET).remove([storage_path])
        logger.info("Deleted from storage: %s", storage_path)
