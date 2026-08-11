import logging
import time
from collections import defaultdict, deque
from collections.abc import Awaitable, Callable

from fastapi import Request, Response, status
from starlette.middleware.base import BaseHTTPMiddleware

from app.core.config import Settings


logger = logging.getLogger("smart_helpdesk.api")


class RequestSizeLimitMiddleware(BaseHTTPMiddleware):
    def __init__(self, app, *, max_body_bytes: int) -> None:
        super().__init__(app)
        self.max_body_bytes = max_body_bytes

    async def dispatch(self, request: Request, call_next: Callable[[Request], Awaitable[Response]]) -> Response:
        content_length = request.headers.get("content-length")
        if content_length and int(content_length) > self.max_body_bytes:
            return Response(
                content='{"error":{"code":"request_too_large","message":"Request body is too large"}}',
                status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                media_type="application/json",
            )
        return await call_next(request)


class SafeAccessLogMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next: Callable[[Request], Awaitable[Response]]) -> Response:
        started = time.perf_counter()
        response = await call_next(request)
        elapsed_ms = round((time.perf_counter() - started) * 1000, 2)
        logger.info(
            "request_complete",
            extra={
                "method": request.method,
                "path": request.url.path,
                "status_code": response.status_code,
                "elapsed_ms": elapsed_ms,
            },
        )
        return response


class InMemoryRateLimitMiddleware(BaseHTTPMiddleware):
    def __init__(self, app, *, settings: Settings) -> None:
        super().__init__(app)
        self.limit = settings.public_endpoint_rate_limit
        self.window_seconds = settings.public_endpoint_rate_window_seconds
        self.requests: dict[str, deque[float]] = defaultdict(deque)
        self.public_prefixes = ("/webhooks/",)

    async def dispatch(self, request: Request, call_next: Callable[[Request], Awaitable[Response]]) -> Response:
        if request.method != "OPTIONS" and request.url.path.startswith(self.public_prefixes):
            now = time.monotonic()
            key = f"{request.client.host if request.client else 'unknown'}:{request.url.path}"
            timestamps = self.requests[key]
            while timestamps and now - timestamps[0] > self.window_seconds:
                timestamps.popleft()
            if len(timestamps) >= self.limit:
                return Response(
                    content='{"error":{"code":"rate_limited","message":"Too many requests"}}',
                    status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                    media_type="application/json",
                )
            timestamps.append(now)
        return await call_next(request)
