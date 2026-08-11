from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import get_settings
from app.core.errors import install_error_handlers
from app.core.middleware import (
    InMemoryRateLimitMiddleware,
    RequestSizeLimitMiddleware,
    SafeAccessLogMiddleware,
)
from app.routers import health, presence, protected, tickets, webhooks


def create_app() -> FastAPI:
    settings = get_settings()
    app = FastAPI(
        title=settings.app_name,
        version=settings.app_version,
        docs_url="/docs" if settings.debug else None,
        redoc_url="/redoc" if settings.debug else None,
    )
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origins,
        allow_credentials=True,
        allow_methods=["GET", "POST", "PATCH", "OPTIONS"],
        allow_headers=["Authorization", "Content-Type", "X-Hub-Signature-256", "X-Webhook-Signature"],
    )
    app.add_middleware(InMemoryRateLimitMiddleware, settings=settings)
    app.add_middleware(RequestSizeLimitMiddleware, max_body_bytes=settings.max_request_body_bytes)
    app.add_middleware(SafeAccessLogMiddleware)
    install_error_handlers(app)
    app.include_router(health.router)
    app.include_router(presence.router)
    app.include_router(tickets.router)
    app.include_router(webhooks.router)
    app.include_router(protected.router)
    return app


app = create_app()
