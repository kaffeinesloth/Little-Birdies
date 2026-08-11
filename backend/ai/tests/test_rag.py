from app.core.config import Settings
from app.schemas.rag import RAGChunk
from app.services.rag import DEFAULT_ESCALATION_MESSAGE, rag_answer


class MockEmbedder:
    def __init__(self) -> None:
        self.texts: list[str] = []

    def embed(self, texts: list[str]) -> list[list[float]]:
        self.texts = texts
        return [[0.2, 0.4, 0.6] for _ in texts]


class MockRetriever:
    def __init__(self, chunks: list[RAGChunk]) -> None:
        self.chunks = chunks
        self.embedding: list[float] | None = None
        self.top_k: int | None = None

    def query(self, *, embedding: list[float], top_k: int) -> list[RAGChunk]:
        self.embedding = embedding
        self.top_k = top_k
        return self.chunks[:top_k]


class MockAnswerer:
    def __init__(self, answer: str) -> None:
        self.answer_text = answer
        self.chunks: list[RAGChunk] = []

    def answer(self, *, question: str, chunks: list[RAGChunk], settings: Settings) -> str:
        self.chunks = chunks
        return self.answer_text


def policy_chunk(score: float = 0.91) -> RAGChunk:
    return RAGChunk(
        content="Customers can return unused items within 7 days with a receipt.",
        score=score,
        source="returns.txt",
        metadata={
            "document_id": "doc-returns",
            "file_name": "returns.txt",
            "chunk_index": 0,
            "source_ref": "text",
        },
    )


def test_rag_answer_found_uses_top_chunks_and_returns_citations() -> None:
    embedder = MockEmbedder()
    retriever = MockRetriever([policy_chunk()])
    answerer = MockAnswerer("You can return unused items within 7 days with a receipt.")

    response = rag_answer(
        "What is your return policy?",
        settings=Settings(rag_confidence_threshold=0.72, openai_api_key="test-key"),
        embedder=embedder,
        retriever=retriever,
        answerer=answerer,
    )

    assert embedder.texts == ["What is your return policy?"]
    assert retriever.embedding == [0.2, 0.4, 0.6]
    assert retriever.top_k == 3
    assert answerer.chunks == [policy_chunk()]
    assert response.answer == "You can return unused items within 7 days with a receipt."
    assert response.confidence == 0.91
    assert response.should_escalate is False
    assert response.citations[0]["document_id"] == "doc-returns"
    assert response.citations[0]["file_name"] == "returns.txt"


def test_rag_no_context_escalates_with_default_message() -> None:
    response = rag_answer(
        "Do you repair bicycles?",
        settings=Settings(rag_confidence_threshold=0.72),
        embedder=MockEmbedder(),
        retriever=MockRetriever([policy_chunk(score=0.2)]),
    )

    assert response.answer == DEFAULT_ESCALATION_MESSAGE
    assert response.confidence == 0.0
    assert response.should_escalate is True
    assert response.used_fallback is True
    assert response.chunks[0].score == 0.2


def test_rag_missing_llm_credentials_uses_deterministic_context_fallback() -> None:
    response = rag_answer(
        "What is your return policy?",
        settings=Settings(rag_confidence_threshold=0.72),
        embedder=MockEmbedder(),
        retriever=MockRetriever([policy_chunk()]),
    )

    assert response.answer.startswith("Based on returns.txt:")
    assert "return unused items within 7 days" in response.answer
    assert response.should_escalate is False
    assert response.used_fallback is True
