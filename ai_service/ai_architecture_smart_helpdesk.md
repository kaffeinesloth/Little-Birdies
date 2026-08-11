# Smart Helpdesk — Kiến trúc chi tiết AI Agent & RAG

> **Scope:** Tài liệu này chỉ bao gồm phần AI Core (vai trò của bạn): Intent Classification, RAG Pipeline, Agent Orchestrator, FastAPI endpoints, DB schema liên quan, và Prompt Engineering.

---

## 1. Tổng quan kiến trúc AI Core

```
┌─────────────────────────────────────────────────────────────────┐
│                        AI CORE SERVICE                          │
│                                                                 │
│  ┌───────────────┐    ┌──────────────────┐    ┌─────────────┐  │
│  │AgentOrchestrat│───▶│ IntentClassifier  │    │  RAGPipeline│  │
│  │      or       │    │                  │    │             │  │
│  │ (entry point) │    │ classify(message) │    │ query(text) │  │
│  └───────┬───────┘    └──────────────────┘    └─────────────┘  │
│          │                                                      │
│          ├──── COMPLAINT ──▶ TicketService ──▶ NotifyService   │
│          │                                                      │
│          └──── FAQ ─────────▶ RAGPipeline ──▶ ResponseBuilder  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Thành phần chính

| Module | File | Trách nhiệm |
|--------|------|-------------|
| `AgentOrchestrator` | `agent/orchestrator.py` | Entry point, điều phối toàn bộ luồng |
| `IntentClassifier` | `agent/intent_classifier.py` | Phân loại ý định bằng LLM |
| `RAGPipeline` | `rag/pipeline.py` | Retrieval + Generation |
| `DocumentIndexer` | `rag/indexer.py` | Xử lý upload và index tài liệu |
| `VectorStore` | `rag/vector_store.py` | Wrapper cho ChromaDB |
| `ConversationManager` | `agent/conversation.py` | Quản lý lịch sử hội thoại |
| `TicketService` | `services/ticket.py` | Tạo ticket vào Supabase |
| `NotifyService` | `services/notify.py` | Gửi push notification (FCM) |

---

## 2. Intent Classification Module

### 2.1 Thiết kế approach

Dùng **LLM với structured output** (JSON schema cố định) thay vì fine-tuned classifier riêng. Lý do:
- Không cần training data → deploy ngay
- Gemini Flash đủ nhanh (<1s) và rẻ cho classification
- Dễ thêm intent category mới mà không cần retrain

### 2.2 Intent Categories

```python
from enum import Enum
from pydantic import BaseModel, Field

class IntentType(str, Enum):
    GENERAL_FAQ    = "GENERAL_FAQ"      # Câu hỏi thông thường: giá, lịch, chính sách
    COMPLAINT      = "COMPLAINT"        # Khiếu nại về sản phẩm/dịch vụ
    ANGRY          = "ANGRY"            # Tin nhắn tức giận, xúc phạm
    ESCALATION_REQ = "ESCALATION_REQ"  # Khách chủ động yêu cầu gặp người thật
    GREETING       = "GREETING"         # Chào hỏi đơn thuần
    OUT_OF_SCOPE   = "OUT_OF_SCOPE"    # Ngoài phạm vi hỗ trợ

class IntentResult(BaseModel):
    intent: IntentType
    confidence: float = Field(ge=0.0, le=1.0)
    reasoning: str           # Giải thích ngắn gọn tại sao classify thế này
    detected_keywords: list[str]  # Keywords dùng để detect
    urgency_level: int = Field(ge=1, le=3)  # 1=thấp, 2=trung, 3=khẩn
```

### 2.3 Logic phân nhánh (Orchestrator)

```python
HUMAN_HANDOFF_INTENTS = {IntentType.COMPLAINT, IntentType.ANGRY, IntentType.ESCALATION_REQ}

async def route_message(result: IntentResult) -> str:
    # Luôn handoff nếu là complaint/angry/escalation
    if result.intent in HUMAN_HANDOFF_INTENTS:
        return "HANDOFF"
    
    # Handoff nếu confidence của FAQ quá thấp (không chắc chắn)
    if result.intent == IntentType.GENERAL_FAQ and result.confidence < 0.60:
        return "HANDOFF"
    
    # Greeting → trả lời cố định, không cần RAG
    if result.intent == IntentType.GREETING:
        return "GREETING_RESPONSE"
    
    if result.intent == IntentType.OUT_OF_SCOPE:
        return "OUT_OF_SCOPE_RESPONSE"
    
    return "RAG"
```

### 2.4 Prompt Template — Intent Classification

```python
INTENT_SYSTEM_PROMPT = """
Bạn là hệ thống phân loại ý định tin nhắn khách hàng cho một doanh nghiệp bán hàng online.

NHIỆM VỤ: Phân tích tin nhắn và trả về JSON với schema sau (KHÔNG có markdown, KHÔNG có giải thích ngoài JSON):

{
  "intent": "<GENERAL_FAQ|COMPLAINT|ANGRY|ESCALATION_REQ|GREETING|OUT_OF_SCOPE>",
  "confidence": <0.0-1.0>,
  "reasoning": "<lý do ngắn gọn>",
  "detected_keywords": ["<keyword1>", ...],
  "urgency_level": <1|2|3>
}

QUY TẮC PHÂN LOẠI:
- GENERAL_FAQ: hỏi giá, kích cỡ, chính sách đổi trả, thời gian giao hàng, thông tin sản phẩm
- COMPLAINT: "sản phẩm lỗi", "giao sai hàng", "đợi mãi không thấy", "yêu cầu hoàn tiền"
- ANGRY: ngôn ngữ tức giận, xúc phạm, dùng chữ viết hoa nhiều, nhiều dấu chấm than
- ESCALATION_REQ: "cho tôi gặp manager", "tôi muốn nói chuyện với người thật", "nhân viên đâu rồi"
- GREETING: "xin chào", "hi", "hello", "shop ơi"
- OUT_OF_SCOPE: chủ đề không liên quan đến shop

URGENCY:
- 3 (khẩn): ANGRY + đe dọa review xấu, COMPLAINT về mất tiền, yêu cầu hoàn tiền
- 2 (trung): COMPLAINT thông thường, ESCALATION_REQ
- 1 (thấp): mọi trường hợp còn lại
"""

INTENT_USER_TEMPLATE = """
Tin nhắn từ khách hàng: "{message}"

Lịch sử gần nhất (nếu có): {recent_history}
"""
```

### 2.5 Code Implementation

```python
# agent/intent_classifier.py
import json
import google.generativeai as genai
from .schemas import IntentResult, IntentType

class IntentClassifier:
    def __init__(self, model_name: str = "gemini-1.5-flash"):
        self.model = genai.GenerativeModel(
            model_name=model_name,
            generation_config={"response_mime_type": "application/json"}
        )
    
    async def classify(
        self, 
        message: str, 
        recent_history: list[dict] | None = None
    ) -> IntentResult:
        history_str = self._format_history(recent_history or [])
        
        prompt = f"{INTENT_SYSTEM_PROMPT}\n\n{INTENT_USER_TEMPLATE.format(
            message=message,
            recent_history=history_str
        )}"
        
        response = await self.model.generate_content_async(prompt)
        
        raw = json.loads(response.text)
        return IntentResult(**raw)
    
    def _format_history(self, history: list[dict]) -> str:
        if not history:
            return "(không có)"
        return "\n".join([
            f"- {'Khách' if m['role']=='user' else 'Bot'}: {m['content']}"
            for m in history[-3:]  # Chỉ lấy 3 tin nhắn gần nhất
        ])
```

---

## 3. RAG Pipeline

### 3.1 Document Ingestion (Offline)

Khi chủ shop upload tài liệu lên Web Admin, flow indexing chạy async (không block UI):

```
Upload API → Validate file → Save to Supabase Storage 
         → Trigger background task → DocumentIndexer
         → Extract text → Clean → Chunk → Embed → ChromaDB
         → Update status in DB (INDEXING → DONE / FAILED)
```

#### 3.1.1 Text Extraction

```python
# rag/extractors.py
from pypdf import PdfReader
from docx import Document
import re

class TextExtractor:
    def extract(self, file_path: str, mime_type: str) -> str:
        if "pdf" in mime_type:
            return self._extract_pdf(file_path)
        elif "docx" in mime_type or "msword" in mime_type:
            return self._extract_docx(file_path)
        elif "plain" in mime_type:
            return open(file_path, encoding="utf-8").read()
        raise ValueError(f"Unsupported type: {mime_type}")
    
    def _extract_pdf(self, path: str) -> str:
        reader = PdfReader(path)
        pages = [page.extract_text() or "" for page in reader.pages]
        return self._clean("\n\n".join(pages))
    
    def _extract_docx(self, path: str) -> str:
        doc = Document(path)
        paragraphs = [p.text for p in doc.paragraphs if p.text.strip()]
        return self._clean("\n\n".join(paragraphs))
    
    def _clean(self, text: str) -> str:
        # Loại bỏ nhiều newline liên tiếp, normalize whitespace
        text = re.sub(r'\n{3,}', '\n\n', text)
        text = re.sub(r'[ \t]+', ' ', text)
        return text.strip()
```

#### 3.1.2 Chunking Strategy

```python
# rag/chunker.py
from langchain_text_splitters import RecursiveCharacterTextSplitter

class DocumentChunker:
    def __init__(self):
        self.splitter = RecursiveCharacterTextSplitter(
            chunk_size=512,           # tokens (khoảng 400-500 từ tiếng Việt)
            chunk_overlap=64,         # 12.5% overlap để không mất ngữ cảnh ở ranh giới
            separators=["\n\n", "\n", "。", ".", "!", "?", " "],
            length_function=len,
        )
    
    def chunk(self, text: str, metadata: dict) -> list[dict]:
        chunks = self.splitter.split_text(text)
        return [
            {
                "text": chunk,
                "metadata": {
                    **metadata,
                    "chunk_index": i,
                    "total_chunks": len(chunks),
                }
            }
            for i, chunk in enumerate(chunks)
        ]
```

> **Lý do chọn 512/64:** Đủ nhỏ để embedding chính xác, đủ lớn để giữ ngữ cảnh. Overlap 64 tokens tránh mất thông tin ở ranh giới chunk.

#### 3.1.3 Embedding & Vector Store

```python
# rag/vector_store.py
import chromadb
from chromadb.utils import embedding_functions

class VectorStore:
    def __init__(self, persist_dir: str = "./chroma_db"):
        self.client = chromadb.PersistentClient(path=persist_dir)
        
        # Dùng Google embedding cho nhất quán với Gemini pipeline
        self.embed_fn = embedding_functions.GoogleGenerativeAiEmbeddingFunction(
            api_key=GOOGLE_API_KEY,
            model_name="models/text-embedding-004"  # 768 dims, multilingual
        )
    
    def get_or_create_collection(self, tenant_id: str) -> chromadb.Collection:
        """Mỗi tenant (shop) có 1 collection riêng biệt."""
        collection_name = f"tenant_{tenant_id}"
        return self.client.get_or_create_collection(
            name=collection_name,
            embedding_function=self.embed_fn,
            metadata={"hnsw:space": "cosine"}  # cosine similarity
        )
    
    def add_chunks(self, tenant_id: str, chunks: list[dict]) -> None:
        collection = self.get_or_create_collection(tenant_id)
        collection.add(
            ids=[f"{chunk['metadata']['doc_id']}_{chunk['metadata']['chunk_index']}" 
                 for chunk in chunks],
            documents=[chunk["text"] for chunk in chunks],
            metadatas=[chunk["metadata"] for chunk in chunks],
        )
    
    def query(
        self, 
        tenant_id: str, 
        query_text: str, 
        top_k: int = 5
    ) -> list[dict]:
        collection = self.get_or_create_collection(tenant_id)
        results = collection.query(
            query_texts=[query_text],
            n_results=top_k,
            include=["documents", "metadatas", "distances"]
        )
        return self._format_results(results)
    
    def _format_results(self, raw: dict) -> list[dict]:
        docs = raw["documents"][0]
        metas = raw["metadatas"][0]
        distances = raw["distances"][0]
        
        return [
            {
                "text": doc,
                "metadata": meta,
                "similarity": 1 - dist,  # cosine distance → similarity
            }
            for doc, meta, dist in zip(docs, metas, distances)
        ]
    
    def delete_document(self, tenant_id: str, doc_id: str) -> None:
        """Xóa tất cả chunks của 1 document khi user xóa tài liệu."""
        collection = self.get_or_create_collection(tenant_id)
        results = collection.get(where={"doc_id": doc_id})
        if results["ids"]:
            collection.delete(ids=results["ids"])
```

### 3.2 Retrieval Strategy

```python
# rag/retriever.py

SIMILARITY_THRESHOLD = 0.60  # Dưới ngưỡng này → không đủ tin cậy

class Retriever:
    def __init__(self, vector_store: VectorStore):
        self.vs = vector_store
    
    async def retrieve(
        self, 
        tenant_id: str, 
        query: str,
        top_k: int = 5
    ) -> tuple[list[dict], float]:
        """
        Returns: (chunks, max_similarity_score)
        max_similarity_score dùng cho confidence check
        """
        results = self.vs.query(tenant_id, query, top_k=top_k)
        
        if not results:
            return [], 0.0
        
        # Lọc kết quả dưới threshold
        filtered = [r for r in results if r["similarity"] >= SIMILARITY_THRESHOLD]
        
        # MMR (Maximal Marginal Relevance) để tránh duplicate chunks
        diverse = self._mmr_rerank(filtered, top_k=3)
        
        max_score = max(r["similarity"] for r in diverse) if diverse else 0.0
        return diverse, max_score
    
    def _mmr_rerank(self, results: list[dict], top_k: int = 3) -> list[dict]:
        """
        Đơn giản hóa: lấy top-1, rồi lấy các kết quả ít giống top-1 nhất.
        Trong production có thể dùng langchain MMR.
        """
        if len(results) <= top_k:
            return results
        
        selected = [results[0]]
        candidates = results[1:]
        
        while len(selected) < top_k and candidates:
            # Tìm candidate ít overlap nhất với các item đã chọn
            scores = []
            for candidate in candidates:
                # Đơn giản: so sánh theo source file để tránh cùng 1 doc
                overlap_penalty = sum(
                    0.2 for s in selected 
                    if s["metadata"].get("doc_id") == candidate["metadata"].get("doc_id")
                )
                scores.append(candidate["similarity"] - overlap_penalty)
            
            best_idx = scores.index(max(scores))
            selected.append(candidates.pop(best_idx))
        
        return selected
```

### 3.3 Response Generation

```python
# rag/generator.py

RAG_SYSTEM_PROMPT = """
Bạn là trợ lý CSKH AI của {shop_name}. 
Nhiệm vụ của bạn là trả lời khách hàng dựa CHÍNH XÁC vào thông tin được cung cấp bên dưới.

NGUYÊN TẮC:
1. CHỈ trả lời dựa trên "Thông tin tham khảo" bên dưới. KHÔNG bịa đặt thông tin.
2. Nếu thông tin không có trong tài liệu, nói thẳng: "Mình chưa có thông tin về vấn đề này, 
   để mình chuyển câu hỏi của bạn đến nhân viên nhé."
3. Trả lời bằng tiếng Việt, thân thiện, ngắn gọn (tối đa 3-4 câu).
4. KHÔNG đề cập đến "tài liệu" hay "dữ liệu" — nói như thể bạn biết tự nhiên.
5. Xưng "mình" với khách, gọi khách là "bạn" hoặc "anh/chị".

Tên shop: {shop_name}
Giờ hiện tại: {current_time}
"""

RAG_USER_TEMPLATE = """
--- THÔNG TIN THAM KHẢO ---
{context}
--------------------------

LỊCH SỬ HỘI THOẠI:
{history}

KHÁCH HỎI: {question}

Trả lời:
"""

LOW_CONFIDENCE_RESPONSE = """
Cảm ơn bạn đã liên hệ! Câu hỏi này mình cần kiểm tra thêm thông tin để trả lời chính xác cho bạn.
Mình sẽ chuyển đến nhân viên hỗ trợ ngay nhé, thường trong vòng 5-10 phút sẽ có người liên hệ lại với bạn! 🙏
"""

class ResponseGenerator:
    def __init__(self, model_name: str = "gemini-1.5-pro"):
        # Pro cho generation (cần reasoning tốt hơn Flash)
        self.model = genai.GenerativeModel(model_name)
    
    async def generate(
        self,
        tenant_config: dict,    # shop_name, persona, etc.
        question: str,
        chunks: list[dict],
        history: list[dict],
        max_similarity: float,
    ) -> dict:
        # Không đủ context → trả về LOW_CONFIDENCE response
        if max_similarity < SIMILARITY_THRESHOLD or not chunks:
            return {
                "text": LOW_CONFIDENCE_RESPONSE,
                "confidence": "low",
                "should_create_ticket": True,
            }
        
        context = self._build_context(chunks)
        history_str = self._format_history(history)
        
        system = RAG_SYSTEM_PROMPT.format(
            shop_name=tenant_config["shop_name"],
            current_time=datetime.now().strftime("%H:%M %d/%m/%Y")
        )
        user = RAG_USER_TEMPLATE.format(
            context=context,
            history=history_str,
            question=question
        )
        
        response = await self.model.generate_content_async(
            contents=[{"role": "user", "parts": [system + "\n\n" + user]}]
        )
        
        return {
            "text": response.text,
            "confidence": "high" if max_similarity > 0.80 else "medium",
            "should_create_ticket": False,
            "source_docs": [c["metadata"]["doc_name"] for c in chunks],
        }
    
    def _build_context(self, chunks: list[dict]) -> str:
        parts = []
        for i, chunk in enumerate(chunks, 1):
            doc_name = chunk["metadata"].get("doc_name", "Tài liệu")
            parts.append(f"[{i}] Từ {doc_name}:\n{chunk['text']}")
        return "\n\n".join(parts)
    
    def _format_history(self, history: list[dict], max_turns: int = 5) -> str:
        if not history:
            return "(Đây là tin nhắn đầu tiên)"
        recent = history[-(max_turns * 2):]  # max 5 cặp hỏi-đáp
        lines = []
        for msg in recent:
            prefix = "Khách:" if msg["role"] == "user" else "Bot:"
            lines.append(f"{prefix} {msg['content']}")
        return "\n".join(lines)
```

---

## 4. Agent Orchestrator

### 4.1 Conversation State Machine

```
         ┌─────────┐
         │  START  │
         └────┬────┘
              │
              ▼
     ┌────────────────┐
     │  AI_HANDLING   │◀──────────────────────┐
     └────────────────┘                       │
              │                               │
    ┌─────────┼──────────────┐                │
    │         │              │                │
    ▼         ▼              ▼                │
COMPLAINT  OUT_OF_SCOPE  LOW_CONFIDENCE       │
    │         │              │                │
    └────────►▼◄─────────────┘                │
     ┌────────────────┐                       │
     │HUMAN_HANDLING  │                       │
     └────────────────┘                       │
              │                               │
              ▼                               │
     ┌────────────────┐                       │
     │   RESOLVED     │  (human marks done)   │
     └────────────────┘
```

### 4.2 Full Orchestrator Code

```python
# agent/orchestrator.py
from dataclasses import dataclass
from enum import Enum

class ConvState(str, Enum):
    AI_HANDLING    = "AI_HANDLING"
    HUMAN_HANDLING = "HUMAN_HANDLING"
    RESOLVED       = "RESOLVED"

@dataclass
class ProcessResult:
    reply: str                      # Text gửi cho khách
    state: ConvState                # Trạng thái conversation sau xử lý
    ticket_id: str | None = None    # Nếu có ticket được tạo
    action: str = "NONE"            # "NONE" | "HANDOFF" | "NOTIFY"

class AgentOrchestrator:
    def __init__(
        self,
        classifier: IntentClassifier,
        retriever: Retriever,
        generator: ResponseGenerator,
        ticket_svc: TicketService,
        notify_svc: NotifyService,
        conv_manager: ConversationManager,
    ):
        self.classifier = classifier
        self.retriever = retriever
        self.generator = generator
        self.ticket_svc = ticket_svc
        self.notify_svc = notify_svc
        self.conv_mgr = conv_manager
    
    async def process(
        self,
        tenant_id: str,
        conversation_id: str,
        message: str,
        channel: str,  # "web" | "facebook" | "email"
    ) -> ProcessResult:
        
        # 1. Load conversation state & history
        conv = await self.conv_mgr.get(conversation_id)
        
        # 2. Nếu human đang xử lý → chỉ forward, không làm gì
        if conv.state == ConvState.HUMAN_HANDLING:
            await self.conv_mgr.add_message(conversation_id, "user", message)
            return ProcessResult(
                reply="",  # Không reply tự động khi human đang handle
                state=ConvState.HUMAN_HANDLING,
                action="NONE"
            )
        
        # 3. Classify intent
        intent_result = await self.classifier.classify(
            message=message,
            recent_history=conv.messages[-6:]
        )
        
        # 4. Routing
        if intent_result.intent in HUMAN_HANDOFF_INTENTS:
            return await self._handle_complaint(
                tenant_id, conversation_id, message, conv, intent_result, channel
            )
        
        if intent_result.intent == IntentType.GREETING:
            reply = await self._get_greeting(tenant_id)
            await self.conv_mgr.add_message(conversation_id, "user", message)
            await self.conv_mgr.add_message(conversation_id, "assistant", reply)
            return ProcessResult(reply=reply, state=ConvState.AI_HANDLING)
        
        if intent_result.intent == IntentType.OUT_OF_SCOPE:
            reply = "Mình chỉ có thể hỗ trợ các vấn đề liên quan đến sản phẩm và dịch vụ của shop. Bạn có câu hỏi nào khác không ạ?"
            return ProcessResult(reply=reply, state=ConvState.AI_HANDLING)
        
        # 5. FAQ → RAG
        return await self._handle_faq(
            tenant_id, conversation_id, message, conv, intent_result
        )
    
    async def _handle_complaint(
        self, tenant_id, conv_id, message, conv, intent_result, channel
    ) -> ProcessResult:
        # Tạo ticket
        ticket = await self.ticket_svc.create({
            "tenant_id": tenant_id,
            "conversation_id": conv_id,
            "channel": channel,
            "intent": intent_result.intent,
            "urgency": intent_result.urgency_level,
            "customer_message": message,
            "context_summary": self._summarize_history(conv.messages),
        })
        
        # Gửi push notification cho staff
        await self.notify_svc.send_urgent(
            tenant_id=tenant_id,
            ticket_id=ticket.id,
            urgency=intent_result.urgency_level,
            preview=message[:100],
        )
        
        # Update conversation state
        await self.conv_mgr.update_state(conv_id, ConvState.HUMAN_HANDLING)
        await self.conv_mgr.add_message(conv_id, "user", message)
        
        # Immediate auto-reply cho khách (không để khách đợi trong im lặng)
        acknowledgment = self._get_complaint_ack(intent_result.urgency_level)
        await self.conv_mgr.add_message(conv_id, "assistant", acknowledgment)
        
        return ProcessResult(
            reply=acknowledgment,
            state=ConvState.HUMAN_HANDLING,
            ticket_id=ticket.id,
            action="HANDOFF"
        )
    
    async def _handle_faq(
        self, tenant_id, conv_id, message, conv, intent_result
    ) -> ProcessResult:
        tenant_config = await self._get_tenant_config(tenant_id)
        
        # RAG retrieval
        chunks, max_similarity = await self.retriever.retrieve(
            tenant_id=tenant_id,
            query=message,
        )
        
        # Generate response
        result = await self.generator.generate(
            tenant_config=tenant_config,
            question=message,
            chunks=chunks,
            history=conv.messages,
            max_similarity=max_similarity,
        )
        
        # Nếu confidence thấp → tạo ticket, chuyển human
        if result["should_create_ticket"]:
            return await self._handle_complaint(
                tenant_id, conv_id, message, conv, 
                IntentResult(
                    intent=IntentType.GENERAL_FAQ,
                    confidence=max_similarity,
                    reasoning="Low confidence RAG",
                    detected_keywords=[],
                    urgency_level=1  # Low priority
                ),
                "auto"
            )
        
        # Save to history
        await self.conv_mgr.add_message(conv_id, "user", message)
        await self.conv_mgr.add_message(conv_id, "assistant", result["text"])
        
        return ProcessResult(
            reply=result["text"],
            state=ConvState.AI_HANDLING,
        )
    
    def _get_complaint_ack(self, urgency: int) -> str:
        if urgency == 3:
            return ("Mình rất xin lỗi về sự bất tiện này! Mình đã chuyển vấn đề của bạn "
                   "đến nhân viên phụ trách ngay lập tức và họ sẽ liên hệ với bạn trong vài phút. "
                   "Bạn vui lòng chờ một chút nhé! 🙏")
        elif urgency == 2:
            return ("Cảm ơn bạn đã phản hồi! Mình đã ghi nhận vấn đề và sẽ chuyển đến "
                   "nhân viên hỗ trợ ngay. Thông thường trong 5-10 phút sẽ có người liên hệ lại. 😊")
        else:
            return ("Cảm ơn bạn đã liên hệ! Mình cần chuyển câu hỏi này đến bộ phận "
                   "chuyên trách để hỗ trợ bạn tốt hơn. Bạn vui lòng chờ trong giây lát nhé!")
```

---

## 5. FastAPI Endpoints (AI-related)

```python
# routers/chat.py

@router.post("/chat/message")
async def receive_message(
    payload: ChatMessagePayload,
    bg: BackgroundTasks,
):
    """
    Web widget gửi tin nhắn vào. Trả về response ngay.
    """
    result = await orchestrator.process(
        tenant_id=payload.tenant_id,
        conversation_id=payload.conversation_id,
        message=payload.message,
        channel="web",
    )
    return {"reply": result.reply, "state": result.state, "ticket_id": result.ticket_id}


@router.post("/webhook/facebook")
async def facebook_webhook(request: Request, bg: BackgroundTasks):
    """
    Meta Messenger Webhook. Verify token và xử lý message.
    """
    body = await request.json()
    # Verify webhook signature
    if not verify_fb_signature(request.headers, await request.body()):
        raise HTTPException(403)
    
    for entry in body.get("entry", []):
        for event in entry.get("messaging", []):
            if "message" in event:
                bg.add_task(
                    handle_fb_message,
                    sender_id=event["sender"]["id"],
                    text=event["message"].get("text", ""),
                    page_id=entry["id"],
                )
    
    return {"status": "ok"}


@router.post("/knowledge/upload")
async def upload_document(
    tenant_id: str,
    file: UploadFile,
    bg: BackgroundTasks,
    current_user = Depends(require_manager),
):
    """
    Upload và index tài liệu. Chạy indexing async.
    """
    # Save to Supabase Storage
    doc_id = await storage.save(tenant_id, file)
    
    # Tạo record trong DB với status=INDEXING
    await db.create_document(doc_id, tenant_id, file.filename, status="INDEXING")
    
    # Trigger background indexing
    bg.add_task(indexer.index_document, tenant_id, doc_id, file)
    
    return {"doc_id": doc_id, "status": "INDEXING"}


@router.get("/knowledge/documents")
async def list_documents(
    tenant_id: str,
    current_user = Depends(require_manager),
):
    """
    Danh sách tài liệu đã upload và status indexing.
    """
    return await db.get_documents(tenant_id)


@router.delete("/knowledge/documents/{doc_id}")
async def delete_document(
    doc_id: str,
    tenant_id: str,
    current_user = Depends(require_manager),
):
    """
    Xóa document khỏi DB và ChromaDB.
    """
    await vector_store.delete_document(tenant_id, doc_id)
    await storage.delete(tenant_id, doc_id)
    await db.delete_document(doc_id)
    return {"status": "deleted"}
```

---

## 6. Database Schema (Supabase — AI-related tables)

```sql
-- Bảng lưu conversation và state
CREATE TABLE conversations (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       UUID NOT NULL REFERENCES tenants(id),
    channel         TEXT NOT NULL CHECK (channel IN ('web', 'facebook', 'email')),
    external_id     TEXT,           -- Facebook sender_id, email address, etc.
    state           TEXT NOT NULL DEFAULT 'AI_HANDLING'
                        CHECK (state IN ('AI_HANDLING', 'HUMAN_HANDLING', 'RESOLVED')),
    assigned_agent_id UUID REFERENCES users(id),
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Bảng lưu từng message trong conversation  
CREATE TABLE messages (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL REFERENCES conversations(id),
    role            TEXT NOT NULL CHECK (role IN ('user', 'assistant', 'system')),
    content         TEXT NOT NULL,
    intent          TEXT,           -- Kết quả classify (nếu role=user)
    confidence      FLOAT,          -- Confidence score
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Bảng tickets (khiếu nại)
CREATE TABLE tickets (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       UUID NOT NULL REFERENCES tenants(id),
    conversation_id UUID NOT NULL REFERENCES conversations(id),
    channel         TEXT NOT NULL,
    intent          TEXT NOT NULL,
    urgency         INT NOT NULL DEFAULT 1 CHECK (urgency BETWEEN 1 AND 3),
    status          TEXT NOT NULL DEFAULT 'OPEN'
                        CHECK (status IN ('OPEN', 'IN_PROGRESS', 'RESOLVED')),
    customer_message TEXT NOT NULL,     -- Tin nhắn gốc trigger ticket
    context_summary TEXT,               -- Tóm tắt lịch sử hội thoại
    assigned_agent_id UUID REFERENCES users(id),
    resolved_at     TIMESTAMPTZ,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Bảng tài liệu knowledge base
CREATE TABLE knowledge_documents (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       UUID NOT NULL REFERENCES tenants(id),
    file_name       TEXT NOT NULL,
    storage_path    TEXT NOT NULL,      -- Path trong Supabase Storage
    mime_type       TEXT NOT NULL,
    file_size       BIGINT,
    status          TEXT NOT NULL DEFAULT 'INDEXING'
                        CHECK (status IN ('INDEXING', 'DONE', 'FAILED')),
    chunks_count    INT DEFAULT 0,
    error_message   TEXT,
    indexed_at      TIMESTAMPTZ,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    uploaded_by     UUID REFERENCES users(id)
);

-- Cấu hình AI cho từng tenant
CREATE TABLE tenant_ai_configs (
    tenant_id       UUID PRIMARY KEY REFERENCES tenants(id),
    shop_name       TEXT NOT NULL,
    bot_persona     TEXT DEFAULT 'thân thiện, chuyên nghiệp',
    greeting_message TEXT DEFAULT 'Xin chào! Mình có thể giúp gì cho bạn?',
    fallback_message TEXT,
    auto_reply_enabled BOOLEAN DEFAULT TRUE,
    business_hours  JSONB,              -- {"mon": {"start": "8:00", "end": "22:00"}, ...}
    fcm_server_key  TEXT,              -- Encrypted Firebase key
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes quan trọng
CREATE INDEX idx_conversations_tenant ON conversations(tenant_id);
CREATE INDEX idx_messages_conversation ON messages(conversation_id);
CREATE INDEX idx_tickets_tenant_status ON tickets(tenant_id, status);
CREATE INDEX idx_tickets_urgency ON tickets(urgency DESC, created_at ASC);
CREATE INDEX idx_knowledge_tenant ON knowledge_documents(tenant_id);
```

---

## 7. Prompt Engineering — Best Practices

### 7.1 Anti-hallucination prompt cho RAG

Key phrase cần có trong system prompt:
```
"CHỈ dựa trên thông tin trong THÔNG TIN THAM KHẢO bên dưới.
 Nếu câu hỏi không được đề cập, hãy nói thẳng rằng bạn chưa có thông tin."
```

### 7.2 Persona consistency

Mỗi tenant có `bot_persona` riêng. Inject vào system prompt:
```python
f"Phong cách trả lời: {tenant_config['bot_persona']}"
# Ví dụ: "thân thiện như nhân viên bán hàng trẻ tuổi"
# Ví dụ: "chuyên nghiệp và lịch sự như nhân viên ngân hàng"
```

### 7.3 Conversation history window

**Luôn dùng sliding window** để tránh vượt context limit:
- Intent classification: dùng 3 tin nhắn gần nhất
- RAG generation: dùng 5 cặp hỏi-đáp gần nhất (10 messages)
- Không bao giờ inject toàn bộ history

### 7.4 Language handling

Người dùng thường mix Việt-Anh. Prompt cần:
```
"Khách có thể viết tiếng Việt, tiếng Anh, hoặc mix cả hai.
 Luôn trả lời bằng tiếng Việt trừ khi khách viết hoàn toàn bằng tiếng Anh."
```

---

## 8. Cấu trúc thư mục code

```
backend/
├── main.py                     # FastAPI app entry point
├── config.py                   # Settings, env vars (pydantic-settings)
├── dependencies.py             # DI: get_orchestrator(), get_db(), etc.
│
├── agent/
│   ├── __init__.py
│   ├── orchestrator.py         # AgentOrchestrator (main logic)
│   ├── intent_classifier.py    # IntentClassifier
│   ├── conversation.py         # ConversationManager (Supabase)
│   └── schemas.py              # IntentResult, ConvState, ProcessResult
│
├── rag/
│   ├── __init__.py
│   ├── pipeline.py             # RAGPipeline (thin wrapper)
│   ├── indexer.py              # DocumentIndexer (background tasks)
│   ├── extractors.py           # TextExtractor (PDF, DOCX, TXT)
│   ├── chunker.py              # DocumentChunker
│   ├── vector_store.py         # VectorStore (ChromaDB)
│   └── retriever.py            # Retriever + MMR reranking
│
├── services/
│   ├── ticket.py               # TicketService (Supabase)
│   ├── notify.py               # NotifyService (FCM)
│   └── storage.py              # Supabase Storage
│
├── routers/
│   ├── chat.py                 # POST /chat/message
│   ├── webhooks.py             # POST /webhook/facebook, /webhook/email
│   └── knowledge.py            # POST/GET/DELETE /knowledge/*
│
├── db/
│   ├── client.py               # Supabase client init
│   └── queries.py              # Raw SQL / Supabase queries
│
├── tests/
│   ├── test_intent.py
│   ├── test_rag.py
│   └── test_orchestrator.py
│
└── prompts/                    # Tách prompt ra file riêng (dễ edit)
    ├── intent_system.txt
    ├── rag_system.txt
    └── rag_user.txt
```

---

## 9. Thứ tự implement (14 ngày)

### Phase 1 — Foundation (Ngày 1-3)

| Ngày | Task |
|------|------|
| 1 | Setup FastAPI boilerplate, config, Supabase client, Gemini client |
| 2 | Implement `IntentClassifier` + viết unit tests với 20 test cases |
| 3 | Implement `TextExtractor` + `DocumentChunker` + basic `VectorStore` |

### Phase 2 — Core AI (Ngày 4-8)

| Ngày | Task |
|------|------|
| 4 | Implement `Retriever` (query, MMR reranking) + test với sample data |
| 5 | Implement `ResponseGenerator` (RAG prompt, confidence check) |
| 6 | Implement `ConversationManager` (Supabase CRUD, state machine) |
| 7 | Implement `AgentOrchestrator` (kết nối tất cả module) |
| 8 | Implement `/chat/message` endpoint + integration test end-to-end |

### Phase 3 — Integrations (Ngày 9-12)

| Ngày | Task |
|------|------|
| 9 | `DocumentIndexer` (upload → extract → chunk → embed → store) |
| 10 | `/knowledge/*` endpoints + test với PDF thực tế |
| 11 | `TicketService` + `NotifyService` (FCM) |
| 12 | Facebook Messenger webhook + Email webhook |

### Phase 4 — Polish (Ngày 13-14)

| Ngày | Task |
|------|------|
| 13 | Error handling toàn diện, retry logic, timeout handling |
| 14 | Performance test, viết API docs (FastAPI auto-docs), fix bugs |

---

## 10. Key Decisions & Tradeoffs

| Quyết định | Lý do chọn | Tradeoff chấp nhận |
|-----------|-----------|-------------------|
| Gemini Flash cho Intent Classification | Rẻ (~$0.075/1M tokens), đủ nhanh (<1s) | Có thể kém GPT-4 ở edge cases |
| Gemini Pro cho RAG Generation | Reasoning tốt hơn, cần độ chính xác cao | Tốn tiền hơn Flash (~5-10x) |
| ChromaDB local (không Pinecone) | Zero cost, đủ cho demo, dễ setup | Cần migrate nếu scale lớn |
| text-embedding-004 (Google) | Miễn phí, multilingual, nhất quán với Gemini | Bị vendor lock-in Google |
| 1 ChromaDB collection / tenant | Data isolation rõ ràng | Nhiều collections = overhead startup |
| Chunk size 512 tokens | Balance giữa accuracy và context | Có thể cần tuning cho domain cụ thể |
| LLM cho Intent (không ML model) | Zero training data needed | Chi phí per-call cao hơn |
| Sliding window 5 turns | Đủ ngữ cảnh, không vượt token limit | Mất context nếu hội thoại rất dài |

---

## 11. Lưu ý đặc biệt khi implement

1. **Multi-tenant isolation**: Luôn pass `tenant_id` vào mọi query ChromaDB và Supabase. Không bao giờ query cross-tenant.

2. **Async everywhere**: Tất cả LLM calls và DB calls phải `async`/`await`. Đừng để blocking call trong request handler.

3. **Background tasks cho indexing**: Indexing tài liệu có thể mất 30s-2min. Dùng `BackgroundTasks` của FastAPI, không block response.

4. **Idempotency cho webhooks**: Facebook có thể gửi webhook duplicate. Dùng `message_id` để dedup.

5. **Rate limiting**: Gemini API có rate limit. Implement exponential backoff với `tenacity` library.

6. **Secrets management**: `GOOGLE_API_KEY`, `SUPABASE_KEY`, `FCM_SERVER_KEY` phải từ env vars, không hardcode.

7. **Vietnamese text**: `RecursiveCharacterTextSplitter` hoạt động OK với tiếng Việt vì split theo character, không phải word.

---
## 12. Sau khi hoàn thành và những gì cần để chạy và kết nối với các thành viên khác
Để chạy thật cần thêm 3 thứ ngoài code:

.env — copy .env.example rồi điền GOOGLE_API_KEY, SUPABASE_URL, SUPABASE_SERVICE_KEY
Supabase tables — chạy đoạn SQL trong phần 6 của file kiến trúc để tạo bảng conversations, messages, tickets, knowledge_documents
Firebase JSON — download service account từ Firebase Console nếu cần push notification

Phần của các thành viên khác trong nhóm vẫn cần làm: Web Admin (Next.js), Mobile App (Flutter), và các REST API còn lại (Users, Auth).

## 13. Chạy code tham khảo
python smoke_test.py          # smoke test nhanh, không cần API key
python -m pytest tests/ -v
python test_real_api.py

*Tài liệu này phác thảo kiến trúc chi tiết trước khi code. Mọi interface có thể điều chỉnh khi integrate với các module khác (Backend, Mobile, Web).*
