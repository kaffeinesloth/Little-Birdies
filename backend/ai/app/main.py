from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import get_settings
from app.core.errors import install_error_handlers
from app.core.middleware import RequestSizeLimitMiddleware, SafeAccessLogMiddleware
from app.routers import classify, documents, health, process_message, rag


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
        allow_methods=["GET", "POST", "OPTIONS"],
        allow_headers=["Content-Type", "Authorization"],
    )
    app.add_middleware(RequestSizeLimitMiddleware, max_body_bytes=settings.max_request_body_bytes)
    app.add_middleware(SafeAccessLogMiddleware)
    install_error_handlers(app)
    app.include_router(health.router)
    app.include_router(classify.router)
    app.include_router(rag.router)
    app.include_router(process_message.router)
    app.include_router(documents.router)
    return app


app = create_app()
