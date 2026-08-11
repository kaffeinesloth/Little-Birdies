from fastapi import APIRouter

from app.schemas.processing import ProcessMessageRequest, ProcessMessageResponse
from app.services.processor import process_message


router = APIRouter(tags=["processing"])


@router.post("/process-message", response_model=ProcessMessageResponse)
async def process(payload: ProcessMessageRequest) -> ProcessMessageResponse:
    return process_message(
        source=payload.source,
        sender_id=payload.sender_id,
        content=payload.content,
    )
