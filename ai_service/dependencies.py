"""
dependencies.py — FastAPI Depends() wiring.

Mỗi service được khởi tạo 1 lần duy nhất (singleton pattern với lru_cache).
Routers import get_orchestrator(), get_indexer() từ file này.
"""
from __future__ import annotations

from functools import lru_cache

from config import settings


@lru_cache(maxsize=1)
def get_demo_fallback_orchestrator():
    from agent.demo_fallback import create_demo_fallback_orchestrator
    return create_demo_fallback_orchestrator()


# ── Singletons (heavy objects — khởi tạo 1 lần) ─────────────────────────────

@lru_cache(maxsize=1)
def get_vector_store():
    from rag.vector_store import VectorStore
    return VectorStore(
        api_key=settings.google_api_key,
        embedding_model=settings.embedding_model,
        persist_dir=settings.chroma_persist_dir,
    )


@lru_cache(maxsize=1)
def get_intent_classifier():
    from agent.intent_classifier import IntentClassifier
    return IntentClassifier(
        api_key=settings.google_api_key,
        model_name=settings.intent_model,
    )


@lru_cache(maxsize=1)
def get_rag_pipeline():
    from rag.retriever  import Retriever
    from rag.generator  import ResponseGenerator
    from rag.pipeline   import RAGPipeline

    retriever = Retriever(vector_store=get_vector_store())
    generator = ResponseGenerator(
        api_key=settings.google_api_key,
        model_name=settings.rag_model,
    )
    return RAGPipeline(retriever=retriever, generator=generator)


# ── Per-request (cần DB connection) ─────────────────────────────────────────

async def get_db():
    from db.client import get_supabase
    return await get_supabase()


async def get_orchestrator():
    from agent.orchestrator  import AgentOrchestrator
    from agent.conversation  import ConversationManager
    from services.ticket     import TicketService
    from services.notify     import NotifyService

    if not settings.supabase_url or not settings.supabase_service_key:
        return get_demo_fallback_orchestrator()

    try:
        db = await get_db()
        return AgentOrchestrator(
            classifier=get_intent_classifier(),
            rag_pipeline=get_rag_pipeline(),
            ticket_svc=TicketService(db),
            notify_svc=NotifyService(db),
            conv_mgr=ConversationManager(db),
            db=db,
        )
    except Exception:
        return get_demo_fallback_orchestrator()


async def get_indexer():
    from rag.indexer import DocumentIndexer
    db = await get_db()

    class _DBQueries:
        """Thin wrapper để indexer có thể gọi update_document_status."""
        async def update_document_status(self, **kwargs):
            import db.queries as q
            await q.update_document_status(db, **kwargs)

    return DocumentIndexer(
        vector_store=get_vector_store(),
        db_queries=_DBQueries(),
    )
