"""
Webhooks router — nhận tin nhắn từ Facebook Messenger và Email (Mailgun/SendGrid).
Các endpoint này public (không cần JWT) vì được gọi bởi Facebook/Mailgun servers.
Bảo mật bằng cách verify signature của từng platform.
"""
import hashlib
import hmac
import os
from fastapi import APIRouter, Request, HTTPException, Query, Response

from core.database import get_supabase_admin
from models.domain import SenderType

router = APIRouter()

FB_VERIFY_TOKEN = os.getenv("FB_VERIFY_TOKEN", "")
FB_APP_SECRET = os.getenv("FB_APP_SECRET", "")
MAILGUN_SIGNING_KEY = os.getenv("MAILGUN_SIGNING_KEY", "")

AI_SERVICE_URL = "http://localhost:8001"


# ============================================================
# Facebook Messenger Webhook
# ============================================================

@router.get("/facebook")
def facebook_verify(
    hub_mode: str = Query(..., alias="hub.mode"),
    hub_verify_token: str = Query(..., alias="hub.verify_token"),
    hub_challenge: str = Query(..., alias="hub.challenge"),
):
    """
    Facebook gọi endpoint này để xác minh webhook URL khi super_admin
    đăng ký trên Meta Developer Portal.
    """
    if hub_mode == "subscribe" and hub_verify_token == FB_VERIFY_TOKEN:
        return Response(content=hub_challenge, media_type="text/plain")
    raise HTTPException(status_code=403, detail="Xác minh webhook thất bại.")


@router.post("/facebook")
async def facebook_webhook(request: Request):
    """
    Facebook gửi tin nhắn mới vào endpoint này (POST).
    Verify HMAC signature trước khi xử lý.
    """
    body = await request.body()

    # Verify HMAC-SHA256 signature
    signature = request.headers.get("X-Hub-Signature-256", "")
    if FB_APP_SECRET:
        expected = "sha256=" + hmac.new(
            FB_APP_SECRET.encode(),
            body,
            hashlib.sha256,
        ).hexdigest()
        if not hmac.compare_digest(signature, expected):
            raise HTTPException(status_code=403, detail="Chữ ký không hợp lệ.")

    import json
    data = json.loads(body)

    # Xử lý từng entry từ Facebook
    for entry in data.get("entry", []):
        for messaging in entry.get("messaging", []):
            sender_id = messaging.get("sender", {}).get("id")
            message = messaging.get("message", {})
            text = message.get("text")

            if not sender_id or not text:
                continue

            # Lưu message và dispatch sang AI service
            await _process_incoming(
                customer_id=sender_id,
                source="facebook",
                content=text,
            )

    return {"status": "ok"}


# ============================================================
# Email Webhook (Mailgun)
# ============================================================

@router.post("/email")
async def email_webhook(request: Request):
    """
    Mailgun gửi email mới vào endpoint này.
    Parse form data, verify timestamp + token + signature.
    """
    form = await request.form()

    sender = form.get("sender", "")
    subject = form.get("subject", "")
    body_plain = form.get("body-plain", "")

    if not sender or not body_plain:
        return {"status": "ignored"}

    # Verify Mailgun signature
    timestamp = form.get("timestamp", "")
    token = form.get("token", "")
    signature = form.get("signature", "")

    if MAILGUN_SIGNING_KEY:
        value = timestamp + token
        expected = hmac.new(
            MAILGUN_SIGNING_KEY.encode(),
            value.encode(),
            hashlib.sha256,
        ).hexdigest()
        if not hmac.compare_digest(signature, expected):
            raise HTTPException(status_code=403, detail="Chữ ký Mailgun không hợp lệ.")

    # Dùng sender email làm customer_id
    await _process_incoming(
        customer_id=sender,
        source="email",
        content=f"[Subject: {subject}]\n\n{body_plain}",
        customer_name=form.get("from", sender),
    )

    return {"status": "ok"}


# ============================================================
# Internal helper
# ============================================================

async def _process_incoming(
    customer_id: str,
    source: str,
    content: str,
    customer_name: str = None,
):
    """
    Lưu message vào DB và gọi AI service.
    Dùng chung cho Facebook webhook và Email webhook.
    """
    import httpx
    supabase = get_supabase_admin()

    # Tìm ticket đang mở
    existing = (
        supabase.table("tickets")
        .select("id")
        .eq("customer_id", customer_id)
        .eq("source", source)
        .in_("status", ["open", "in_progress"])
        .order("created_at", desc=True)
        .limit(1)
        .execute()
    )

    if existing.data:
        ticket_id = existing.data[0]["id"]
    else:
        new_ticket = supabase.table("tickets").insert({
            "customer_id": customer_id,
            "customer_name": customer_name,
            "source": source,
            "status": "open",
        }).execute()
        ticket_id = new_ticket.data[0]["id"]

    # Lưu message
    supabase.table("messages").insert({
        "ticket_id": ticket_id,
        "sender_type": SenderType.customer.value,
        "sender_id": customer_id,
        "content": content,
    }).execute()

    # Gọi AI service
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            await client.post(f"{AI_SERVICE_URL}/process", json={
                "ticket_id": ticket_id,
                "customer_id": customer_id,
                "source": source,
                "content": content,
            })
    except Exception:
        pass
