from dataclasses import dataclass
from typing import Any, Protocol

import httpx

from app.core.config import Settings, get_settings
from app.schemas.common import IntentType


FALLBACK_HANDOFF_MESSAGE = (
    "I'm sorry, I can't answer that confidently right now. "
    "I'll ask a staff member to help you."
)


class AIProcessingError(Exception):
    """Raised when the AI service cannot process a message."""


class AIClassifierTimeout(AIProcessingError):
    """Raised when only the classifier call times out."""


@dataclass(frozen=True)
class AIClassificationResult:
    intent: IntentType
    confidence: float
    reason: str | None = None

    @classmethod
    def from_payload(cls, payload: dict[str, Any]) -> "AIClassificationResult":
        return cls(
            intent=IntentType(payload.get("intent", IntentType.QUESTION)),
            confidence=float(payload.get("confidence", 0.0)),
            reason=payload.get("reason"),
        )


@dataclass(frozen=True)
class AIRAGResult:
    answer: str | None
    confidence: float
    should_escalate: bool
    citations: list[dict[str, Any]]
    reason: str | None = None

    @classmethod
    def from_payload(cls, payload: dict[str, Any]) -> "AIRAGResult":
        return cls(
            answer=payload.get("answer"),
            confidence=float(payload.get("confidence", 0.0)),
            should_escalate=bool(payload.get("should_escalate", False)),
            citations=payload.get("citations") or [],
            reason=payload.get("reason"),
        )


@dataclass(frozen=True)
class AIDocumentProcessResult:
    document_id: str
    embedding_status: str
    chunk_count: int
    reason: str | None = None

    @classmethod
    def from_payload(cls, payload: dict[str, Any]) -> "AIDocumentProcessResult":
        return cls(
            document_id=str(payload["document_id"]),
            embedding_status=str(payload["embedding_status"]),
            chunk_count=int(payload.get("chunk_count", 0)),
            reason=payload.get("reason"),
        )


@dataclass(frozen=True)
class AIProcessingResult:
    intent: IntentType
    confidence: float
    answer: str | None = None
    should_escalate: bool = False
    reason: str | None = None
    citations: list[dict[str, Any]] | None = None

    @classmethod
    def from_payload(cls, payload: dict[str, Any]) -> "AIProcessingResult":
        return cls(
            intent=IntentType(payload.get("intent", IntentType.QUESTION)),
            confidence=float(payload.get("confidence", 0.0)),
            answer=payload.get("answer") or payload.get("reply"),
            should_escalate=bool(payload.get("should_escalate", payload.get("escalate", False))),
            reason=payload.get("reason"),
            citations=payload.get("citations") or [],
        )


class AIProcessor(Protocol):
    def process_message(self, *, source: str, sender_id: str, content: str) -> AIProcessingResult: ...

    def process_document(
        self,
        *,
        document_id: str,
        file_url: str,
        file_type: str,
        file_name: str | None = None,
        file_size_bytes: int = 0,
    ) -> AIDocumentProcessResult: ...


class HTTPAIClient:
    def __init__(self, settings: Settings | None = None, timeout_seconds: float = 5.0) -> None:
        self.settings = settings or get_settings()
        self.timeout_seconds = timeout_seconds
        self.base_url = self.settings.ai_service_url.rstrip("/")

    def _post(self, path: str, payload: dict[str, Any]) -> dict[str, Any]:
        try:
            response = httpx.post(
                f"{self.base_url}{path}",
                json=payload,
                timeout=self.timeout_seconds,
            )
            response.raise_for_status()
        except httpx.TimeoutException as exc:
            if path == "/classify":
                raise AIClassifierTimeout("AI classifier timed out") from exc
            raise AIProcessingError(f"AI request timed out: {path}") from exc
        except httpx.HTTPError as exc:
            raise AIProcessingError(f"AI request failed: {path}") from exc
        return response.json()

    def classify(self, message_text: str) -> AIClassificationResult:
        return AIClassificationResult.from_payload(
            self._post("/classify", {"message_text": message_text})
        )

    def rag_answer(self, question: str, top_k: int = 3) -> AIRAGResult:
        return AIRAGResult.from_payload(
            self._post("/rag/answer", {"question": question, "top_k": top_k})
        )

    def process_full_message(self, *, source: str, sender_id: str, content: str) -> AIProcessingResult:
        return AIProcessingResult.from_payload(
            self._post(
                "/process-message",
                {"source": source, "sender_id": sender_id, "content": content},
            )
        )

    def process_document(
        self,
        *,
        document_id: str,
        file_url: str,
        file_type: str,
        file_name: str | None = None,
        file_size_bytes: int = 0,
    ) -> AIDocumentProcessResult:
        return AIDocumentProcessResult.from_payload(
            self._post(
                "/documents/process",
                {
                    "document_id": document_id,
                    "file_url": file_url,
                    "file_type": file_type,
                    "file_name": file_name,
                    "file_size_bytes": file_size_bytes,
                },
            )
        )

    def process_message(self, *, source: str, sender_id: str, content: str) -> AIProcessingResult:
        try:
            classification = self.classify(content)
        except AIClassifierTimeout:
            classification = AIClassificationResult(
                intent=IntentType.QUESTION,
                confidence=0.0,
                reason="Classifier timed out; defaulted to question.",
            )

        if classification.intent == IntentType.SPAM:
            return AIProcessingResult(
                intent=IntentType.SPAM,
                confidence=classification.confidence,
                should_escalate=False,
                reason=classification.reason,
            )

        if classification.intent == IntentType.COMPLAINT:
            return AIProcessingResult(
                intent=IntentType.COMPLAINT,
                confidence=classification.confidence,
                answer="I am sorry about that. A staff member will help right away.",
                should_escalate=True,
                reason=classification.reason,
            )

        rag = self.rag_answer(content, top_k=3)
        return AIProcessingResult(
            intent=IntentType.QUESTION,
            confidence=max(classification.confidence, rag.confidence),
            answer=rag.answer,
            should_escalate=rag.should_escalate,
            reason=rag.reason or classification.reason,
            citations=rag.citations,
        )


HTTPAIProcessor = HTTPAIClient


def get_ai_processor() -> AIProcessor:
    return HTTPAIClient()


def ai_timeout_fallback() -> AIProcessingResult:
    return AIProcessingResult(
        intent=IntentType.QUESTION,
        confidence=0.0,
        answer=FALLBACK_HANDOFF_MESSAGE,
        should_escalate=True,
        reason="AI service unavailable; saved fallback handoff for staff review.",
    )
