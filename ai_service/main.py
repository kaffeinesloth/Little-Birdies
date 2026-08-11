"""
AI Service — Smart Helpdesk
============================
Microservice này do team AI đảm nhận implement.
Backend gọi 2 endpoint sau qua HTTP (fire-and-forget):

POST /process
    Input:  { ticket_id, customer_id, source, content }
    Output: { status: "auto_replied" | "escalated" | "ignored" }
    Hành vi:
    - Classify intent: question | complaint | spam
    - Nếu question → RAG query → INSERT bot message → resolve ticket
    - Nếu complaint hoặc RAG fail → INSERT handoff message → push notification

POST /embed
    Input:  { document_id, file_url, file_type }
    Output: { status: "ready" | "error", chunk_count: int }
    Hành vi:
    - Download file từ Supabase Storage
    - Parse PDF/DOCX/TXT → chunk → embed → lưu vào vector DB
    - UPDATE documents SET embedding_status=ready/error

GET /
    Health check → { status: "ok" }

Xem chi tiết: AI Helpdesk Agent/api_design_specification.md
Mục "2. AI Processing Background"
"""
