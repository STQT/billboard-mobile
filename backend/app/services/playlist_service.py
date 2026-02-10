from sqlalchemy.orm import Session
from datetime import datetime, timedelta
from typing import List
import json
from app.models.models import Video, VideoType, VehicleTariff, Playlist
from app.core.config import settings


class PlaylistService:
    """Сервис для генерации плейлистов"""
    
    @staticmethod
    def generate_hourly_playlist(db: Session, tariff: VehicleTariff, vehicle_id: int) -> List[int]:
        """
        Генерация плейлиста на 1 час с учетом контрактных видео и филлеров
        
        Логика:
        1. Получить все контрактные видео для данного тарифа
        2. Рассчитать количество показов каждого контрактного видео в час
        3. Заполнить оставшиеся слоты филлерами
        4. Перемешать так, чтобы контрактные видео были равномерно распределены
        """
        
        # Получить все активные видео для данного тарифа
        contract_videos = db.query(Video).filter(
            Video.is_active == True,
            Video.video_type == VideoType.CONTRACT,
            Video.tariffs.contains(tariff.value)
        ).all()
        
        filler_videos = db.query(Video).filter(
            Video.is_active == True,
            Video.video_type == VideoType.FILLER,
            Video.tariffs.contains(tariff.value)
        ).order_by(Video.priority.desc()).all()
        
        # Создать последовательность видео
        playlist_sequence = []
        
        # Добавить контрактные видео с нужной частотой
        for video in contract_videos:
            plays = video.plays_per_hour or 1
            for _ in range(plays):
                playlist_sequence.append(video.id)
        
        # Рассчитать сколько времени займут контрактные видео
        total_contract_duration = sum(
            (video.duration or 0) * (video.plays_per_hour or 1) 
            for video in contract_videos
        )
        
        # Заполнить оставшееся время филлерами (примерно до 1 часа = 3600 секунд)
        remaining_time = max(0, 3600 - total_contract_duration)
        filler_index = 0
        max_filler_slots = 5000  # защита от бесконечного цикла
        
        while remaining_time > 0 and filler_videos and len(playlist_sequence) < max_filler_slots:
            video = filler_videos[filler_index % len(filler_videos)]
            duration = video.duration or 0
            if duration <= 0:
                # без длительности не добавляем в цикл — избегаем бесконечного цикла
                filler_index += 1
                if filler_index >= len(filler_videos):
                    break
                continue
            playlist_sequence.append(video.id)
            remaining_time -= duration
            filler_index += 1
        
        # Перемешать плейлист для равномерного распределения
        # (простая стратегия - можно улучшить)
        playlist_sequence = PlaylistService._distribute_evenly(
            playlist_sequence, 
            [v.id for v in contract_videos]
        )
        
        return playlist_sequence
    
    @staticmethod
    def _distribute_evenly(sequence: List[int], priority_ids: List[int]) -> List[int]:
        """
        Распределить priority_ids равномерно по всему плейлисту
        """
        if not priority_ids:
            return sequence
        
        # Отделить контрактные видео от филлеров
        contract_items = [x for x in sequence if x in priority_ids]
        filler_items = [x for x in sequence if x not in priority_ids]
        
        if not contract_items:
            return sequence
        
        # Равномерно распределить контрактные видео
        result = []
        contract_step = len(sequence) / len(contract_items) if contract_items else 1
        
        contract_positions = [int(i * contract_step) for i in range(len(contract_items))]
        
        filler_idx = 0
        contract_idx = 0
        
        for i in range(len(sequence)):
            if i in contract_positions and contract_idx < len(contract_items):
                result.append(contract_items[contract_idx])
                contract_idx += 1
            else:
                if filler_idx < len(filler_items):
                    result.append(filler_items[filler_idx])
                    filler_idx += 1
        
        return result
    
    @staticmethod
    def create_playlist(db: Session, vehicle_id: int, tariff: VehicleTariff, hours: int = 24) -> Playlist:
        """
        Создать плейлист для автомобиля: генерируется только 1 час контента.
        Период действия — hours (по умолчанию 24). Приложение зацикливает часовой плейлист.
        """
        # Один часовой плейлист — приложение зациклит его
        hourly_sequence = PlaylistService.generate_hourly_playlist(db, tariff, vehicle_id)
        
        now = datetime.utcnow()
        playlist = Playlist(
            vehicle_id=vehicle_id,
            tariff=tariff,
            video_sequence=json.dumps(hourly_sequence),
            valid_from=now,
            valid_until=now + timedelta(hours=hours)
        )
        
        db.add(playlist)
        db.commit()
        db.refresh(playlist)
        
        return playlist
    
    @staticmethod
    def get_active_playlist(db: Session, vehicle_id: int) -> Playlist:
        """
        Получить активный плейлист для автомобиля
        """
        now = datetime.utcnow()
        return db.query(Playlist).filter(
            Playlist.vehicle_id == vehicle_id,
            Playlist.valid_from <= now,
            Playlist.valid_until > now
        ).order_by(Playlist.created_at.desc()).first()
