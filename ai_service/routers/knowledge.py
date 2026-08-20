"""
routers/knowledge.py — Knowledge base management cho Web Admin.

POST   /knowledge/upload              → upload + trigger indexing
GET    /knowledge/documents           → list tài liệu + status
DELETE /knowledge/documents/{doc_id}  → xóa tài liệu + vectors
"""
from __future__ import annotations

import os
import tempfile
import io
import re
from pathlib import Path
from uuid import uuid4

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, UploadFile, File, Query

from dependencies import get_db, get_indexer, get_vector_store
import db.queries as q
from config import settings

router = APIRouter()

_ALLOWED_MIME = {
    "application/pdf",
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    "application/msword",
    "text/plain",
}
_MAX_FILE_SIZE = 20 * 1024 * 1024   # 20 MB


def _uses_local_knowledge() -> bool:
    return settings.ai_provider.lower() in {"auto", "ollama"}


def _local_dir() -> Path:
    path = Path(settings.local_knowledge_dir)
    path.mkdir(parents=True, exist_ok=True)
    return path


def _extract_text(file_bytes: bytes, file_name: str, mime_type: str) -> str:
    extension = Path(file_name).suffix.lower()
    if mime_type == "application/pdf" or extension == ".pdf":
        from pypdf import PdfReader
        reader = PdfReader(io.BytesIO(file_bytes))
        return "\n\n".join(page.extract_text() or "" for page in reader.pages)
    if extension in {".docx", ".doc"}:
        from docx import Document
        document = Document(io.BytesIO(file_bytes))
        return "\n".join(paragraph.text for paragraph in document.paragraphs)
    return file_bytes.decode("utf-8", errors="ignore")


def _local_documents() -> list[dict]:
    documents = [{
        "id": "doc_default_sportgear",
        "file_name": "sportgear_store.txt",
        "status": "DONE",
        "chunks_count": 19,
    }]
    for path in sorted(_local_dir().glob("*.txt")):
        identifier, _, stored_name = path.stem.partition("__")
        text = path.read_text(encoding="utf-8", errors="ignore")
        documents.append({
            "id": identifier,
            "file_name": stored_name or path.name,
            "status": "DONE",
            "chunks_count": max(1, len(text) // 512),
        })
    return documents


@router.post("/upload")
async def upload_document(
    tenant_id:       str,
    background_tasks: BackgroundTasks,
    file:            UploadFile = File(...),
):
    """
    Upload tài liệu PDF/DOCX/TXT.
    File được lưu vào Supabase Storage, indexing chạy async (background).
    """
    # Validate mime type
    mime = file.content_type or ""
    if mime not in _ALLOWED_MIME:
        raise HTTPException(
            status_code=415,
            detail=f"Unsupported file type: {mime}. Allowed: PDF, DOCX, TXT",
        )

    # Đọc file vào memory để check size
    file_bytes = await file.read()
    if len(file_bytes) > _MAX_FILE_SIZE:
        raise HTTPException(status_code=413, detail="File too large (max 20 MB)")

    doc_id = str(uuid4())

    if _uses_local_knowledge():
        file_name = file.filename or "knowledge.txt"
        text = _extract_text(file_bytes, file_name, mime)
        if not text.strip():
            raise HTTPException(status_code=422, detail="No readable text found in document")
        safe_name = re.sub(r"[^A-Za-z0-9._-]+", "_", Path(file_name).name)[:100]
        (_local_dir() / f"{doc_id}__{safe_name}.txt").write_text(
            text,
            encoding="utf-8",
        )
        return {
            "doc_id": doc_id,
            "status": "DONE",
            "message": f"File '{file_name}' is ready for local RAG",
        }

    db = await get_db()
    indexer = await get_indexer()

    # Lưu record vào DB (status = INDEXING)
    await q.create_document(
        db,
        doc_id=doc_id,
        tenant_id=tenant_id,
        file_name=file.filename or "unknown",
        storage_path=f"{tenant_id}/{doc_id}/{file.filename}",
        mime_type=mime,
        file_size=len(file_bytes),
        uploaded_by="system",   # TODO: inject từ JWT token
    )

    # Lưu file vào temp để indexer đọc
    suffix = os.path.splitext(file.filename or "")[-1]
    with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
        tmp.write(file_bytes)
        tmp_path = tmp.name

    # Trigger indexing trong background
    background_tasks.add_task(
        indexer.index_document,
        tenant_id=tenant_id,
        doc_id=doc_id,
        file_path=tmp_path,
        file_name=file.filename or "unknown",
        mime_type=mime,
    )

    return {
        "doc_id":  doc_id,
        "status":  "INDEXING",
        "message": f"File '{file.filename}' is being processed. Check its status at /knowledge/documents",
    }


@router.get("/documents")
async def list_documents(
    tenant_id: str = Query(...),
):
    """Danh sách tài liệu + status indexing."""
    if _uses_local_knowledge():
        docs = _local_documents()
        return {"documents": docs, "total": len(docs)}
    db = await get_db()
    docs = await q.get_documents(db, tenant_id)
    return {"documents": docs, "total": len(docs)}


@router.delete("/documents/{doc_id}")
async def delete_document(
    doc_id:    str,
    tenant_id: str = Query(...),
):
    """Xóa tài liệu khỏi DB và ChromaDB."""
    if _uses_local_knowledge():
        if doc_id == "doc_default_sportgear":
            raise HTTPException(status_code=400, detail="Bundled demo knowledge cannot be deleted")
        deleted = 0
        for path in _local_dir().glob(f"{doc_id}__*.txt"):
            path.unlink(missing_ok=True)
            deleted += 1
        return {
            "doc_id": doc_id,
            "deleted_chunks": deleted,
            "status": "deleted",
        }

    db = await get_db()
    vs = get_vector_store()
    # Xóa vectors
    deleted_chunks = vs.delete_document(tenant_id=tenant_id, doc_id=doc_id)

    # Xóa DB record
    await q.delete_document(db, doc_id)

    return {
        "doc_id":         doc_id,
        "deleted_chunks": deleted_chunks,
        "status":         "deleted",
    }
