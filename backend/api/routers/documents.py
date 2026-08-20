import os
import httpx
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from uuid import UUID, uuid4

from core.auth import get_current_user, require_super_admin
from core.database import get_supabase_client, get_supabase_admin
from models.domain import APIResponse, MetaResponse, EmbeddingStatus

router = APIRouter()

ALLOWED_TYPES = {"application/pdf", "application/vnd.openxmlformats-officedocument.wordprocessingml.document", "text/plain"}
ALLOWED_EXTENSIONS = {".pdf", ".docx", ".txt"}
MAX_FILE_SIZE_MB = 10

MIME_BY_EXTENSION = {
    ".pdf": "application/pdf",
    ".docx": "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    ".txt": "text/plain",
}

AI_SERVICE_URL = os.getenv("AI_SERVICE_URL", "http://ai-service:8001")


# ── Demo Admin Knowledge Base Endpoints (No Auth needed for Web Admin Demo) ────

@router.get("/demo-list", response_model=APIResponse)
async def list_demo_documents():
    """Lấy danh sách tài liệu thật đã Index vào ChromaDB cho Web Admin"""
    docs = []
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            ai_res = await client.get(f"{AI_SERVICE_URL}/knowledge/documents", params={"tenant_id": "default"})
            if ai_res.status_code == 200:
                raw_docs = ai_res.json().get("documents", [])
                for d in raw_docs:
                    if d.get("status") == "DONE":
                        file_name = d.get("file_name") or "document.txt"
                        file_extension = os.path.splitext(file_name)[1].lower()
                        docs.append({
                            "id": d.get("id"),
                            "name": file_name,
                            "file_type": file_extension.lstrip(".") or "txt",
                            "embedding_status": "completed",
                            "chunk_count": d.get("chunks_count", 6),
                            "created_at": d.get("created_at"),
                        })
    except Exception as e:
        print(f"Error fetching docs from AI Service: {e}")

    # Lọc unique theo name để hiển thị đẹp
    unique_docs = {}
    for d in docs:
        if d["name"] not in unique_docs:
            unique_docs[d["name"]] = d

    final_list = list(unique_docs.values())
    if not final_list:
        final_list = [{
            "id": "doc_default_sportgear",
            "name": "sportgear_store.txt (6 Products & Support Policies)",
            "file_type": "txt",
            "embedding_status": "completed",
            "chunk_count": 19,
            "created_at": "2026-08-18T00:00:00Z",
        }]

    return APIResponse(
        meta=MetaResponse(code=200, message="Success"),
        data=final_list,
    )


@router.post("/demo-upload", response_model=APIResponse, status_code=201)
async def upload_demo_document(file: UploadFile = File(...)):
    """
    Nhận upload file thật (.txt, .pdf, .docx) từ Flutter Web Admin,
    gửi sang AI Service để Chunking + Vector Embedding vào ChromaDB và lưu DB.
    """
    _, ext = os.path.splitext(file.filename or "")
    if ext.lower() not in ALLOWED_EXTENSIONS:
        raise HTTPException(
            status_code=400,
            detail=f"Only PDF, DOCX, and TXT are supported. Received: {ext}",
        )

    content = await file.read()
    if len(content) > MAX_FILE_SIZE_MB * 1024 * 1024:
        raise HTTPException(status_code=400, detail=f"File exceeds the {MAX_FILE_SIZE_MB} MB limit.")

    file_type_map = {".pdf": "pdf", ".docx": "docx", ".txt": "txt"}
    file_type = file_type_map.get(ext.lower(), "txt")

    # 1. Gửi sang AI Service /knowledge/upload để index vào ChromaDB
    try:
        async with httpx.AsyncClient(timeout=30.0) as client:
            ai_res = await client.post(
                f"{AI_SERVICE_URL}/knowledge/upload",
                params={"tenant_id": "default"},
                files={"file": (file.filename, content, MIME_BY_EXTENSION[ext.lower()])},
            )
    except Exception as e:
        print(f"Error forwarding to AI Service: {e}")
        raise HTTPException(status_code=502, detail="AI knowledge service is unavailable")

    if ai_res.status_code < 200 or ai_res.status_code >= 300:
        raise HTTPException(
            status_code=502,
            detail=f"AI knowledge indexing failed: {ai_res.text[:200]}",
        )
    ai_payload = ai_res.json()
    doc_id = ai_payload.get("doc_id") or str(uuid4())

    # 2. Lưu vào Supabase documents table nếu cấu hình demo có sẵn.
    new_doc = {
        "id": doc_id,
        "name": file.filename or "new_knowledge.txt",
        "file_type": file_type,
        "embedding_status": "completed",
        "chunk_count": max(4, len(content) // 256),
    }
    try:
        supabase = get_supabase_admin()
        supabase.table("documents").insert(new_doc).execute()
    except Exception as e:
        print(f"Error saving to supabase: {e}")

    return APIResponse(
        meta=MetaResponse(code=201, message=f"Document '{file.filename}' uploaded and indexed successfully."),
        data=new_doc,
    )


@router.delete("/demo-delete/{doc_id}", response_model=APIResponse)
async def delete_demo_document(doc_id: str):
    """Xóa tài liệu khỏi database và ChromaDB"""
    try:
        supabase = get_supabase_admin()
        supabase.table("documents").delete().eq("id", doc_id).execute()
    except Exception as e:
        print(f"Error deleting document from supabase: {e}")

    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            await client.delete(
                f"{AI_SERVICE_URL}/knowledge/documents/{doc_id}",
                params={"tenant_id": "default"},
            )
    except Exception:
        pass

    return APIResponse(
        meta=MetaResponse(code=200, message="Document removed from the knowledge base."),
        data={"id": doc_id},
    )


# ── Standard Auth Endpoints ──────────────────────────────────────────────────


@router.get("", response_model=APIResponse)
def list_documents(current_user: dict = Depends(get_current_user)):
    """Lấy danh sách tài liệu đã upload vào Knowledge Base."""
    supabase = get_supabase_client()

    result = (
        supabase.table("documents")
        .select("id, name, file_type, embedding_status, chunk_count, uploaded_by, created_at")
        .order("created_at", desc=True)
        .execute()
    )

    return APIResponse(
        meta=MetaResponse(code=200, message="Success"),
        data=result.data,
    )


@router.post("", response_model=APIResponse, status_code=202)
async def upload_document(
    file: UploadFile = File(...),
    current_user: dict = Depends(require_super_admin),
):
    """
    super_admin upload tài liệu (PDF/DOCX/TXT) để làm Knowledge Base cho AI.
    Luồng:
    1. Validate file type + size
    2. Upload lên Supabase Storage
    3. Tạo bản ghi trong bảng documents (status=processing)
    4. Gọi AI service để chunk + embed (bất đồng bộ)
    5. Trả về 202 + document_id
    """
    import os

    # 1. Validate extension
    _, ext = os.path.splitext(file.filename or "")
    if ext.lower() not in ALLOWED_EXTENSIONS:
        raise HTTPException(
            status_code=400,
            detail=f"Only PDF, DOCX, and TXT are supported. Received: {ext}",
        )

    # Validate file size
    content = await file.read()
    size_mb = len(content) / (1024 * 1024)
    if size_mb > MAX_FILE_SIZE_MB:
        raise HTTPException(
            status_code=400,
            detail=f"File exceeds the {MAX_FILE_SIZE_MB} MB limit.",
        )

    supabase = get_supabase_client()

    # 2. Upload lên Supabase Storage bucket "knowledge-base"
    storage_path = f"knowledge-base/{current_user['id']}/{file.filename}"
    try:
        supabase.storage.from_("knowledge-base").upload(
            path=storage_path,
            file=content,
            file_options={"content-type": file.content_type or "application/octet-stream"},
        )
        file_url = supabase.storage.from_("knowledge-base").get_public_url(storage_path)
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"File upload failed: {str(e)}",
        )

    # Map extension → file_type enum
    file_type_map = {".pdf": "pdf", ".docx": "docx", ".txt": "txt"}
    file_type = file_type_map[ext.lower()]

    # 3. Tạo bản ghi document
    doc_result = (
        supabase.table("documents")
        .insert({
            "name": file.filename,
            "file_url": file_url,
            "file_type": file_type,
            "embedding_status": EmbeddingStatus.processing.value,
            "uploaded_by": current_user["id"],
        })
        .execute()
    )

    if not doc_result.data:
        raise HTTPException(status_code=500, detail="Could not save document information.")

    document_id = doc_result.data[0]["id"]

    # 4. Gọi AI service để xử lý embedding (fire-and-forget)
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            await client.post(
                f"{AI_SERVICE_URL}/embed",
                json={
                    "document_id": document_id,
                    "file_url": file_url,
                    "file_type": file_type,
                },
            )
    except Exception:
        # AI service sẽ xử lý sau; status vẫn là "processing"
        pass

    return APIResponse(
        meta=MetaResponse(code=202, message="Document is being processed."),
        data={"document_id": document_id, "status": EmbeddingStatus.processing.value},
    )


@router.delete("/{document_id}", response_model=APIResponse)
def delete_document(
    document_id: UUID,
    current_user: dict = Depends(require_super_admin),
):
    """super_admin xóa tài liệu khỏi Knowledge Base."""
    supabase = get_supabase_client()

    # Lấy thông tin trước khi xóa (để xóa file trên Storage)
    doc = (
        supabase.table("documents")
        .select("id, file_url, name")
        .eq("id", str(document_id))
        .single()
        .execute()
    )

    if not doc.data:
        raise HTTPException(status_code=404, detail="Document not found.")

    # Xóa record trong DB
    supabase.table("documents").delete().eq("id", str(document_id)).execute()

    # TODO: Xóa vector embeddings trong ChromaDB (gọi AI service)

    return APIResponse(
        meta=MetaResponse(code=200, message="Document deleted."),
        data=None,
    )
