from sqlalchemy import Column, Integer, String, Float, Boolean, DateTime, ForeignKey, Text, Enum as SQLEnum
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.db.database import Base
import enum


class VehicleTariff(str, enum.Enum):
    """Тарифы автомобилей"""
    STANDARD = "standard"
    COMFORT = "comfort"
    BUSINESS = "business"
    PREMIUM = "premium"


class VideoType(str, enum.Enum):
    """Типы видео"""
    FILLER = "filler"        # Заполняющее видео
    CONTRACT = "contract"    # Контрактное видео


class Vehicle(Base):
    """Модель автомобиля (пользователя системы)"""
    __tablename__ = "vehicles"
    
    id = Column(Integer, primary_key=True, index=True)
    login = Column(String(100), unique=True, nullable=False, index=True)
    hashed_password = Column(String(255), nullable=False)
    car_number = Column(String(20), unique=True, nullable=False)
    tariff = Column(SQLEnum(VehicleTariff), nullable=False)
    driver_name = Column(String(200))
    phone = Column(String(20))
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    # Relationships
    sessions = relationship("VehicleSession", back_populates="vehicle")
    playback_logs = relationship("PlaybackLog", back_populates="vehicle")


class Video(Base):
    """Модель видео"""
    __tablename__ = "videos"
    
    id = Column(Integer, primary_key=True, index=True)
    title = Column(String(255), nullable=False)
    filename = Column(String(500), nullable=False)
    file_path = Column(String(1000), nullable=False)
    file_size = Column(Integer)  # в байтах
    duration = Column(Float)  # в секундах
    
    # Тип видео
    video_type = Column(SQLEnum(VideoType), nullable=False)
    
    # Для контрактных видео - сколько раз показывать в час
    plays_per_hour = Column(Integer, nullable=True)
    
    # Для каких тарифов доступно (JSON массив или отдельная таблица связей)
    # Используем строку с разделителями для простоты
    tariffs = Column(String(200))  # Например: "standard,comfort,business"
    
    # Приоритет
    priority = Column(Integer, default=0)
    
    # Статус
    is_active = Column(Boolean, default=True)
    
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    # Relationships
    playback_logs = relationship("PlaybackLog", back_populates="video")


class VehicleSession(Base):
    """Сессия работы автомобиля"""
    __tablename__ = "vehicle_sessions"
    
    id = Column(Integer, primary_key=True, index=True)
    vehicle_id = Column(Integer, ForeignKey("vehicles.id"), nullable=False)
    
    start_time = Column(DateTime(timezone=True), nullable=False)
    end_time = Column(DateTime(timezone=True), nullable=True)
    
    # Метрики сессии
    total_duration_seconds = Column(Integer, default=0)
    videos_played = Column(Integer, default=0)
    
    # Relationships
    vehicle = relationship("Vehicle", back_populates="sessions")


class PlaybackLog(Base):
    """Лог воспроизведения видео"""
    __tablename__ = "playback_logs"
    
    id = Column(Integer, primary_key=True, index=True)
    vehicle_id = Column(Integer, ForeignKey("vehicles.id"), nullable=False)
    video_id = Column(Integer, ForeignKey("videos.id"), nullable=False)
    session_id = Column(Integer, ForeignKey("vehicle_sessions.id"), nullable=True)
    
    # Время воспроизведения
    played_at = Column(DateTime(timezone=True), nullable=False, index=True)
    
    # Длительность воспроизведения (может отличаться от длительности видео)
    duration_seconds = Column(Float, nullable=False)
    
    # Было ли это в праймтайм
    is_prime_time = Column(Boolean, default=False)
    
    # Полностью ли просмотрено
    completed = Column(Boolean, default=True)
    
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    # Relationships
    vehicle = relationship("Vehicle", back_populates="playback_logs")
    video = relationship("Video", back_populates="playback_logs")


class Playlist(Base):
    """Сгенерированный плейлист для автомобиля"""
    __tablename__ = "playlists"
    
    id = Column(Integer, primary_key=True, index=True)
    vehicle_id = Column(Integer, ForeignKey("vehicles.id"), nullable=False)
    tariff = Column(SQLEnum(VehicleTariff), nullable=False)
    
    # JSON с массивом ID видео в порядке воспроизведения
    video_sequence = Column(Text, nullable=False)  # JSON array: [1, 5, 3, 1, 2, ...]
    
    # Временной диапазон действия плейлиста
    valid_from = Column(DateTime(timezone=True), nullable=False)
    valid_until = Column(DateTime(timezone=True), nullable=False)
    
    created_at = Column(DateTime(timezone=True), server_default=func.now())
