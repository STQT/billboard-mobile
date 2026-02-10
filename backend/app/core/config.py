from pydantic_settings import BaseSettings
from typing import Optional


class Settings(BaseSettings):
    # PostgreSQL (используются в docker-compose.yml)
    POSTGRES_USER: Optional[str] = "billboard_user"
    POSTGRES_PASSWORD: Optional[str] = "billboard_pass"
    POSTGRES_DB: Optional[str] = "billboard_db"
    POSTGRES_PORT: Optional[int] = 5432
    
    # Database URL для приложения
    DATABASE_URL: str = "postgresql://billboard_user:billboard_pass@localhost:5432/billboard_db"
    
    # Redis
    REDIS_PORT: Optional[int] = 6379
    REDIS_URL: str = "redis://localhost:6379/0"
    
    # JWT
    SECRET_KEY: str = "your-secret-key-change-in-production"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 43200  # 30 days for vehicles
    
    # File Storage
    UPLOAD_DIR: str = "./uploads/videos"
    MAX_VIDEO_SIZE_MB: int = 500
    UPLOADS_VOLUME_PATH: str = "./uploads"
    
    # Prime Time (час пик)
    PRIME_TIME_START: int = 18  # 18:00
    PRIME_TIME_END: int = 22    # 22:00
    PRIME_TIME_MULTIPLIER: float = 1.5
    
    # Server
    HOST: str = "0.0.0.0"
    PORT: int = 8000
    DEBUG: bool = True  # Режим отладки (включает автоперезагрузку)
    
    # Base URL for media files (можно переопределить через .env)
    BASE_URL: Optional[str] = None  # Если None, будет формироваться автоматически
    
    class Config:
        env_file = ".env"
        case_sensitive = True
        # extra = "ignore"  # Игнорировать дополнительные переменные из .env


settings = Settings()
