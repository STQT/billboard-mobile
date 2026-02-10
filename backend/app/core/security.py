from datetime import datetime, timedelta
from typing import Optional
import bcrypt
from jose import JWTError, jwt
from app.core.config import settings

# Bcrypt принимает максимум 72 байта
BCRYPT_MAX_PASSWORD_BYTES = 72


def _to_bcrypt_password(s: str) -> bytes:
    """Привести пароль к bytes и обрезать до 72 байт (ограничение bcrypt)."""
    if isinstance(s, str):
        s = s.encode("utf-8")
    return s[:BCRYPT_MAX_PASSWORD_BYTES]


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Проверка пароля."""
    try:
        password_bytes = _to_bcrypt_password(plain_password)
        hashed_bytes = hashed_password.encode("utf-8") if isinstance(hashed_password, str) else hashed_password
        return bcrypt.checkpw(password_bytes, hashed_bytes)
    except Exception:
        return False


def get_password_hash(password: str) -> str:
    """Хеширование пароля (обрезается до 72 байт)."""
    password_bytes = _to_bcrypt_password(password)
    hashed = bcrypt.hashpw(password_bytes, bcrypt.gensalt(rounds=12))
    return hashed.decode("utf-8")


def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    """Создание JWT токена"""
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM)
    return encoded_jwt


def decode_access_token(token: str) -> Optional[dict]:
    """Декодирование JWT токена"""
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        return payload
    except JWTError:
        return None
