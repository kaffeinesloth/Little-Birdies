import os
from rag.vector_store import VectorStore
from rag.indexer import DocumentIndexer
from db.queries import update_document_status

vs = VectorStore(api_key="", persist_dir="/data/chroma_db")
vs.delete_tenant("default")
print("Deleted old tenant_default collection.")

# Re-index clean
class DummyDb:
    async def update_document_status(self, *args, **kwargs):
        pass

indexer = DocumentIndexer(vector_store=vs, db_queries=DummyDb())
import asyncio

async def run():
    with open("/app/knowledge_data/sportgear_store.txt", "r", encoding="utf-8") as f:
        text = f.read()

    from rag.chunker import DocumentChunker
    chunker = DocumentChunker(chunk_size=450, chunk_overlap=50)
    chunks = chunker.chunk(text, base_metadata={"doc_id": "doc_sportgear_main", "doc_name": "sportgear_store.txt", "tenant_id": "default"})
    stored = vs.add_chunks("default", chunks)
    print(f"Successfully re-indexed {stored} clean chunks into tenant_default!")

asyncio.run(run())
