from __future__ import annotations

import json
from typing import Any, Protocol

import httpx

from app.core.config import Settings, get_settings
from app.schemas.rag import RAGAnswerResponse, RAGChunk
from app.services.documents import Embedder, get_embedder


DEFAULT_ESCALATION_MESSAGE = (
    "I'm sorry, I don't have enough information to answer that accurately. "
    "I'll ask a staff member to help you."
)
RAG_SYSTEM_PROMPT = (
    "Answer using only the provided support context. If the context does not "
    "contain the policy, say you do not have enough information. Return JSON "
    "with answer only."
)


class RAGAnswerError(Exception):
    """Raised when RAG answer generation fails."""


class ChunkRetriever(Protocol):
    def query(self, *, embedding: list[float], top_k: int) -> list[RAGChunk]: ...


class LLMAnswerer(Protocol):
    def answer(self, *, question: str, chunks: list[RAGChunk], settings: Settings) -> str: ...


class ChromaChunkRetriever:
    def __init__(self, settings: Settings) -> None:
        self.settings = settings

    def query(self, *, embedding: list[float], top_k: int) -> list[RAGChunk]:
        try:
            import chromadb

            if self.settings.chroma_db_host:
                client = chromadb.HttpClient(host=self.settings.chroma_db_host)
            else:
                client = chromadb.PersistentClient(path=self.settings.chroma_db_path)
            collection = client.get_or_create_collection("smart_helpdesk_knowledge_base")
            result = collection.query(query_embeddings=[embedding], n_results=top_k)
        except Exception as exc:
            raise RAGAnswerError("Failed to retrieve chunks from ChromaDB") from exc

        documents = (result.get("documents") or [[]])[0]
        metadatas = (result.get("metadatas") or [[]])[0]
        distances = (result.get("distances") or [[]])[0]
        chunks = []
        for index, document in enumerate(documents):
            distance = float(distances[index]) if index < len(distances) else 1.0
            score = max(0.0, min(1.0, 1.0 - distance))
            metadata = metadatas[index] if index < len(metadatas) and metadatas[index] else {}
            chunks.append(
                RAGChunk(
                    content=document,
                    score=score,
                    source=metadata.get("source_ref") or metadata.get("file_name"),
                    metadata=metadata,
                )
            )
        return chunks


class HTTPContextAnswerer:
    def answer(self, *, question: str, chunks: list[RAGChunk], settings: Settings) -> str:
        context = "\n\n".join(
            f"[{index + 1}] {chunk.content}" for index, chunk in enumerate(chunks)
        )
        if settings.openai_api_key:
            return self._answer_with_openai(question=question, context=context, settings=settings)
        if settings.gemini_api_key:
            return self._answer_with_gemini(question=question, context=context, settings=settings)
        raise RAGAnswerError("No LLM provider configured")

    def _answer_with_openai(self, *, question: str, context: str, settings: Settings) -> str:
        response = httpx.post(
            "https://api.openai.com/v1/chat/completions",
            headers={"Authorization": f"Bearer {settings.openai_api_key}"},
            json={
                "model": settings.openai_chat_model,
                "temperature": 0,
                "response_format": {"type": "json_object"},
                "messages": [
                    {"role": "system", "content": RAG_SYSTEM_PROMPT},
                    {"role": "user", "content": f"Context:\n{context}\n\nQuestion: {question[:1000]}"},
                ],
            },
            timeout=settings.llm_timeout_seconds,
        )
        response.raise_for_status()
        payload = json.loads(response.json()["choices"][0]["message"]["content"])
        return str(payload.get("answer") or DEFAULT_ESCALATION_MESSAGE)

    def _answer_with_gemini(self, *, question: str, context: str, settings: Settings) -> str:
        response = httpx.post(
            f"https://generativelanguage.googleapis.com/v1beta/models/{settings.gemini_model}:generateContent",
            params={"key": settings.gemini_api_key},
            json={
                "generationConfig": {"temperature": 0, "responseMimeType": "application/json"},
                "contents": [
                    {
                        "parts": [
                            {"text": f"{RAG_SYSTEM_PROMPT}\nContext:\n{context}\nQuestion: {question[:1000]}"},
                        ]
                    }
                ],
            },
            timeout=settings.llm_timeout_seconds,
        )
        response.raise_for_status()
        payload = json.loads(response.json()["candidates"][0]["content"]["parts"][0]["text"])
        return str(payload.get("answer") or DEFAULT_ESCALATION_MESSAGE)


class DeterministicContextAnswerer:
    def answer(self, *, question: str, chunks: list[RAGChunk], settings: Settings) -> str:
        best_chunk = max(chunks, key=lambda chunk: chunk.score)
        source = best_chunk.metadata.get("file_name") or best_chunk.source or "knowledge base"
        return f"Based on {source}: {best_chunk.content}"


def get_chunk_retriever(settings: Settings) -> ChunkRetriever:
    return ChromaChunkRetriever(settings)


def get_answerer(settings: Settings) -> LLMAnswerer:
    if settings.has_llm_provider:
        return HTTPContextAnswerer()
    return DeterministicContextAnswerer()


def _citations(chunks: list[RAGChunk]) -> list[dict[str, Any]]:
    citations = []
    for chunk in chunks:
        citations.append(
            {
                "score": chunk.score,
                "source": chunk.source,
                **chunk.metadata,
            }
        )
    return citations


def rag_answer(
    question: str,
    *,
    top_k: int = 3,
    settings: Settings | None = None,
    embedder: Embedder | None = None,
    retriever: ChunkRetriever | None = None,
    answerer: LLMAnswerer | None = None,
) -> RAGAnswerResponse:
    settings = settings or get_settings()
    active_embedder = embedder or get_embedder(settings)
    active_retriever = retriever or get_chunk_retriever(settings)
    active_answerer = answerer or get_answerer(settings)

    question_embedding = active_embedder.embed([question])[0]
    retrieved_chunks = active_retriever.query(embedding=question_embedding, top_k=top_k)
    confident_chunks = [
        chunk for chunk in retrieved_chunks if chunk.score >= settings.rag_confidence_threshold
    ][:top_k]

    if not confident_chunks:
        return RAGAnswerResponse(
            answer=DEFAULT_ESCALATION_MESSAGE,
            confidence=0.0,
            chunks=retrieved_chunks[:top_k],
            citations=_citations(retrieved_chunks[:top_k]),
            should_escalate=True,
            used_fallback=True,
        )

    confidence = max(chunk.score for chunk in confident_chunks)
    try:
        answer = active_answerer.answer(question=question, chunks=confident_chunks, settings=settings)
        used_fallback = isinstance(active_answerer, DeterministicContextAnswerer)
    except (RAGAnswerError, httpx.HTTPError, json.JSONDecodeError, KeyError, IndexError):
        answer = DeterministicContextAnswerer().answer(
            question=question,
            chunks=confident_chunks,
            settings=settings,
        )
        used_fallback = True

    return RAGAnswerResponse(
        answer=answer,
        confidence=confidence,
        chunks=confident_chunks,
        citations=_citations(confident_chunks),
        should_escalate=False,
        used_fallback=used_fallback,
    )


def answer_question(question: str, top_k: int = 3, settings: Settings | None = None) -> RAGAnswerResponse:
    return rag_answer(question, top_k=top_k, settings=settings)
