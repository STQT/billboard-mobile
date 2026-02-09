from sqlalchemy.orm import Session
from sqlalchemy import func, and_
from datetime import datetime, date, timedelta
from typing import List
from app.models.models import PlaybackLog, Video, Vehicle, VehicleSession
from app.schemas.schemas import DailyAnalytics, VideoAnalytics, VehicleAnalytics
from app.core.config import settings


class AnalyticsService:
    """Сервис аналитики"""
    
    @staticmethod
    def is_prime_time(dt: datetime) -> bool:
        """Проверка на праймтайм"""
        hour = dt.hour
        return settings.PRIME_TIME_START <= hour < settings.PRIME_TIME_END
    
    @staticmethod
    def calculate_earnings(duration_seconds: float, is_prime_time: bool) -> float:
        """
        Расчет заработка
        Базовая ставка: 100 сум за секунду (можно настроить)
        В праймтайм - умножается на коэффициент
        """
        BASE_RATE_PER_SECOND = 100  # сум
        
        earnings = duration_seconds * BASE_RATE_PER_SECOND
        
        if is_prime_time:
            earnings *= settings.PRIME_TIME_MULTIPLIER
        
        return earnings
    
    @staticmethod
    def get_vehicle_analytics(
        db: Session, 
        vehicle_id: int, 
        start_date: date, 
        end_date: date
    ) -> VehicleAnalytics:
        """
        Получить аналитику для автомобиля за период
        """
        vehicle = db.query(Vehicle).filter(Vehicle.id == vehicle_id).first()
        if not vehicle:
            raise ValueError("Vehicle not found")
        
        # Получить логи за период
        logs = db.query(PlaybackLog).filter(
            and_(
                PlaybackLog.vehicle_id == vehicle_id,
                func.date(PlaybackLog.played_at) >= start_date,
                func.date(PlaybackLog.played_at) <= end_date
            )
        ).all()
        
        # Группировать по дням
        daily_stats = {}
        video_stats = {}
        
        for log in logs:
            log_date = log.played_at.date()
            day_key = log_date.isoformat()
            
            if day_key not in daily_stats:
                daily_stats[day_key] = {
                    'date': day_key,
                    'total_duration_seconds': 0,
                    'videos_played': 0,
                    'prime_time_duration_seconds': 0,
                    'earnings': 0
                }
            
            daily_stats[day_key]['total_duration_seconds'] += int(log.duration_seconds)
            daily_stats[day_key]['videos_played'] += 1
            
            if log.is_prime_time:
                daily_stats[day_key]['prime_time_duration_seconds'] += int(log.duration_seconds)
            
            earnings = AnalyticsService.calculate_earnings(
                log.duration_seconds, 
                log.is_prime_time
            )
            daily_stats[day_key]['earnings'] += earnings
            
            # Статистика по видео
            if log.video_id not in video_stats:
                video = db.query(Video).filter(Video.id == log.video_id).first()
                video_stats[log.video_id] = {
                    'video_id': log.video_id,
                    'video_title': video.title if video else 'Unknown',
                    'play_count': 0,
                    'total_duration': 0
                }
            
            video_stats[log.video_id]['play_count'] += 1
            video_stats[log.video_id]['total_duration'] += log.duration_seconds
        
        # Конвертировать в модели
        daily_analytics = [DailyAnalytics(**stats) for stats in daily_stats.values()]
        video_analytics = [VideoAnalytics(**stats) for stats in video_stats.values()]
        
        total_earnings = sum(day['earnings'] for day in daily_stats.values())
        
        return VehicleAnalytics(
            vehicle_id=vehicle_id,
            car_number=vehicle.car_number,
            daily_stats=daily_analytics,
            video_stats=video_analytics,
            total_earnings=total_earnings
        )
    
    @staticmethod
    def log_playback(
        db: Session,
        vehicle_id: int,
        video_id: int,
        duration_seconds: float,
        session_id: int = None,
        completed: bool = True
    ) -> PlaybackLog:
        """
        Записать лог воспроизведения
        """
        now = datetime.utcnow()
        is_prime = AnalyticsService.is_prime_time(now)
        
        log = PlaybackLog(
            vehicle_id=vehicle_id,
            video_id=video_id,
            session_id=session_id,
            played_at=now,
            duration_seconds=duration_seconds,
            is_prime_time=is_prime,
            completed=completed
        )
        
        db.add(log)
        db.commit()
        db.refresh(log)
        
        return log
    
    @staticmethod
    def start_session(db: Session, vehicle_id: int) -> VehicleSession:
        """Начать сессию работы автомобиля"""
        session = VehicleSession(
            vehicle_id=vehicle_id,
            start_time=datetime.utcnow()
        )
        db.add(session)
        db.commit()
        db.refresh(session)
        return session
    
    @staticmethod
    def end_session(db: Session, session_id: int) -> VehicleSession:
        """Завершить сессию работы автомобиля"""
        session = db.query(VehicleSession).filter(VehicleSession.id == session_id).first()
        if not session:
            raise ValueError("Session not found")
        
        session.end_time = datetime.utcnow()
        
        # Рассчитать метрики
        duration = (session.end_time - session.start_time).total_seconds()
        session.total_duration_seconds = int(duration)
        
        # Подсчитать видео
        videos_count = db.query(PlaybackLog).filter(
            PlaybackLog.session_id == session_id
        ).count()
        session.videos_played = videos_count
        
        db.commit()
        db.refresh(session)
        return session
