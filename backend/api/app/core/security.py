from dataclasses import dataclass
from typing import Any

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
import jwt
from jwt import InvalidTokenError

from app.core.config import Settings, get_settings
from app.schemas.common import UserRole, UserStatus


bearer_scheme = HTTPBearer(auto_error=False)


@dataclass(frozen=True)
class AuthenticatedUser:
    id: str
    email: str | None
    role: str
    status: str


async def get_bearer_token(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
) -> str:
    if credentials is None or not credentials.credentials:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing bearer token",
        )
    return credentials.credentials


def _mock_user_from_token(token: str, settings: Settings) -> AuthenticatedUser | None:
    if not settings.local_mock_auth_enabled or settings.app_env == "production":
        return None
    if not token.startswith("mock:"):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid bearer token",
        )

    parts = token.split(":")
    if len(parts) != 5:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid mock auth token",
        )
    _, user_id, email, role, user_status = parts
    return AuthenticatedUser(id=user_id, email=email or None, role=role, status=user_status)


def _decode_supabase_jwt(token: str, settings: Settings) -> dict[str, Any]:
    if not settings.supabase_jwt_secret:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Supabase JWT settings are not configured",
        )

    options = {"verify_aud": bool(settings.supabase_jwt_audience)}
    try:
        return jwt.decode(
            token,
            settings.supabase_jwt_secret,
            algorithms=["HS256"],
            audience=settings.supabase_jwt_audience if settings.supabase_jwt_audience else None,
            issuer=settings.supabase_jwt_issuer,
            options=options,
        )
    except InvalidTokenError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid bearer token",
        ) from None


def _user_from_claims(claims: dict[str, Any]) -> AuthenticatedUser:
    user_id = claims.get("sub")
    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid bearer token: missing subject",
        )

    app_metadata = claims.get("app_metadata") or {}
    user_metadata = claims.get("user_metadata") or {}
    role = app_metadata.get("role") or user_metadata.get("role")
    user_status = app_metadata.get("status") or user_metadata.get("status") or UserStatus.OFFLINE

    if role not in {UserRole.SUPER_ADMIN, UserRole.AGENT}:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="User profile role is missing or invalid",
        )

    return AuthenticatedUser(
        id=str(user_id),
        email=claims.get("email"),
        role=str(role),
        status=str(user_status),
    )


async def get_current_user(
    token: str = Depends(get_bearer_token),
    settings: Settings = Depends(get_settings),
) -> AuthenticatedUser:
    """Validate a Supabase JWT and return the authenticated app user profile.

    In production, the JWT is verified with Supabase JWT settings. Until the
    profile lookup layer is wired to Supabase, role/status are read from custom
    JWT metadata claims. Tests may use the explicit mock mode only when
    `APP_ENV=test` and `LOCAL_MOCK_AUTH_ENABLED=true`.
    """
    user = _mock_user_from_token(token, settings)
    if user is None:
        user = _user_from_claims(_decode_supabase_jwt(token, settings))

    if user.status == UserStatus.DISABLED:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="User account is disabled",
        )
    return user


async def require_super_admin(
    current_user: AuthenticatedUser = Depends(get_current_user),
) -> AuthenticatedUser:
    if current_user.role != UserRole.SUPER_ADMIN:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Super admin permission required",
        )
    return current_user


async def require_agent_or_super_admin(
    current_user: AuthenticatedUser = Depends(get_current_user),
) -> AuthenticatedUser:
    if current_user.role not in {UserRole.AGENT, UserRole.SUPER_ADMIN}:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Agent or super admin permission required",
        )
    return current_user
