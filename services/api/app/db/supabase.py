from dataclasses import dataclass

from fastapi import Depends

from app.core.config import Settings, get_settings
from app.db.local_supabase import local_supabase
from app.services.supabase_table import SupabaseClient


@dataclass(frozen=True)
class SupabaseConfig:
    url: str | None
    anon_key: str | None
    service_role_key: str | None

    @property
    def is_configured(self) -> bool:
        return bool(self.url and self.service_role_key)


def get_supabase_config(settings: Settings | None = None) -> SupabaseConfig:
    settings = settings or get_settings()
    return SupabaseConfig(
        url=settings.supabase_url,
        anon_key=settings.supabase_anon_key,
        service_role_key=settings.supabase_service_role_key,
    )


def get_supabase_client(settings: Settings = Depends(get_settings)) -> SupabaseClient:
    if settings.local_mock_auth_enabled and settings.app_env != "production":
        return local_supabase
    config = get_supabase_config(settings)
    if not config.is_configured:
        raise RuntimeError("Supabase client is not configured")
    raise NotImplementedError("Supabase client adapter is not implemented yet")
