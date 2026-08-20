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
        return ["The Polo Pro Active costs 320,000 VND."]

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
    assert result.metadata["provider"] == "ollama"
    assert result.metadata["local_ai"] is True
