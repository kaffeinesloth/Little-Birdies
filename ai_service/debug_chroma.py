from rag.vector_store import VectorStore

vs = VectorStore(api_key="", persist_dir="/data/chroma_db")
coll = vs._collection("default")
print("Total vectors in Chroma tenant_default:", coll.count())

all_data = coll.get()
print("Total retrieved ids:", len(all_data["ids"]))
for idx, (doc, meta) in enumerate(zip(all_data["documents"], all_data["metadatas"])):
    print(f"--- CHUNK {idx+1} ({meta.get('doc_name')}) ---")
    print(doc[:250] + "...\n")
