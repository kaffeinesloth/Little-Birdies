from __future__ import annotations

import hashlib
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Protocol
from urllib.parse import urlparse

import httpx

from app.core.config import Settings, get_settings
from app.schemas.common import DocumentFileType, EmbeddingStatus
from app.schemas.documents import DocumentProcessResponse, MAX_DOCUMENT_BYTES


class DocumentProcessingError(Exception):
    """Raised for document extraction, embedding, or storage failures."""


class UnsupportedFileTypeError(DocumentProcessingError):
    """Raised when a document file type is not supported."""


class FileTooLargeError(DocumentProcessingError):
    """Raised when a document exceeds the configured size limit."""


class ExtractionError(DocumentProcessingError):
    """Raised when text extraction fails."""


class EmbeddingStorageError(DocumentProcessingError):
    """Raised when embedding generation or vector storage fails."""


@dataclass(frozen=True)
class ExtractedSection:
    text: str
    source_ref: str | None = None


@dataclass(frozen=True)
class DocumentChunk:
    text: str
    metadata: dict[str, Any]


class Embedder(Protocol):
    def embed(self, texts: list[str]) -> list[list[float]]: ...


class VectorStore(Protocol):
    def store(self, *, ids: list[str], texts: list[str], embeddings: list[list[float]], metadatas: list[dict[str, Any]]) -> None: ...


def _read_bytes(file_url: str, expected_size: int | None = None) -> tuple[bytes, str]:
    if expected_size is not None and expected_size > MAX_DOCUMENT_BYTES:
        raise FileTooLargeError("Document exceeds the 10 MB size limit")

    parsed = urlparse(file_url)
    if parsed.scheme in {"http", "https"}:
        response = httpx.get(file_url, timeout=20)
        response.raise_for_status()
        data = response.content
        file_name = Path(parsed.path).name or "document"
    else:
        path = Path(file_url)
        data = path.read_bytes()
        file_name = path.name

    if len(data) > MAX_DOCUMENT_BYTES:
        raise FileTooLargeError("Document exceeds the 10 MB size limit")
    return data, file_name


def _extract_txt(data: bytes) -> list[ExtractedSection]:
    try:
        text = data.decode("utf-8")
    except UnicodeDecodeError:
        text = data.decode("utf-8", errors="replace")
    text = text.strip()
    if not text:
        raise ExtractionError("TXT document contains no extractable text")
    return [ExtractedSection(text=text, source_ref="text")]


def _extract_pdf(data: bytes) -> list[ExtractedSection]:
    try:
        from io import BytesIO

        from pypdf import PdfReader

        reader = PdfReader(BytesIO(data))
        sections = []
        for index, page in enumerate(reader.pages, start=1):
            text = (page.extract_text() or "").strip()
            if text:
                sections.append(ExtractedSection(text=text, source_ref=f"page {index}"))
        if not sections:
            raise ExtractionError("PDF document contains no extractable text")
        return sections
    except DocumentProcessingError:
        raise
    except Exception as exc:
        raise ExtractionError("Failed to extract text from PDF") from exc


def _extract_docx(data: bytes) -> list[ExtractedSection]:
    try:
        from io import BytesIO

        from docx import Document

        document = Document(BytesIO(data))
        sections = []
        current_heading = "section 1"
        current_text: list[str] = []
        for paragraph in document.paragraphs:
            text = paragraph.text.strip()
            if not text:
                continue
            style_name = (paragraph.style.name or "").casefold()
            if "heading" in style_name:
                if current_text:
                    sections.append(ExtractedSection(text="\n".join(current_text), source_ref=current_heading))
                    current_text = []
                current_heading = text[:80]
            else:
                current_text.append(text)
        if current_text:
            sections.append(ExtractedSection(text="\n".join(current_text), source_ref=current_heading))
        if not sections:
            raise ExtractionError("DOCX document contains no extractable text")
        return sections
    except DocumentProcessingError:
        raise
    except Exception as exc:
        raise ExtractionError("Failed to extract text from DOCX") from exc


def extract_text_sections(data: bytes, file_type: DocumentFileType) -> list[ExtractedSection]:
    if file_type == DocumentFileType.TXT:
        return _extract_txt(data)
    if file_type == DocumentFileType.PDF:
        return _extract_pdf(data)
    if file_type == DocumentFileType.DOCX:
        return _extract_docx(data)
    raise UnsupportedFileTypeError(f"Unsupported file type: {file_type}")


def chunk_sections(
    sections: list[ExtractedSection],
    *,
    document_id: str,
    file_name: str,
    max_chars: int = 1000,
    overlap: int = 150,
) -> list[DocumentChunk]:
    chunks: list[DocumentChunk] = []
    for section in sections:
        text = " ".join(section.text.split())
        start = 0
        while start < len(text):
            end = min(start + max_chars, len(text))
            chunk_text = text[start:end].strip()
            if chunk_text:
                chunks.append(
                    DocumentChunk(
                        text=chunk_text,
                        metadata={
                            "document_id": document_id,
                            "file_name": file_name,
                            "chunk_index": len(chunks),
                            "source_ref": section.source_ref,
                        },
                    )
                )
            if end >= len(text):
                break
            start = max(0, end - overlap)
    if not chunks:
        raise ExtractionError("Document contains no useful text chunks")
    return chunks


class DeterministicEmbedder:
    def __init__(self, dimensions: int = 16) -> None:
        self.dimensions = dimensions

    def embed(self, texts: list[str]) -> list[list[float]]:
        vectors = []
        for text in texts:
            digest = hashlib.sha256(text.encode("utf-8")).digest()
            vector = [round((digest[index] / 255.0) * 2 - 1, 6) for index in range(self.dimensions)]
            vectors.append(vector)
        return vectors


class OpenAIEmbedder:
    def __init__(self, settings: Settings) -> None:
        self.settings = settings

    def embed(self, texts: list[str]) -> list[list[float]]:
        response = httpx.post(
            "https://api.openai.com/v1/embeddings",
            headers={"Authorization": f"Bearer {self.settings.openai_api_key}"},
            json={"model": self.settings.embedding_model, "input": texts},
            timeout=30,
        )
        response.raise_for_status()
        return [item["embedding"] for item in response.json()["data"]]


class ChromaVectorStore:
    def __init__(self, settings: Settings) -> None:
        self.settings = settings

    def store(self, *, ids: list[str], texts: list[str], embeddings: list[list[float]], metadatas: list[dict[str, Any]]) -> None:
        try:
            import chromadb

            if self.settings.chroma_db_host:
                client = chromadb.HttpClient(host=self.settings.chroma_db_host)
            else:
                client = chromadb.PersistentClient(path=self.settings.chroma_db_path)
            collection = client.get_or_create_collection("smart_helpdesk_knowledge_base")
            collection.upsert(ids=ids, documents=texts, embeddings=embeddings, metadatas=metadatas)
        except Exception as exc:
            raise EmbeddingStorageError("Failed to store chunks in ChromaDB") from exc


class InMemoryVectorStore:
    def __init__(self) -> None:
        self.records: list[dict[str, Any]] = []

    def store(self, *, ids: list[str], texts: list[str], embeddings: list[list[float]], metadatas: list[dict[str, Any]]) -> None:
        self.records.extend(
            {"id": item_id, "text": text, "embedding": embedding, "metadata": metadata}
            for item_id, text, embedding, metadata in zip(ids, texts, embeddings, metadatas, strict=True)
        )


def get_embedder(settings: Settings) -> Embedder:
    if settings.openai_api_key:
        return OpenAIEmbedder(settings)
    return DeterministicEmbedder()


def get_vector_store(settings: Settings) -> VectorStore:
    return ChromaVectorStore(settings)


def process_document(
    *,
    document_id: str,
    file_url: str,
    file_type: str,
    file_name: str | None = None,
    file_size_bytes: int | None = None,
    settings: Settings | None = None,
    embedder: Embedder | None = None,
    vector_store: VectorStore | None = None,
) -> DocumentProcessResponse:
    settings = settings or get_settings()
    try:
        parsed_file_type = DocumentFileType(file_type)
    except ValueError as exc:
        raise UnsupportedFileTypeError(f"Unsupported file type: {file_type}") from exc

    try:
        data, derived_file_name = _read_bytes(file_url, expected_size=file_size_bytes)
        final_file_name = file_name or derived_file_name
        sections = extract_text_sections(data, parsed_file_type)
        chunks = chunk_sections(sections, document_id=document_id, file_name=final_file_name)
        texts = [chunk.text for chunk in chunks]
        metadatas = [chunk.metadata for chunk in chunks]
        ids = [f"{document_id}:{metadata['chunk_index']}" for metadata in metadatas]
        active_embedder = embedder or get_embedder(settings)
        active_vector_store = vector_store or get_vector_store(settings)
        embeddings = active_embedder.embed(texts)
        if len(embeddings) != len(chunks):
            raise EmbeddingStorageError("Embedding provider returned the wrong number of vectors")
        active_vector_store.store(ids=ids, texts=texts, embeddings=embeddings, metadatas=metadatas)
    except DocumentProcessingError:
        raise
    except (OSError, httpx.HTTPError) as exc:
        raise ExtractionError("Failed to read document content") from exc
    except Exception as exc:
        raise EmbeddingStorageError("Embedding or storage failed") from exc

    used_fallback = isinstance(active_embedder, DeterministicEmbedder)
    return DocumentProcessResponse(
        document_id=document_id,
        embedding_status=EmbeddingStatus.READY,
        chunk_count=len(chunks),
        reason="Document processed successfully.",
        used_fallback=used_fallback,
        chunks=metadatas,
    )
