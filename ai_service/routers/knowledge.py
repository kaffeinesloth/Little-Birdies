"""
routers/knowledge.py — Knowledge base management cho Web Admin.

POST   /knowledge/upload              → upload + trigger indexing
GET    /knowledge/documents           → list tài liệu + status
DELETE /knowledge/documents/{doc_id}  → xóa tài liệu + vectors
"""
from __future__ import annotations

import os
import tempfile

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, UploadFile, File, Query

from dependencies import get_db, get_indexer, get_vector_store
import db.queries as q

router = APIRouter()

_ALLOWED_MIME = {
    "application/pdf",
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    "application/msword",
    "text/plain",
}
_MAX_FILE_SIZE = 20 * 1024 * 1024   # 20 MB


@router.post("/upload")
async def upload_document(
    tenant_id:       str,
    background_tasks: BackgroundTasks,
    file:            UploadFile = File(...),
    db               = Depends(get_db),
    indexer          = Depends(get_indexer),
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

    from uuid import uuid4
    doc_id = str(uuid4())

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
        "message": f"File '{file.filename}' đang được xử lý. Kiểm tra status tại /knowledge/documents",
    }


@router.get("/documents")
async def list_documents(
    tenant_id: str = Query(...),
    db         = Depends(get_db),
):
    """Danh sách tài liệu + status indexing."""
    docs = await q.get_documents(db, tenant_id)
    return {"documents": docs, "total": len(docs)}


@router.delete("/documents/{doc_id}")
async def delete_document(
    doc_id:    str,
    tenant_id: str = Query(...),
    db         = Depends(get_db),
    vs         = Depends(get_vector_store),
):
    """Xóa tài liệu khỏi DB và ChromaDB."""
    # Xóa vectors
    deleted_chunks = vs.delete_document(tenant_id=tenant_id, doc_id=doc_id)

    # Xóa DB record
    await q.delete_document(db, doc_id)

    return {
        "doc_id":         doc_id,
        "deleted_chunks": deleted_chunks,
        "status":         "deleted",
    }
