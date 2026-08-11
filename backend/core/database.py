import os
from supabase import create_client, Client
from functools import lru_cache


SUPABASE_URL = os.getenv("SUPABASE_URL", "")
SUPABASE_ANON_KEY = os.getenv("SUPABASE_ANON_KEY", "")
SUPABASE_SERVICE_KEY = os.getenv("SUPABASE_SERVICE_KEY", "")


@lru_cache(maxsize=1)
def get_supabase_client() -> Client:
    """Anon client — dùng cho các query theo phân quyền RLS của user."""
    if not SUPABASE_URL or not SUPABASE_ANON_KEY:
        raise RuntimeError("SUPABASE_URL và SUPABASE_ANON_KEY phải được set trong .env")
    return create_client(SUPABASE_URL, SUPABASE_ANON_KEY)


@lru_cache(maxsize=1)
def get_supabase_admin() -> Client:
    """Service-role client — bypass RLS, dùng cho AI bot tạo ticket/message."""
    if not SUPABASE_URL or not SUPABASE_SERVICE_KEY:
        raise RuntimeError("SUPABASE_URL và SUPABASE_SERVICE_KEY phải được set trong .env")
    return create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)
