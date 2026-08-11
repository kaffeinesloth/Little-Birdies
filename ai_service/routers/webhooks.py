"""
routers/webhooks.py — Xử lý webhook từ Facebook Messenger và Email (Mailgun).

Facebook:
  GET  /webhook/facebook  → verify token (dùng lúc setup trên Meta dashboard)
  POST /webhook/facebook  → nhận tin nhắn từ Messenger

Email (Mailgun inbound):
  POST /webhook/email     → nhận email từ khách hàng
"""
from __future__ import annotations

import hashlib
import hmac
import logging
import os

import httpx
from fastapi import APIRouter, BackgroundTasks, HTTPException, Query, Request

from dependencies import get_orchestrator

router = APIRouter()
logger = logging.getLogger(__name__)

_FB_VERIFY_TOKEN   = os.getenv("FB_VERIFY_TOKEN", "smart_helpdesk_verify")
_FB_APP_SECRET     = os.getenv("FB_APP_SECRET", "")
_FB_PAGE_TOKEN     = os.getenv("FB_PAGE_TOKEN", "")
_FB_GRAPH_API      = "https://graph.facebook.com/v19.0/me/messages"


# ── Facebook ──────────────────────────────────────────────────────────────────

@router.get("/facebook")
async def fb_verify(
    hub_mode:         str = Query(alias="hub.mode",          default=""),
    hub_verify_token: str = Query(alias="hub.verify_token",  default=""),
    hub_challenge:    str = Query(alias="hub.challenge",     default=""),
):
    """Meta Webhook verification (chỉ gọi 1 lần lúc setup)."""
    if hub_mode == "subscribe" and hub_verify_token == _FB_VERIFY_TOKEN:
        logger.info("Facebook webhook verified")
        return int(hub_challenge)
    raise HTTPException(status_code=403, detail="Verification failed")


@router.post("/facebook")
async def fb_receive(request: Request, background_tasks: BackgroundTasks):
    """Nhận events từ Messenger webhook."""
    body_bytes = await request.body()

    # Verify HMAC signature
    if _FB_APP_SECRET and not _verify_fb_signature(
        request.headers.get("X-Hub-Signature-256", ""), body_bytes
    ):
        raise HTTPException(status_code=403, detail="Invalid signature")

    body = await request.json()
    if body.get("object") != "page":
        return {"status": "ignored"}

    for entry in body.get("entry", []):
        for event in entry.get("messaging", []):
            msg = event.get("message", {})
            text = msg.get("text", "").strip()
            if not text or msg.get("is_echo"):
                continue   # Bỏ qua echo và non-text

            sender_id = event["sender"]["id"]
            page_id   = entry["id"]

            background_tasks.add_task(
                _handle_fb_message,
                sender_id=sender_id,
                text=text,
                page_id=page_id,
            )

    return {"status": "ok"}


async def _handle_fb_message(sender_id: str, text: str, page_id: str) -> None:
    """Background task: xử lý 1 tin nhắn Facebook."""
    try:
        orchestrator = await get_orchestrator()
        result = await orchestrator.process(
            tenant_id=page_id,
            conversation_id=f"fb_{sender_id}",
            message=text,
            channel="facebook",
            external_id=sender_id,
        )
        if result.reply:
            await _send_fb_reply(sender_id, result.reply)
    except Exception as exc:
        logger.error("FB message handling failed sender=%s: %s", sender_id, exc)


async def _send_fb_reply(recipient_id: str, text: str) -> None:
    """Gửi reply về Messenger qua Graph API."""
    async with httpx.AsyncClient() as client:
        resp = await client.post(
            _FB_GRAPH_API,
            params={"access_token": _FB_PAGE_TOKEN},
            json={
                "recipient": {"id": recipient_id},
                "message":   {"text": text[:2000]},  # FB limit 2000 chars
            },
            timeout=10,
        )
    if resp.status_code != 200:
        logger.error("FB send failed %d: %s", resp.status_code, resp.text[:200])


def _verify_fb_signature(signature_header: str, body: bytes) -> bool:
    if not signature_header.startswith("sha256="):
        return False
    expected = hmac.new(
        _FB_APP_SECRET.encode(), body, hashlib.sha256
    ).hexdigest()
    return hmac.compare_digest(f"sha256={expected}", signature_header)


# ── Email (Mailgun inbound) ───────────────────────────────────────────────────

@router.post("/email")
async def email_receive(request: Request, background_tasks: BackgroundTasks):
    """
    Mailgun inbound webhook.
    Mailgun gửi POST với form-data (không phải JSON).
    """
    form = await request.form()
    sender    = str(form.get("sender", ""))
    recipient = str(form.get("recipient", ""))
    subject   = str(form.get("subject", ""))
    body_text = str(form.get("body-plain", "")).strip()

    if not body_text or not sender:
        return {"status": "ignored"}

    # Dùng email sender làm external_id để track conversation
    message = f"[Subject: {subject}]\n{body_text[:1000]}" if subject else body_text[:1000]

    background_tasks.add_task(
        _handle_email_message,
        sender=sender,
        recipient=recipient,
        message=message,
        tenant_id=_extract_tenant_from_recipient(recipient),
    )
    return {"status": "ok"}


async def _handle_email_message(
    sender: str, recipient: str, message: str, tenant_id: str
) -> None:
    try:
        orchestrator = await get_orchestrator()
        await orchestrator.process(
            tenant_id=tenant_id,
            conversation_id=f"email_{sender.replace('@', '_at_')}",
            message=message,
            channel="email",
            external_id=sender,
        )
        # Note: reply qua email cần gọi Mailgun/SendGrid API riêng — TODO
    except Exception as exc:
        logger.error("Email handling failed sender=%s: %s", sender, exc)


def _extract_tenant_from_recipient(recipient: str) -> str:
    """
    Lấy tenant_id từ địa chỉ email recipient.
    Convention: support+{tenant_id}@yourdomain.com
    """
    local = recipient.split("@")[0]
    if "+" in local:
        return local.split("+")[-1]
    return "default"
