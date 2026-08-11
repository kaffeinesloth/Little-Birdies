from app.core.config import Settings, get_settings
from app.schemas.common import IntentType
from app.schemas.processing import ProcessMessageResponse
from app.services.classifier import classify_intent
from app.services.rag import answer_question


def process_message(
    *,
    source: str,
    sender_id: str,
    content: str,
    settings: Settings | None = None,
) -> ProcessMessageResponse:
    settings = settings or get_settings()
    classification = classify_intent(content, settings)

    if classification.intent == IntentType.SPAM:
        return ProcessMessageResponse(
            intent=classification.intent,
            confidence=classification.confidence,
            answer=None,
            should_escalate=False,
            reason=classification.reason,
            used_fallback=classification.used_fallback,
        )

    if classification.intent == IntentType.COMPLAINT:
        return ProcessMessageResponse(
            intent=classification.intent,
            confidence=classification.confidence,
            answer="I am sorry about that. I will ask a staff member to help right away.",
            should_escalate=True,
            reason=classification.reason,
            used_fallback=classification.used_fallback,
        )

    rag_result = answer_question(content, top_k=3, settings=settings)
    has_confident_answer = bool(rag_result.answer) and rag_result.confidence >= settings.rag_confidence_threshold
    return ProcessMessageResponse(
        intent=classification.intent,
        confidence=max(classification.confidence, rag_result.confidence),
        answer=rag_result.answer if has_confident_answer else None,
        should_escalate=not has_confident_answer,
        reason=(
            "RAG fallback has no confident context."
            if not has_confident_answer
            else "Answered from retrieved context."
        ),
        used_fallback=classification.used_fallback or rag_result.used_fallback,
    )
