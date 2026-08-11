import pytest

from app.core.config import get_settings


@pytest.fixture(autouse=True)
def isolate_settings(monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setenv("LOCAL_MOCK_AUTH_ENABLED", "true")
    monkeypatch.setenv("LOCAL_MOCK_DB_ENABLED", "true")
    get_settings.cache_clear()
    yield
    get_settings.cache_clear()
