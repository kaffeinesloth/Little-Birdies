"""
db/client.py — Supabase client singleton.

Dùng service_key (không phải anon_key) cho server-side operations
vì cần bypass Row Level Security.
"""
from __future__ import annotations

from functools import lru_cache

from supabase import AsyncClient, acreate_client

from config import settings


@lru_cache(maxsize=1)
def _get_cached_client() -> AsyncClient | None:
    """
    Note: acreate_client là async, nhưng lru_cache không hỗ trợ async.
    Workaround: dùng _client_holder để cache sau lần đầu khởi tạo.
    """
    return None   # placeholder — client thực được init bởi get_supabase()


_client_holder: AsyncClient | None = None


async def get_supabase() -> AsyncClient:
    """
    Trả về Supabase AsyncClient singleton.
    Gọi ở startup hoặc trong Depends().
    """
    global _client_holder
    if not settings.supabase_url or not settings.supabase_service_key:
        raise RuntimeError("SUPABASE_URL and SUPABASE_SERVICE_KEY are not configured")

    if _client_holder is None:
        _client_holder = await acreate_client(
            supabase_url=settings.supabase_url,
            supabase_key=settings.supabase_service_key,
        )
    return _client_holder
