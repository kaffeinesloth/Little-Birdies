from fastapi import APIRouter

from app.schemas.classification import ClassificationRequest, ClassificationResponse
from app.services.classifier import classify_intent


router = APIRouter(tags=["classification"])


@router.post("/classify", response_model=ClassificationResponse)
async def classify(payload: ClassificationRequest) -> ClassificationResponse:
    return classify_intent(payload.message_text)
