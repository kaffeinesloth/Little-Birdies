import json
from urllib.parse import parse_qs

from fastapi import APIRouter, Depends, Header, HTTPException, Query, Request, Response, status

from app.core.config import Settings, get_settings
from app.db.supabase import get_supabase_client
from app.schemas.common import ChannelType
from app.schemas.webhooks import InboundMessageRequest
from app.services.ai_client import AIProcessor, get_ai_processor
from app.services.email import (
    EmailWebhookError,
    parse_email_message,
    verify_mailgun_signature,
    verify_sendgrid_signature,
)
from app.services.facebook import (
    FacebookWebhookError,
    parse_facebook_message,
    verify_facebook_signature,
)
from app.services.orchestrator import process_inbound_message
from app.services.supabase_table import SupabaseClient


router = APIRouter(prefix="/webhooks", tags=["webhooks"])


def _bad_webhook(exc: ValueError) -> HTTPException:
    return HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc))


async def _payload_from_request(request: Request) -> dict:
    raw_body = await request.body()
    settings = get_settings()
    if len(raw_body) > settings.max_request_body_bytes:
        raise HTTPException(status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE, detail="Request body is too large")
    content_type = request.headers.get("content-type", "")
    if "application/json" in content_type:
        return json.loads(raw_body.decode("utf-8") or "{}")
    if "application/x-www-form-urlencoded" in content_type or "multipart/form-data" in content_type:
        parsed = parse_qs(raw_body.decode("utf-8"), keep_blank_values=True)
        return {key: values[-1] if values else "" for key, values in parsed.items()}
    return json.loads(raw_body.decode("utf-8") or "{}")


def _response(result) -> dict:
    return {
        "ticket": result.ticket,
        "customer_message": result.customer_message,
        "bot_message": result.bot_message,
        "notifications": result.notifications,
        "action": result.action,
        "intent": result.intent,
    }


@router.post("/web-message")
async def web_message(
    payload: InboundMessageRequest,
    client: SupabaseClient = Depends(get_supabase_client),
    ai_processor: AIProcessor = Depends(get_ai_processor),
) -> dict:
    return _response(
        process_inbound_message(
            client=client,
            ai_processor=ai_processor,
            source=ChannelType.WEB,
            sender_id=payload.sender_id,
            content=payload.content,
            customer_name=payload.customer_name,
        )
    )


@router.get("/facebook")
async def verify_facebook_webhook(
    hub_mode: str | None = Query(default=None, alias="hub.mode"),
    hub_verify_token: str | None = Query(default=None, alias="hub.verify_token"),
    hub_challenge: str | None = Query(default=None, alias="hub.challenge"),
    settings: Settings = Depends(get_settings),
) -> Response:
    if hub_mode == "subscribe" and hub_verify_token and hub_verify_token == settings.facebook_verify_token:
        return Response(content=hub_challenge or "", media_type="text/plain")
    raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Invalid Facebook verify token")


@router.post("/facebook")
async def facebook_message(
    request: Request,
    x_hub_signature_256: str | None = Header(default=None, alias="X-Hub-Signature-256"),
    settings: Settings = Depends(get_settings),
    client: SupabaseClient = Depends(get_supabase_client),
    ai_processor: AIProcessor = Depends(get_ai_processor),
) -> dict:
    raw_body = await request.body()
    if len(raw_body) > settings.max_request_body_bytes:
        raise HTTPException(status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE, detail="Request body is too large")
    try:
        verify_facebook_signature(x_hub_signature_256, raw_body, settings)
        payload = json.loads(raw_body.decode("utf-8") or "{}")
        parsed = parse_facebook_message(payload)
    except (FacebookWebhookError, json.JSONDecodeError) as exc:
        raise _bad_webhook(ValueError(str(exc))) from exc
    if parsed is None:
        return {"action": "ignored", "reason": "No text message event"}
    return _response(
        process_inbound_message(
            client=client,
            ai_processor=ai_processor,
            source=ChannelType.FACEBOOK,
            sender_id=parsed.sender_id,
            content=parsed.content,
            customer_name=parsed.customer_name,
        )
    )


@router.post("/email")
async def email_message(
    request: Request,
    x_webhook_signature: str | None = Header(default=None, alias="X-Webhook-Signature"),
    x_sendgrid_signature: str | None = Header(default=None, alias="X-Twilio-Email-Event-Webhook-Signature"),
    provider: str = Query(default="mailgun"),
    settings: Settings = Depends(get_settings),
    client: SupabaseClient = Depends(get_supabase_client),
    ai_processor: AIProcessor = Depends(get_ai_processor),
) -> dict:
    try:
        payload = await _payload_from_request(request)
        if provider == "sendgrid":
            verify_sendgrid_signature(x_sendgrid_signature or x_webhook_signature, settings)
        else:
            if x_webhook_signature and "signature" not in payload:
                payload["signature"] = x_webhook_signature
            verify_mailgun_signature(payload, settings)
        parsed = parse_email_message(payload, provider)
    except (EmailWebhookError, ValueError, json.JSONDecodeError) as exc:
        raise _bad_webhook(ValueError(str(exc))) from exc
    return _response(
        process_inbound_message(
            client=client,
            ai_processor=ai_processor,
            source=ChannelType.EMAIL,
            sender_id=parsed.sender_id,
            content=parsed.content,
            customer_name=parsed.customer_name,
        )
    )
