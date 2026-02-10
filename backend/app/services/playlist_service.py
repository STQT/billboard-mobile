from sqlalchemy.orm import Session
from datetime import datetime, timedelta
from typing import List, Optional, Tuple, Dict
import json
import random
from collections import Counter
from app.models.models import Video, VideoType, VehicleTariff, Playlist
from app.core.config import settings


class PlaylistService:
    """Сервис для генерации плейлистов"""
    
    @staticmethod
    def generate_hourly_playlist(db: Session, tariff: VehicleTariff) -> List[int]:
        """
        Генерация плейлиста на 1 час для тарифа
        
        Логика:
        1. Проверить есть ли контрактные видео для данного тарифа
        2. Если есть - заполнить контрактными видео с нужной частотой
        3. Если нет контрактных - заполнить филлерами в разброс (чтобы не повторялись подряд)
        4. Перемешать так, чтобы контрактные видео были равномерно распределены
        """
        
        # Получить все активные контрактные видео для данного тарифа
        contract_videos = db.query(Video).filter(
            Video.is_active == True,
            Video.video_type == VideoType.CONTRACT,
            Video.tariffs.contains(tariff.value)
        ).all()
        
        # Получить все активные филлеры для данного тарифа
        filler_videos = db.query(Video).filter(
            Video.is_active == True,
            Video.video_type == VideoType.FILLER,
            Video.tariffs.contains(tariff.value)
        ).order_by(Video.priority.desc()).all()
        
        # Создать последовательность видео
        playlist_sequence = []
        
        # Фильтруем видео с валидной длительностью
        contract_videos = [v for v in contract_videos if v.duration and v.duration > 0]
        filler_videos = [v for v in filler_videos if v.duration and v.duration > 0]
        
        # Если есть контрактные видео - заполняем ими
        if contract_videos:
            # Добавить контрактные видео с нужной частотой
            for video in contract_videos:
                plays = video.plays_per_hour or 1
                for _ in range(plays):
                    playlist_sequence.append(video.id)
            
            # Рассчитать сколько времени займут контрактные видео
            total_contract_duration = sum(
                video.duration * (video.plays_per_hour or 1) 
                for video in contract_videos
            )
            
            # Заполнить оставшееся время филлерами (примерно до 1 часа = 3600 секунд)
            remaining_time = max(0, 3600 - total_contract_duration)
            playlist_sequence = PlaylistService._fill_with_fillers(
                playlist_sequence, 
                filler_videos, 
                remaining_time
            )
            
            # Перемешать плейлист для равномерного распределения контрактных видео
            playlist_sequence = PlaylistService._distribute_evenly(
                playlist_sequence, 
                [v.id for v in contract_videos]
            )
        else:
            # Если нет контрактных видео - заполнить только филлерами в разброс
            if not filler_videos:
                return []  # Нет видео для плейлиста
            
            # Заполнить час филлерами (3600 секунд)
            playlist_sequence = PlaylistService._fill_with_fillers(
                [], 
                filler_videos, 
                3600,
                shuffle=True  # В разброс, чтобы не повторялись подряд
            )
        
        return playlist_sequence
    
    @staticmethod
    def _fill_with_fillers(
        sequence: List[int], 
        filler_videos: List[Video], 
        remaining_time: float,
        shuffle: bool = False
    ) -> List[int]:
        """
        Заполнить оставшееся время филлерами
        
        Args:
            sequence: Текущая последовательность видео
            filler_videos: Список филлеров
            remaining_time: Оставшееся время в секундах
            shuffle: Перемешивать ли филлеры чтобы не повторялись подряд
        """
        if not filler_videos:
            return sequence
        
        result = sequence.copy()
        max_iterations = 5000  # защита от бесконечного цикла
        
        if shuffle:
            # Перемешиваем филлеры и избегаем повторений подряд
            available_fillers = [v.id for v in filler_videos if (v.duration or 0) > 0]
            if not available_fillers:
                return result
            
            # Создаем список филлеров с их длительностями
            filler_list = [(v.id, v.duration or 0) for v in filler_videos if (v.duration or 0) > 0]
            random.shuffle(filler_list)
            
            last_filler_id = None
            iterations = 0
            
            while remaining_time > 0 and iterations < max_iterations:
                # Выбираем филлер, который не повторяет предыдущий
                for filler_id, duration in filler_list:
                    if filler_id != last_filler_id:
                        result.append(filler_id)
                        remaining_time -= duration
                        last_filler_id = filler_id
                        iterations += 1
                        break
                else:
                    # Если все филлеры одинаковые или только один - просто берем первый
                    filler_id, duration = filler_list[0]
                    result.append(filler_id)
                    remaining_time -= duration
                    last_filler_id = filler_id
                    iterations += 1
                    # Перемешиваем снова для разнообразия
                    random.shuffle(filler_list)
        else:
            # Простое циклическое заполнение
            filler_index = 0
            iterations = 0
            
            while remaining_time > 0 and iterations < max_iterations:
                video = filler_videos[filler_index % len(filler_videos)]
                duration = video.duration or 0
                
                if duration <= 0:
                    filler_index += 1
                    iterations += 1
                    if filler_index >= len(filler_videos):
                        break
                    continue
                
                result.append(video.id)
                remaining_time -= duration
                filler_index += 1
                iterations += 1
        
        return result
    
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
    def create_playlist(
        db: Session, 
        tariff: VehicleTariff, 
        vehicle_id: Optional[int] = None, 
        hours: int = 24
    ) -> Playlist:
        """
        Создать плейлист для тарифа или конкретного автомобиля.
        
        Если vehicle_id=None - создается общий плейлист для тарифа.
        Если vehicle_id указан - создается индивидуальный плейлист для автомобиля.
        
        Генерируется только 1 час контента.
        Период действия — hours (по умолчанию 24). Приложение зацикливает часовой плейлист.
        """
        # Один часовой плейлист — приложение зациклит его
        hourly_sequence = PlaylistService.generate_hourly_playlist(db, tariff)
        
        # Если последовательность пустая, это проблема - логируем предупреждение
        if not hourly_sequence:
            # Попробуем найти любые активные видео для этого тарифа
            all_videos = db.query(Video).filter(
                Video.is_active == True,
                Video.tariffs.contains(tariff.value)
            ).all()
            
            # Если есть видео, но они не попали в плейлист - возможно проблема с длительностью
            if all_videos:
                videos_without_duration = [v for v in all_videos if not v.duration or v.duration <= 0]
                if videos_without_duration:
                    # Есть видео без длительности - это проблема
                    pass  # Можно добавить логирование здесь
        
        now = datetime.utcnow()
        playlist = Playlist(
            vehicle_id=vehicle_id,  # None для плейлиста по тарифу
            tariff=tariff,
            video_sequence=json.dumps(hourly_sequence) if hourly_sequence else json.dumps([]),
            valid_from=now,
            valid_until=now + timedelta(hours=hours)
        )
        
        db.add(playlist)
        db.commit()
        db.refresh(playlist)
        
        return playlist
    
    @staticmethod
    def get_active_playlist(db: Session, tariff: VehicleTariff, vehicle_id: Optional[int] = None) -> Optional[Playlist]:
        """
        Получить активный плейлист для автомобиля или тарифа.
        
        Сначала ищет индивидуальный плейлист для vehicle_id (если указан),
        если не найден - ищет общий плейлист для tariff.
        """
        now = datetime.utcnow()
        
        # Сначала ищем индивидуальный плейлист для автомобиля
        if vehicle_id:
            playlist = db.query(Playlist).filter(
                Playlist.vehicle_id == vehicle_id,
                Playlist.tariff == tariff,
                Playlist.valid_from <= now,
                Playlist.valid_until > now
            ).order_by(Playlist.created_at.desc()).first()
            
            if playlist:
                return playlist
        
        # Если не найден индивидуальный - ищем общий плейлист по тарифу
        playlist = db.query(Playlist).filter(
            Playlist.vehicle_id.is_(None),  # Общий плейлист по тарифу
            Playlist.tariff == tariff,
            Playlist.valid_from <= now,
            Playlist.valid_until > now
        ).order_by(Playlist.created_at.desc()).first()
        
        return playlist
    
    @staticmethod
    def build_playlist_timeline(
        db: Session, 
        playlist: Playlist,
        base_url: Optional[str] = None
    ) -> Tuple[List[Dict], List[Dict]]:
        """
        Построить временную шкалу плейлиста.
        
        Args:
            db: Сессия базы данных
            playlist: Плейлист из БД
            base_url: Базовый URL для медиа файлов (если None, будет использован из настроек)
        
        Returns:
            Tuple[List[Dict], List[Dict]]: 
                - Список контрактных видео с временными метками (группированные по ID с частотой)
                - Список филлеров с длительностью и URL
        """
        # Парсим video_sequence
        try:
            video_sequence = json.loads(playlist.video_sequence)
        except (json.JSONDecodeError, TypeError):
            video_sequence = []
        
        if not video_sequence:
            # Если последовательность пустая, возвращаем пустые списки
            return [], []
        
        # Получить информацию о всех видео
        video_ids = set(video_sequence)
        if not video_ids:
            return [], []
        
        videos = db.query(Video).filter(Video.id.in_(video_ids)).all()
        video_map = {v.id: v for v in videos}
        
        # Проверить, что все видео найдены
        missing_ids = video_ids - set(video_map.keys())
        if missing_ids:
            # Некоторые видео не найдены в БД - пропускаем их
            video_sequence = [vid for vid in video_sequence if vid in video_map]
        
        # Разделить на контрактные и филлеры
        # Важно: проверяем только is_active, но не фильтруем по типу здесь,
        # так как тип уже определен в video_map
        contract_video_ids = {
            vid for vid, video in video_map.items()
            if video.video_type == VideoType.CONTRACT and video.is_active
        }
        
        # Подсчитать частоту повторений контрактных видео
        contract_frequency = Counter(
            vid for vid in video_sequence 
            if vid in contract_video_ids
        )
        
        # Формировать базовый URL для медиа файлов
        if base_url is None:
            base_url = settings.BASE_URL
        if base_url is None:
            # Если BASE_URL не задан, используем относительный путь
            # Клиент сам добавит свой базовый URL
            base_url = ""
        
        # Вычислить временные метки для всех видео в последовательности
        # Проходим по последовательности и вычисляем реальные временные метки
        contract_items_dict: Dict[int, Dict] = {}  # video_id -> {info with first occurrence}
        filler_items_dict: Dict[int, Dict] = {}  # video_id -> {duration, file_path}
        
        current_time = 0.0
        max_time = 3600.0  # 1 час
        
        # Проходим по всей последовательности и вычисляем временные метки
        for video_id in video_sequence:
            video = video_map.get(video_id)
            if not video:
                continue  # Видео не найдено в БД
            
            # Проверяем активность и длительность
            if not video.is_active:
                continue
            
            duration = video.duration or 0
            if duration <= 0:
                continue  # Пропускаем видео без длительности
            
            # Вычисляем временные метки для этого воспроизведения
            end_time = min(current_time + duration, max_time)
            
            if video_id in contract_video_ids:
                # Контрактное видео
                if video_id not in contract_items_dict:
                    # Первое вхождение - сохраняем информацию
                    media_url = f"{base_url}{video.file_path}" if base_url else video.file_path
                    frequency = contract_frequency[video_id]
                    contract_items_dict[video_id] = {
                        'video_id': video_id,
                        'start_time': current_time,  # Время первого воспроизведения
                        'end_time': end_time,
                        'duration': duration,  # Длительность одного воспроизведения
                        'frequency': frequency,  # Количество повторений в плейлисте
                        'file_path': video.file_path,
                        'media_url': media_url,
                    }
                # Для последующих повторений не обновляем start_time,
                # так как показываем только первое воспроизведение с frequency
            else:
                # Филлер - собираем информацию о длительности и пути
                if video_id not in filler_items_dict:
                    media_url = f"{base_url}{video.file_path}" if base_url else video.file_path
                    filler_items_dict[video_id] = {
                        'duration': duration,
                        'file_path': video.file_path,
                        'media_url': media_url,
                    }
            
            # Перемещаем время вперед на длительность этого видео
            current_time = end_time
            
            # Если достигли максимума, прекращаем обработку
            if current_time >= max_time:
                break
        
        # Преобразовать контрактные видео в список
        contract_items = list(contract_items_dict.values())
        
        # Преобразовать филлеры в список
        filler_items = [
            {
                'video_id': vid,
                'duration': info['duration'],
                'file_path': info['file_path'],
                'media_url': info['media_url'],
            }
            for vid, info in filler_items_dict.items()
        ]
        
        return contract_items, filler_items
