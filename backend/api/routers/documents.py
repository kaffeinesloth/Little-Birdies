import httpx
import os
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from urllib.parse import unquote, urlparse
from uuid import UUID

from core.auth import get_current_user, require_super_admin
from core.database import get_supabase_admin
from models.domain import APIResponse, MetaResponse, EmbeddingStatus

router = APIRouter()

ALLOWED_TYPES = {"application/pdf", "application/vnd.openxmlformats-officedocument.wordprocessingml.document", "text/plain"}
ALLOWED_EXTENSIONS = {".pdf", ".docx", ".txt"}
MAX_FILE_SIZE_MB = 10

AI_SERVICE_URL = os.getenv("AI_SERVICE_URL", "http://localhost:8001")
STORAGE_BUCKET = "knowledge-base"


def _storage_path_from_url(file_url: str) -> str | None:
    parsed_path = unquote(urlparse(file_url).path)
    markers = (
        f"/object/public/{STORAGE_BUCKET}/",
        f"/object/sign/{STORAGE_BUCKET}/",
    )
    for marker in markers:
        if marker in parsed_path:
            return parsed_path.split(marker, 1)[1]

    if parsed_path.startswith(f"{STORAGE_BUCKET}/"):
        return parsed_path[len(STORAGE_BUCKET) + 1:]

    return None


@router.get("", response_model=APIResponse)
def list_documents(current_user: dict = Depends(get_current_user)):
    """Lấy danh sách tài liệu đã upload vào Knowledge Base."""
    supabase = get_supabase_admin()

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
    # 1. Validate extension
    _, ext = os.path.splitext(file.filename or "")
    if ext.lower() not in ALLOWED_EXTENSIONS:
        raise HTTPException(
            status_code=400,
            detail=f"Chỉ hỗ trợ file PDF, DOCX, TXT. Nhận được: {ext}",
        )

    # Validate file size
    content = await file.read()
    size_mb = len(content) / (1024 * 1024)
    if size_mb > MAX_FILE_SIZE_MB:
        raise HTTPException(
            status_code=400,
            detail=f"File vượt quá giới hạn {MAX_FILE_SIZE_MB}MB.",
        )

    supabase = get_supabase_admin()

    # 2. Upload lên Supabase Storage bucket "knowledge-base"
    storage_path = f"knowledge-base/{current_user['id']}/{file.filename}"
    try:
        supabase.storage.from_(STORAGE_BUCKET).upload(
            path=storage_path,
            file=content,
            file_options={"content-type": file.content_type or "application/octet-stream"},
        )
        file_url = supabase.storage.from_(STORAGE_BUCKET).get_public_url(storage_path)
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Upload file thất bại: {str(e)}",
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
        raise HTTPException(status_code=500, detail="Không thể lưu thông tin tài liệu.")

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
        meta=MetaResponse(code=202, message="Tài liệu đang được xử lý."),
        data={"document_id": document_id, "status": EmbeddingStatus.processing.value},
    )


@router.delete("/{document_id}", response_model=APIResponse)
def delete_document(
    document_id: UUID,
    current_user: dict = Depends(require_super_admin),
):
    """super_admin xóa tài liệu khỏi Knowledge Base."""
    supabase = get_supabase_admin()

    # Lấy thông tin trước khi xóa (để xóa file trên Storage)
    doc = (
        supabase.table("documents")
        .select("id, file_url, name")
        .eq("id", str(document_id))
        .single()
        .execute()
    )

    if not doc.data:
        raise HTTPException(status_code=404, detail="Tài liệu không tồn tại.")

    storage_path = _storage_path_from_url(doc.data.get("file_url") or "")
    if storage_path:
        try:
            supabase.storage.from_(STORAGE_BUCKET).remove([storage_path])
        except Exception as e:
            raise HTTPException(
                status_code=500,
                detail=f"Xóa file trên Storage thất bại: {str(e)}",
            )

    # Xóa record trong DB
    supabase.table("documents").delete().eq("id", str(document_id)).execute()

    # TODO: Xóa vector embeddings trong ChromaDB (gọi AI service)

    return APIResponse(
        meta=MetaResponse(code=200, message="Tài liệu đã được xóa."),
        data=None,
    )
