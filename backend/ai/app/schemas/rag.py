from typing import Any

from pydantic import BaseModel, Field, field_validator


class RAGAnswerRequest(BaseModel):
    question: str = Field(min_length=1, max_length=4000)
    top_k: int = Field(default=3, ge=1, le=10)

    @field_validator("question")
    @classmethod
    def question_must_not_be_empty(cls, value: str) -> str:
        if not value.strip():
            raise ValueError("question cannot be empty")
        return value


class RAGChunk(BaseModel):
    content: str
    score: float
    source: str | None = None
    metadata: dict[str, Any] = Field(default_factory=dict)


class RAGAnswerResponse(BaseModel):
    answer: str
    confidence: float
    chunks: list[RAGChunk]
    citations: list[dict[str, Any]] = Field(default_factory=list)
    should_escalate: bool = False
    used_fallback: bool = False
