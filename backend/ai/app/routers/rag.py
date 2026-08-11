from fastapi import APIRouter

from app.schemas.rag import RAGAnswerRequest, RAGAnswerResponse
from app.services.rag import answer_question


router = APIRouter(prefix="/rag", tags=["rag"])


@router.post("/answer", response_model=RAGAnswerResponse)
async def rag_answer(payload: RAGAnswerRequest) -> RAGAnswerResponse:
    return answer_question(payload.question, top_k=payload.top_k)
