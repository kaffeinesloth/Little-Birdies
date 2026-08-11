from pathlib import Path
from uuid import uuid4

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status

from app.core.config import Settings, get_settings
from app.core.security import (
    AuthenticatedUser,
    require_agent_or_super_admin,
    require_super_admin,
)
from app.db.supabase import get_supabase_client
from app.schemas.common import DocumentFileType, EmbeddingStatus
from app.schemas.documents import DocumentCreate, DocumentUpdate
from app.services.ai_client import AIProcessingError, AIProcessor, get_ai_processor
from app.services.documents import DocumentService
from app.services.supabase_table import SupabaseClient


router = APIRouter(tags=["protected"])
UPLOAD_ROOT = Path(__file__).resolve().parents[3] / "uploads" / "knowledge_base"


@router.get("/dashboard")
async def dashboard(
    current_user: AuthenticatedUser = Depends(require_super_admin),
) -> dict[str, str]:
    return {"status": "ok", "scope": "dashboard", "user_id": current_user.id}


@router.get("/documents")
async def list_documents(
    current_user: AuthenticatedUser = Depends(require_super_admin),
    client: SupabaseClient = Depends(get_supabase_client),
) -> dict[str, object]:
    del current_user
    documents = DocumentService(client).list_documents()
    return {"items": documents, "count": len(documents)}


@router.post("/documents/upload", status_code=status.HTTP_201_CREATED)
async def upload_document(
    current_user: AuthenticatedUser = Depends(require_super_admin),
    file: UploadFile = File(...),
    client: SupabaseClient = Depends(get_supabase_client),
    ai_processor: AIProcessor = Depends(get_ai_processor),
    settings: Settings = Depends(get_settings),
) -> dict[str, object]:
    original_name = Path(file.filename or "knowledge-document.txt").name
    suffix = Path(original_name).suffix.lower().lstrip(".")
    if suffix not in {item.value for item in DocumentFileType}:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Only PDF, DOCX, and TXT files are supported.",
        )

    content = await file.read()
    if not content:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Uploaded file is empty.")
    if len(content) > settings.max_document_upload_bytes:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail="Document upload is larger than the configured limit.",
        )

    UPLOAD_ROOT.mkdir(parents=True, exist_ok=True)
    storage_name = f"{uuid4()}-{original_name}"
    storage_path = UPLOAD_ROOT / storage_name
    storage_path.write_bytes(content)

    document_service = DocumentService(client)
    document = document_service.create_document(
        DocumentCreate(
            name=original_name,
            file_url=str(storage_path),
            file_type=DocumentFileType(suffix),
            embedding_status=EmbeddingStatus.PROCESSING,
            chunk_count=0,
            uploaded_by=current_user.id,
        )
    )

    try:
        processed = ai_processor.process_document(
            document_id=str(document["id"]),
            file_url=str(storage_path),
            file_type=suffix,
            file_name=original_name,
            file_size_bytes=len(content),
        )
        document = document_service.update_document(
            str(document["id"]),
            DocumentUpdate(
                embedding_status=EmbeddingStatus(processed.embedding_status),
                chunk_count=processed.chunk_count,
            ),
        )
        return {"document": document, "processing": processed.__dict__}
    except (AIProcessingError, ValueError) as exc:
        document = document_service.update_document(
            str(document["id"]),
            DocumentUpdate(embedding_status=EmbeddingStatus.ERROR),
        )
        return {
            "document": document,
            "processing": {
                "document_id": str(document["id"]),
                "embedding_status": EmbeddingStatus.ERROR,
                "chunk_count": document.get("chunk_count", 0),
                "reason": str(exc),
            },
        }


@router.get("/staff")
async def staff_management(
    current_user: AuthenticatedUser = Depends(require_super_admin),
    client: SupabaseClient = Depends(get_supabase_client),
) -> dict[str, object]:
    del current_user
    users = client.table("users").select("*").order("created_at").execute().data or []
    return {"items": users, "count": len(users)}


@router.get("/channels")
async def channel_settings(
    current_user: AuthenticatedUser = Depends(require_super_admin),
    settings: Settings = Depends(get_settings),
) -> dict[str, object]:
    del current_user
    channels = [
        {
            "id": "web",
            "title": "Web chat",
            "body": "Receives messages through /webhooks/web-message.",
            "status": "active",
        },
        {
            "id": "facebook",
            "title": "Facebook",
            "body": "Messenger webhook is available when Facebook credentials are configured.",
            "status": "configured" if settings.facebook_page_access_token else "not_configured",
        },
        {
            "id": "email",
            "title": "Email",
            "body": "Email adapter is available when provider credentials are configured.",
            "status": "configured"
            if settings.mailgun_api_key or settings.sendgrid_api_key
            else "not_configured",
        },
    ]
    return {"items": channels, "count": len(channels)}


@router.get("/notifications")
async def list_notifications(
    current_user: AuthenticatedUser = Depends(require_agent_or_super_admin),
    client: SupabaseClient = Depends(get_supabase_client),
) -> dict[str, object]:
    rows = (
        client.table("notifications")
        .select("*")
        .eq("recipient_id", current_user.id)
        .order("created_at", desc=True)
        .execute()
        .data
        or []
    )
    return {"items": rows, "count": len(rows)}


@router.get("/inbox")
async def inbox(
    current_user: AuthenticatedUser = Depends(require_agent_or_super_admin),
) -> dict[str, str]:
    return {"status": "ok", "scope": "inbox", "user_id": current_user.id}
