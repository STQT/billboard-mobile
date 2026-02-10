from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime
from app.models.models import VehicleTariff, VideoType


# Bcrypt принимает пароль до 72 байт
PASSWORD_MAX_LENGTH = 72


# Vehicle Schemas
class VehicleCreate(BaseModel):
    login: str
    password: str = Field(..., min_length=1, max_length=PASSWORD_MAX_LENGTH)
    car_number: str
    tariff: VehicleTariff
    driver_name: Optional[str] = None
    phone: Optional[str] = None


class VehicleResponse(BaseModel):
    id: int
    login: str
    car_number: str
    tariff: VehicleTariff
    driver_name: Optional[str]
    phone: Optional[str]
    is_active: bool
    created_at: datetime
    
    class Config:
        from_attributes = True


class VehicleLogin(BaseModel):
    login: str
    password: str = Field(..., min_length=1, max_length=PASSWORD_MAX_LENGTH)


class VehicleUpdate(BaseModel):
    login: str
    password: Optional[str] = Field(None, min_length=1, max_length=PASSWORD_MAX_LENGTH)
    car_number: str
    tariff: VehicleTariff
    driver_name: Optional[str] = None
    phone: Optional[str] = None


class Token(BaseModel):
    access_token: str
    token_type: str


# Video Schemas
class VideoCreate(BaseModel):
    title: str
    video_type: VideoType
    plays_per_hour: Optional[int] = None
    tariffs: List[VehicleTariff]
    priority: int = 0


class VideoUpdate(BaseModel):
    title: Optional[str] = None
    video_type: Optional[VideoType] = None
    plays_per_hour: Optional[int] = None
    tariffs: Optional[List[VehicleTariff]] = None
    priority: Optional[int] = None
    is_active: Optional[bool] = None
    duration: Optional[float] = None  # Длительность в секундах


class VideoResponse(BaseModel):
    id: int
    title: str
    filename: str
    file_path: str
    file_size: Optional[int]
    duration: Optional[float]
    video_type: VideoType
    plays_per_hour: Optional[int]
    tariffs: str
    priority: int
    is_active: bool
    created_at: datetime
    
    class Config:
        from_attributes = True


# Session Schemas
class SessionStart(BaseModel):
    vehicle_id: int


class SessionEnd(BaseModel):
    session_id: int


class SessionResponse(BaseModel):
    id: int
    vehicle_id: int
    start_time: datetime
    end_time: Optional[datetime]
    total_duration_seconds: int
    videos_played: int
    
    class Config:
        from_attributes = True


# Playback Log Schemas
class PlaybackLogCreate(BaseModel):
    video_id: int
    duration_seconds: float
    completed: bool = True


class PlaybackLogResponse(BaseModel):
    id: int
    vehicle_id: int
    video_id: int
    played_at: datetime
    duration_seconds: float
    is_prime_time: bool
    completed: bool
    
    class Config:
        from_attributes = True


# Playlist Schemas
class ContractVideoItem(BaseModel):
    """Контрактное видео с временными метками"""
    video_id: int
    start_time: float  # Время начала в секундах от начала часа (0-3600)
    end_time: float    # Время окончания в секундах от начала часа (0-3600)
    duration: float    # Длительность в секундах
    frequency: int = 1  # Количество повторений этого видео в плейлисте
    file_path: str      # Путь к файлу (например, /uploads/videos/filename.mp4)
    media_url: str      # Полный URL для доступа к медиа файлу


class FillerVideoItem(BaseModel):
    """Филлерное видео с информацией"""
    video_id: int
    duration: float    # Длительность в секундах
    file_path: str     # Путь к файлу (например, /uploads/videos/filename.mp4)
    media_url: str     # Полный URL для доступа к медиа файлу


class PlaylistResponse(BaseModel):
    id: int
    vehicle_id: Optional[int] = None  # None для плейлиста по тарифу
    tariff: VehicleTariff
    # Контрактные видео с временными метками
    contract_videos: List[ContractVideoItem]
    # Список филлеров с длительностью
    filler_videos: List[FillerVideoItem]
    # Упорядоченная последовательность ID видео для воспроизведения
    video_sequence: List[int]
    # Общая длительность плейлиста в секундах (3600 для часового плейлиста)
    total_duration: float = 3600.0
    valid_from: datetime
    valid_until: datetime
    created_at: datetime
    
    class Config:
        from_attributes = True


# Analytics Schemas
class DailyAnalytics(BaseModel):
    date: str
    total_duration_seconds: int
    videos_played: int
    prime_time_duration_seconds: int
    earnings: float


class VideoAnalytics(BaseModel):
    video_id: int
    video_title: str
    play_count: int
    total_duration: float


class VehicleAnalytics(BaseModel):
    vehicle_id: int
    car_number: str
    daily_stats: List[DailyAnalytics]
    video_stats: List[VideoAnalytics]
    total_earnings: float
