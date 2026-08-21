import pytest

from agent.local_ollama import LocalOllamaOrchestrator


@pytest.mark.asyncio
async def test_local_agent_hands_complaint_to_human():
    agent = LocalOllamaOrchestrator()

    result = await agent.process(
        tenant_id="default",
        conversation_id="web_customer",
        message="My new shirt arrived torn. Please resolve this now.",
    )

    assert result.action.value == "HANDOFF"
    assert result.metadata["fallback"] is True


@pytest.mark.asyncio
async def test_local_agent_returns_generated_grounded_answer(monkeypatch):
    agent = LocalOllamaOrchestrator()

    async def available():
        return True

    async def retrieve(question, top_k=3):
        return [("The Polo Pro Active costs 320,000 VND.", "uploaded_policy.txt")]

    async def generate(question, chunks):
        assert "320,000" in chunks[0]
        return "The Polo Pro Active currently costs 320,000 VND."

    monkeypatch.setattr(agent, "_is_available", available)
    monkeypatch.setattr(agent._retriever, "retrieve", retrieve)
    monkeypatch.setattr(agent, "_generate", generate)

    result = await agent.process(
        tenant_id="default",
        conversation_id="web_customer",
        message="How much is the Polo Pro Active?",
    )

    assert result.reply.startswith("The Polo Pro Active")
    assert result.source_docs == ["uploaded_policy.txt"]
    assert result.metadata["provider"] == "ollama"
    assert result.metadata["local_ai"] is True


@pytest.mark.asyncio
async def test_local_retriever_refreshes_uploaded_documents(tmp_path, monkeypatch):
    from agent import local_ollama

    monkeypatch.setattr(local_ollama.settings, "local_knowledge_dir", str(tmp_path))
    uploaded = tmp_path / "doc_123__shipping_policy.txt"
    uploaded.write_text(
        "Custom pickup policy\n\nCustomers may pick up new racket orders after 18:00.",
        encoding="utf-8",
    )

    retriever = local_ollama.LocalKnowledgeRetriever()

    async def unavailable(inputs):
        raise RuntimeError("embedding model unavailable in unit test")

    monkeypatch.setattr(retriever, "_request_embeddings", unavailable)

    results = await retriever.retrieve("When can customers pick up racket orders?")

    assert any("after 18:00" in chunk for chunk, _ in results)
    assert any(source == "doc_123__shipping_policy.txt" for _, source in results)
