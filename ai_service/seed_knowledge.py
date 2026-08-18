import httpx
import pathlib

AI_SERVICE = "http://localhost:8001"
# Khi chạy trong docker, script nằm ở /app/seed_knowledge.py, file ở /app/knowledge_data/...
KNOWLEDGE_FILE = pathlib.Path(__file__).parent / "knowledge_data" / "sportgear_store.txt"

def seed():
    print(f"Uploading {KNOWLEDGE_FILE} to AI Service...")
    if not KNOWLEDGE_FILE.exists():
        print("Knowledge file not found!")
        return

    with httpx.Client() as client:
        try:
            res = client.post(
                f"{AI_SERVICE}/knowledge/upload",
                params={"tenant_id": "default"},
                files={"file": (KNOWLEDGE_FILE.name, KNOWLEDGE_FILE.read_bytes(), "text/plain")},
                timeout=60,
            )
            print("Status:", res.status_code)
            print("Response:", res.json())
        except Exception as e:
            print("Error uploading:", e)

if __name__ == "__main__":
    seed()
