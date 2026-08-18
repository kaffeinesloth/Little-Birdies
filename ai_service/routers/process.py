"""
routers/process.py — Main background processing router called by Backend gateway.

POST /process  → Tiếp nhận tin nhắn đã được lưu DB từ Backend, phân loại Intent & chạy RAG.
"""
from __future__ import annotations

import logging
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

import os
import httpx
from dependencies import get_orchestrator

BACKEND_URL = os.getenv("BACKEND_URL", "http://localhost:8000")

router = APIRouter()
logger = logging.getLogger(__name__)


class ProcessPayload(BaseModel):
    ticket_id: str
    customer_id: str
    source: str
    content: str
    customer_name: Optional[str] = None


class ProcessResponse(BaseModel):
    status: str
    reply: str
    action: str
    ticket_id: str


@router.post("/process", response_model=ProcessResponse)
async def process_incoming_message(
    payload: ProcessPayload,
    orchestrator=Depends(get_orchestrator),
):
    """
    Endpoint tiếp nhận dữ liệu từ Backend.
    Backend đã lưu ticket/message vào Supabase DB và kích hoạt POST /process sang AI Service.
    """
    if not payload.content.strip():
        raise HTTPException(status_code=400, detail="Content cannot be empty")

    logger.info(
        "Processing message from backend: ticket=%s, source=%s, customer=%s",
        payload.ticket_id,
        payload.source,
        payload.customer_id,
    )

    try:
        result = await orchestrator.process(
            tenant_id="default",
            conversation_id=f"{payload.source}_{payload.customer_id}",
            message=payload.content.strip(),
            channel=payload.source,
            external_id=payload.customer_id,
        )

        # Gửi bot reply về Backend
        if result.reply:
            try:
                async with httpx.AsyncClient(timeout=10.0) as client:
                    await client.post(
                        f"{BACKEND_URL}/api/v1/messages/bot-reply",
                        json={
                            "ticket_id": payload.ticket_id,
                            "content": result.reply,
                        }
                    )
            except Exception as e:
                logger.error("Failed to callback backend for ticket %s: %s", payload.ticket_id, e)

        return ProcessResponse(
            status="ok",
            reply=result.reply or "",
            action=result.action.value if hasattr(result.action, "value") else str(result.action),
            ticket_id=payload.ticket_id,
        )
    except Exception as exc:
        logger.error("Error in /process for ticket %s: %s", payload.ticket_id, exc)
        raise HTTPException(status_code=500, detail=f"AI processing failed: {str(exc)}")
