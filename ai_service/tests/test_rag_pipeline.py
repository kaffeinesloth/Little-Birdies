"""
tests/test_rag_pipeline.py — Unit tests cho RAG pipeline.

Mock toàn bộ external calls (ChromaDB, Google AI).
"""
from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, patch

import pytest


# ─────────────────────────────────────────────────────────────────────────────
# TextExtractor
# ─────────────────────────────────────────────────────────────────────────────

class TestTextExtractor:
    def setup_method(self):
        from rag.extractors import TextExtractor
        self.extractor = TextExtractor()

    def test_clean_removes_extra_newlines(self):
        raw = "Dòng 1\n\n\n\nDòng 2"
        result = self.extractor._clean(raw)
        assert "\n\n\n" not in result
        assert "Dòng 1" in result
        assert "Dòng 2" in result

    def test_clean_normalizes_whitespace(self):
        raw = "Từ 1    từ 2\t\tfrom 3"
        result = self.extractor._clean(raw)
        assert "  " not in result  # Không có double space

    def test_clean_strips_null_bytes(self):
        raw = "Hello\x00World"
        result = self.extractor._clean(raw)
        assert "\x00" not in result
        assert "HelloWorld" in result

    def test_extract_txt(self, tmp_path):
        content = "Chính sách đổi trả:\n- Đổi trong 7 ngày\n- Còn nguyên tem nhãn"
        f = tmp_path / "policy.txt"
        f.write_text(content, encoding="utf-8")
        result = self.extractor.extract(str(f), "text/plain")
        assert "Chính sách đổi trả" in result
        assert "7 ngày" in result

    def test_unsupported_mime_raises(self):
        with pytest.raises(ValueError, match="Unsupported"):
            self.extractor.extract("/some/file.xlsx", "application/vnd.ms-excel")


# ─────────────────────────────────────────────────────────────────────────────
# DocumentChunker
# ─────────────────────────────────────────────────────────────────────────────

class TestDocumentChunker:
    def setup_method(self):
        from rag.chunker import DocumentChunker
        self.chunker = DocumentChunker(chunk_size=100, chunk_overlap=10)
        self.base_meta = {"doc_id": "doc-001", "doc_name": "test.pdf", "tenant_id": "t1"}

    def test_returns_list_of_dicts(self):
        text = "Câu văn bình thường. " * 20
        result = self.chunker.chunk(text, self.base_meta)
        assert isinstance(result, list)
        assert all("text" in c and "metadata" in c for c in result)

    def test_metadata_is_preserved(self):
        text = "Thông tin sản phẩm ABC. " * 10
        result = self.chunker.chunk(text, self.base_meta)
        assert result[0]["metadata"]["doc_id"] == "doc-001"
        assert result[0]["metadata"]["tenant_id"] == "t1"

    def test_chunk_index_is_sequential(self):
        text = "Word " * 300   # Đủ dài để tạo nhiều chunks
        result = self.chunker.chunk(text, self.base_meta)
        if len(result) > 1:
            indices = [c["metadata"]["chunk_index"] for c in result]
            assert indices == list(range(len(result)))

    def test_empty_text_returns_empty_list(self):
        result = self.chunker.chunk("", self.base_meta)
        assert result == []

    def test_whitespace_only_returns_empty_list(self):
        result = self.chunker.chunk("   \n\n   ", self.base_meta)
        assert result == []

    def test_short_chunks_filtered_out(self):
        # Chunk < 30 chars phải bị bỏ
        text = "AB\n\n" * 50 + "Thông tin quan trọng cần giữ lại đây là nội dung đủ dài"
        result = self.chunker.chunk(text, self.base_meta)
        # Không có chunk nào < 30 chars
        for chunk in result:
            assert len(chunk["text"].strip()) >= 30


# ─────────────────────────────────────────────────────────────────────────────
# Retriever
# ─────────────────────────────────────────────────────────────────────────────

class TestRetriever:
    def _make_retriever(self, query_results):
        """Tạo retriever với VectorStore mock."""
        from rag.retriever import Retriever
        vs = MagicMock()
        vs.query.return_value = query_results
        return Retriever(vector_store=vs)

    def _chunk(self, text, similarity, doc_id="doc-1"):
        return {"text": text, "metadata": {"doc_id": doc_id, "doc_name": "test.pdf"}, "similarity": similarity}

    @pytest.mark.asyncio
    async def test_returns_empty_when_no_results(self):
        retriever = self._make_retriever([])
        chunks, score = await retriever.retrieve("tenant1", "query?")
        assert chunks == []
        assert score == 0.0

    @pytest.mark.asyncio
    async def test_filters_below_threshold(self):
        """Chunks với similarity < 0.60 phải bị loại."""
        retriever = self._make_retriever([
            self._chunk("Nội dung A", similarity=0.80),
            self._chunk("Nội dung B", similarity=0.45),   # dưới threshold
        ])
        chunks, score = await retriever.retrieve("tenant1", "query?")
        assert len(chunks) == 1
        assert chunks[0]["text"] == "Nội dung A"

    @pytest.mark.asyncio
    async def test_returns_max_similarity(self):
        retriever = self._make_retriever([
            self._chunk("A", similarity=0.90),
            self._chunk("B", similarity=0.75),
            self._chunk("C", similarity=0.62),
        ])
        _, max_sim = await retriever.retrieve("tenant1", "query?")
        assert max_sim == pytest.approx(0.90)

    @pytest.mark.asyncio
    async def test_all_below_threshold_returns_best_score(self):
        """Khi tất cả dưới threshold → trả về score cao nhất để orchestrator biết."""
        retriever = self._make_retriever([
            self._chunk("A", similarity=0.40),
            self._chunk("B", similarity=0.35),
        ])
        chunks, score = await retriever.retrieve("tenant1", "query?")
        assert chunks == []
        assert score == pytest.approx(0.40)

    @pytest.mark.asyncio
    async def test_mmr_prefers_diverse_docs(self):
        """MMR nên chọn chunks từ nhiều doc_id khác nhau."""
        retriever = self._make_retriever([
            self._chunk("Doc A chunk 1", similarity=0.95, doc_id="doc-A"),
            self._chunk("Doc A chunk 2", similarity=0.93, doc_id="doc-A"),
            self._chunk("Doc B chunk 1", similarity=0.88, doc_id="doc-B"),
            self._chunk("Doc A chunk 3", similarity=0.85, doc_id="doc-A"),
        ])
        chunks, _ = await retriever.retrieve("tenant1", "query?")
        doc_ids = [c["metadata"]["doc_id"] for c in chunks]
        # Phải có ít nhất 1 chunk từ doc-B (diversity)
        assert "doc-B" in doc_ids


# ─────────────────────────────────────────────────────────────────────────────
# ResponseGenerator
# ─────────────────────────────────────────────────────────────────────────────

class TestResponseGenerator:
    def _make_generator(self, llm_reply: str = "Giá áo là 250k bạn nhé!"):
        from rag.generator import ResponseGenerator
        with patch("rag.generator.genai.Client"):
            gen = ResponseGenerator(api_key="fake")
        mock_resp = MagicMock()
        mock_resp.text = llm_reply
        gen._client.aio.models.generate_content = AsyncMock(return_value=mock_resp)
        return gen

    def _chunks(self, n=2):
        return [
            {
                "text": f"Chunk {i}: Giá sản phẩm là 250.000đ",
                "metadata": {"doc_id": f"d{i}", "doc_name": "banggia.pdf"},
                "similarity": 0.85,
            }
            for i in range(n)
        ]

    @pytest.mark.asyncio
    async def test_returns_reply_when_high_confidence(self):
        gen    = self._make_generator("Giá 250k bạn ơi!")
        result = await gen.generate(
            tenant_config={"shop_name": "Shop Test"},
            question="Giá bao nhiêu?",
            chunks=self._chunks(),
            history=[],
            max_similarity=0.85,
        )
        assert result["text"] == "Giá 250k bạn ơi!"
        assert result["confidence"] == "high"
        assert result["should_create_ticket"] is False

    @pytest.mark.asyncio
    async def test_low_confidence_triggers_ticket(self):
        gen    = self._make_generator()
        result = await gen.generate(
            tenant_config={"shop_name": "Shop"},
            question="Câu hỏi không có trong tài liệu?",
            chunks=[],
            history=[],
            max_similarity=0.30,
        )
        assert result["should_create_ticket"] is True
        assert result["confidence"] == "low"

    @pytest.mark.asyncio
    async def test_llm_error_falls_back_to_ticket(self):
        gen = self._make_generator()
        gen._client.aio.models.generate_content = AsyncMock(
            side_effect=Exception("LLM timeout")
        )
        result = await gen.generate(
            tenant_config={"shop_name": "Shop"},
            question="test",
            chunks=self._chunks(),
            history=[],
            max_similarity=0.80,
        )
        assert result["should_create_ticket"] is True

    @pytest.mark.asyncio
    async def test_source_docs_extracted(self):
        gen    = self._make_generator("OK!")
        result = await gen.generate(
            tenant_config={"shop_name": "Shop"},
            question="test",
            chunks=[
                {"text": "A", "metadata": {"doc_id": "1", "doc_name": "policy.pdf"}, "similarity": 0.9},
                {"text": "B", "metadata": {"doc_id": "2", "doc_name": "price.pdf"},  "similarity": 0.8},
            ],
            history=[],
            max_similarity=0.9,
        )
        assert "policy.pdf" in result["source_docs"]
        assert "price.pdf"  in result["source_docs"]

    def test_build_context_format(self):
        from rag.generator import ResponseGenerator
        with patch("rag.generator.genai.Client"):
            gen = ResponseGenerator(api_key="fake")
        chunks = [
            {"text": "Nội dung A", "metadata": {"doc_name": "a.pdf"}, "similarity": 0.9},
            {"text": "Nội dung B", "metadata": {"doc_name": "b.pdf"}, "similarity": 0.8},
        ]
        ctx = gen._build_context(chunks)
        assert "[1]" in ctx
        assert "[2]" in ctx
        assert "a.pdf" in ctx
        assert "Nội dung A" in ctx

    def test_format_history_truncates(self):
        from rag.generator import ResponseGenerator
        with patch("rag.generator.genai.Client"):
            gen = ResponseGenerator(api_key="fake")
        history = [{"role": "user", "content": f"Msg {i}"} for i in range(20)]
        result  = gen._format_history(history, max_turns=3)
        assert "Msg 19" in result   # Có tin nhắn gần nhất
        assert "Msg 0"  not in result  # Không có tin nhắn cũ
