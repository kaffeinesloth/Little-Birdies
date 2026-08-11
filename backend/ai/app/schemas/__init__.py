"""Pydantic schemas for the AI service."""

from app.schemas.classification import ClassificationRequest, ClassificationResponse
from app.schemas.documents import DocumentProcessRequest, DocumentProcessResponse
from app.schemas.health import HealthResponse
from app.schemas.processing import ProcessMessageRequest, ProcessMessageResponse
from app.schemas.rag import RAGAnswerRequest, RAGAnswerResponse, RAGChunk

__all__ = [
    "ClassificationRequest",
    "ClassificationResponse",
    "DocumentProcessRequest",
    "DocumentProcessResponse",
    "HealthResponse",
    "ProcessMessageRequest",
    "ProcessMessageResponse",
    "RAGAnswerRequest",
    "RAGAnswerResponse",
    "RAGChunk",
]
