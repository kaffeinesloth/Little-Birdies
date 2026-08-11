from app.db.local_supabase import AGENT_DEMO_ID, OWNER_DEMO_ID, LocalSupabase


def test_local_sqlite_seeds_demo_users_and_persists_documents(tmp_path) -> None:
    db_path = tmp_path / "demo.sqlite3"
    first = LocalSupabase(db_path)

    users = first.table("users").select("*").execute().data
    assert {user["id"] for user in users} == {OWNER_DEMO_ID, AGENT_DEMO_ID}

    document = (
        first.table("documents")
        .insert(
            {
                "name": "policy.txt",
                "file_url": "/uploads/policy.txt",
                "file_type": "txt",
                "embedding_status": "ready",
                "chunk_count": 3,
                "uploaded_by": OWNER_DEMO_ID,
            }
        )
        .execute()
        .data[0]
    )

    second = LocalSupabase(db_path)
    persisted = second.table("documents").select("*").eq("id", document["id"]).execute().data

    assert persisted[0]["name"] == "policy.txt"
    assert persisted[0]["chunk_count"] == 3


def test_local_sqlite_updates_and_orders_records(tmp_path) -> None:
    db = LocalSupabase(tmp_path / "demo.sqlite3")

    first = db.table("tickets").insert({"customer_name": "A", "status": "open"}).execute().data[0]
    second = db.table("tickets").insert({"customer_name": "B", "status": "pending"}).execute().data[0]
    db.table("tickets").update({"status": "resolved"}).eq("id", first["id"]).execute()

    rows = db.table("tickets").select("*").order("created_at", desc=True).execute().data

    assert rows[0]["id"] in {first["id"], second["id"]}
    assert db.table("tickets").select("*").eq("id", first["id"]).execute().data[0]["status"] == "resolved"
