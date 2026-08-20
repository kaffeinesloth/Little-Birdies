"""
Seed SportGear knowledge into the AI service.

Preferred, when ai_service is running:
    python seed_knowledge.py --mode http

Fallback, when you only need local Chroma data:
    python seed_knowledge.py --mode direct

Auto mode tries HTTP first and falls back to direct Chroma indexing.
"""
from __future__ import annotations

import argparse
import os
import pathlib
import sys
from uuid import uuid5, NAMESPACE_URL

import httpx

DEFAULT_AI_SERVICE = os.getenv("AI_SERVICE_URL", "http://localhost:8001")
DEFAULT_TENANT_ID = "default"
KNOWLEDGE_FILE = pathlib.Path(__file__).parent / "knowledge_data" / "sportgear_store.txt"


def _require_file(path: pathlib.Path) -> None:
    if not path.exists():
        print(f"ERROR: Knowledge file not found: {path}")
        raise SystemExit(1)


def seed_via_http(service_url: str, tenant_id: str, file_path: pathlib.Path) -> bool:
    print(f"Uploading {file_path.name} to {service_url}/knowledge/upload ...")
    try:
        with httpx.Client(timeout=60.0) as client:
            res = client.post(
                f"{service_url.rstrip('/')}/knowledge/upload",
                params={"tenant_id": tenant_id},
                files={"file": (file_path.name, file_path.read_bytes(), "text/plain")},
            )
        print("  Status:", res.status_code)
        try:
            print("  Response:", res.json())
        except Exception:
            print("  Response:", res.text[:500])
        return 200 <= res.status_code < 300
    except Exception as exc:
        print(f"  HTTP seed failed: {exc}")
        return False


def seed_direct(tenant_id: str, file_path: pathlib.Path, persist_dir: str) -> bool:
    """
    Index directly into Chroma without relying on the knowledge_documents table.
    This is enough for /process RAG retrieval in a local class demo.
    """
    print(f"Indexing {file_path.name} directly into Chroma at {persist_dir} ...")
    try:
        from rag.chunker import DocumentChunker
        from rag.vector_store import VectorStore

        doc_id = str(uuid5(NAMESPACE_URL, f"smart-helpdesk:{tenant_id}:{file_path.name}"))
        text = file_path.read_text(encoding="utf-8")
        chunker = DocumentChunker()
        chunks = chunker.chunk(
            text=text,
            base_metadata={
                "doc_id": doc_id,
                "doc_name": file_path.name,
                "tenant_id": tenant_id,
            },
        )
        if not chunks:
            print("ERROR: No chunks produced from knowledge file.")
            return False

        vector_store = VectorStore(
            api_key=os.getenv("GOOGLE_API_KEY", ""),
            embedding_model=os.getenv("EMBEDDING_MODEL", "text-embedding-004"),
            persist_dir=persist_dir,
        )
        vector_store.delete_document(tenant_id=tenant_id, doc_id=doc_id)
        stored = vector_store.add_chunks(tenant_id=tenant_id, chunks=chunks)
        print(f"  Stored {stored} chunks for tenant={tenant_id}, doc_id={doc_id}")
        return stored > 0
    except Exception as exc:
        print(f"  Direct Chroma seed failed: {exc}")
        return False


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Seed SportGear knowledge for Smart Helpdesk demo.")
    parser.add_argument("--mode", choices=["auto", "http", "direct"], default="auto")
    parser.add_argument("--service-url", default=DEFAULT_AI_SERVICE)
    parser.add_argument("--tenant-id", default=DEFAULT_TENANT_ID)
    parser.add_argument("--file", default=str(KNOWLEDGE_FILE))
    parser.add_argument(
        "--persist-dir",
        default=os.getenv("CHROMA_PERSIST_DIR", str(pathlib.Path(__file__).parent / "chroma_db")),
        help="Chroma persist directory for --mode direct or auto fallback.",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    file_path = pathlib.Path(args.file)
    _require_file(file_path)

    ok = False
    if args.mode in {"auto", "http"}:
        ok = seed_via_http(args.service_url, args.tenant_id, file_path)
        if args.mode == "http" and not ok:
            raise SystemExit(1)

    if not ok and args.mode in {"auto", "direct"}:
        ok = seed_direct(args.tenant_id, file_path, args.persist_dir)

    if not ok:
        print("ERROR: SportGear knowledge was not seeded.")
        raise SystemExit(1)

    print("Done. SportGear knowledge is ready for demo retrieval/fallback display.")


if __name__ == "__main__":
    main()
