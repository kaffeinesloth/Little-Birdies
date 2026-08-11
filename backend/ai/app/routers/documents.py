from fastapi import APIRouter, HTTPException, status

from app.schemas.documents import DocumentProcessRequest, DocumentProcessResponse
from app.services.documents import DocumentProcessingError, process_document


router = APIRouter(prefix="/documents", tags=["documents"])


@router.post("/process", response_model=DocumentProcessResponse)
async def process(payload: DocumentProcessRequest) -> DocumentProcessResponse:
    try:
        return process_document(
            document_id=payload.document_id,
            file_url=payload.file_url,
            file_type=payload.file_type,
            file_name=payload.file_name,
            file_size_bytes=payload.file_size_bytes,
        )
    except DocumentProcessingError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exc),
        ) from exc
