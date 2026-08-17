"""
Channel Notification Services — Smart Helpdesk
Gửi tin nhắn phản hồi về cho khách hàng qua Facebook Messenger và Mailgun Email API.
"""
import os
import httpx
import logging
from typing import Optional

logger = logging.getLogger(__name__)

# Config từ env vars hoặc channel config JSONB
FB_PAGE_ACCESS_TOKEN = os.getenv("FB_PAGE_ACCESS_TOKEN", "")
MAILGUN_API_KEY = os.getenv("MAILGUN_API_KEY", "")
MAILGUN_DOMAIN = os.getenv("MAILGUN_DOMAIN", "")
MAILGUN_SENDER_EMAIL = os.getenv("MAILGUN_SENDER_EMAIL", "support@helpdesk.com")


async def send_facebook_message(recipient_psid: str, text_content: str, token_override: Optional[str] = None) -> bool:
    """
    Gửi tin nhắn phản hồi đến Facebook Messenger qua Graph API Send API.
    Docs: https://developers.facebook.com/docs/messenger-platform/reference/send-api/
    """
    page_token = token_override or FB_PAGE_ACCESS_TOKEN
    if not page_token:
        logger.warning("Facebook Page Access Token chưa được cấu hình. Bỏ qua gửi Facebook message.")
        return False

    url = f"https://graph.facebook.com/v19.0/me/messages?access_token={page_token}"
    payload = {
        "recipient": {"id": recipient_psid},
        "message": {"text": text_content},
    }

    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            res = await client.post(url, json=payload)
            if res.status_code == 200:
                logger.info(f"Đã gửi tin nhắn Facebook tới {recipient_psid}")
                return True
            else:
                logger.error(f"Lỗi gửi Facebook message ({res.status_code}): {res.text}")
                return False
    except Exception as e:
        logger.error(f"Ngoại lệ khi gọi Facebook Send API: {str(e)}")
        return False


async def send_email_message(to_email: str, subject: str, text_content: str, api_key_override: Optional[str] = None) -> bool:
    """
    Gửi email phản hồi đến khách hàng qua Mailgun API.
    Docs: https://documentation.mailgun.com/docs/mailgun/api-reference/send-messages/
    """
    api_key = api_key_override or MAILGUN_API_KEY
    domain = MAILGUN_DOMAIN

    if not api_key or not domain:
        logger.warning("Mailgun API Key hoặc Domain chưa được cấu hình. Bỏ qua gửi Email.")
        return False

    url = f"https://api.mailgun.net/v3/{domain}/messages"
    auth = ("api", api_key)
    data = {
        "from": f"Smart Helpdesk Support <{MAILGUN_SENDER_EMAIL}>",
        "to": [to_email],
        "subject": subject or "Phản hồi từ Smart Helpdesk Support",
        "text": text_content,
    }

    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            res = await client.post(url, auth=auth, data=data)
            if res.status_code in (200, 201):
                logger.info(f"Đã gửi email phản hồi tới {to_email}")
                return True
            else:
                logger.error(f"Lỗi gửi Email qua Mailgun ({res.status_code}): {res.text}")
                return False
    except Exception as e:
        logger.error(f"Ngoại lệ khi gọi Mailgun API: {str(e)}")
        return False


async def dispatch_channel_reply(source: str, customer_id: str, content: str, ticket_summary: Optional[str] = None):
    """
    Tự động định tuyến tin nhắn phản hồi của Agent về đúng kênh của khách hàng.
    """
    if source == "facebook":
        await send_facebook_message(recipient_psid=customer_id, text_content=content)
    elif source == "email":
        subject = f"Re: {ticket_summary}" if ticket_summary else "Phản hồi hỗ trợ từ Smart Helpdesk"
        await send_email_message(to_email=customer_id, subject=subject, text_content=content)
    elif source == "web":
        # Với web, Supabase Realtime tự động broadcast event INSERT messages tới Chat Widget subscriber.
        pass
