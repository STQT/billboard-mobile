from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File, Form
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session
from typing import List
from datetime import datetime, timedelta, date
import json
import os
import shutil

from app.db.database import get_db
from app.models.models import Vehicle, Video, Playlist, VehicleTariff, VideoType
from app.schemas.schemas import (
    VehicleCreate, VehicleResponse, VehicleLogin, VehicleUpdate, Token,
    VideoCreate, VideoResponse, VideoUpdate,
    SessionStart, SessionResponse, SessionEnd,
    PlaybackLogCreate, PlaybackLogResponse,
    PlaylistResponse, VehicleAnalytics
)
from app.core.security import verify_password, get_password_hash, create_access_token, decode_access_token
from app.core.config import settings
from app.services.playlist_service import PlaylistService
from app.services.analytics_service import AnalyticsService

router = APIRouter()
security = HTTPBearer()


# ============ AUTH ============

def get_current_vehicle(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db)
) -> Vehicle:
    """Получить текущий автомобиль из токена"""
    token = credentials.credentials
    payload = decode_access_token(token)
    
    if not payload:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication credentials"
        )
    
    vehicle_id = payload.get("sub")
    if not vehicle_id:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")
    
    vehicle = db.query(Vehicle).filter(Vehicle.id == int(vehicle_id)).first()
    if not vehicle:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Vehicle not found")
    
    if not vehicle.is_active:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Vehicle is inactive")
    
    return vehicle


@router.post("/auth/register", response_model=VehicleResponse)
def register_vehicle(vehicle: VehicleCreate, db: Session = Depends(get_db)):
    """Регистрация нового автомобиля"""
    # Проверить существование
    existing = db.query(Vehicle).filter(
        (Vehicle.login == vehicle.login) | (Vehicle.car_number == vehicle.car_number)
    ).first()
    
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Vehicle with this login or car number already exists"
        )
    
    # Создать автомобиль
    new_vehicle = Vehicle(
        login=vehicle.login,
        hashed_password=get_password_hash(vehicle.password),
        car_number=vehicle.car_number,
        tariff=vehicle.tariff,
        driver_name=vehicle.driver_name,
        phone=vehicle.phone
    )
    
    db.add(new_vehicle)
    db.commit()
    db.refresh(new_vehicle)
    
    return new_vehicle


@router.post("/auth/login", response_model=Token)
def login_vehicle(credentials: VehicleLogin, db: Session = Depends(get_db)):
    """Авторизация автомобиля"""
    vehicle = db.query(Vehicle).filter(Vehicle.login == credentials.login).first()
    
    if not vehicle or not verify_password(credentials.password, vehicle.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect login or password"
        )
    
    if not vehicle.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Vehicle is inactive"
        )
    
    # Создать токен
    access_token = create_access_token(data={"sub": str(vehicle.id)})
    
    return {"access_token": access_token, "token_type": "bearer"}


@router.get("/auth/me", response_model=VehicleResponse)
def get_current_vehicle_info(current_vehicle: Vehicle = Depends(get_current_vehicle)):
    """Получить информацию о текущем автомобиле"""
    return current_vehicle


# ============ VEHICLES (Admin) ============

@router.get("/vehicles", response_model=List[VehicleResponse])
def get_all_vehicles(
    skip: int = 0,
    limit: int = 100,
    is_active: bool = None,
    tariff: VehicleTariff = None,
    db: Session = Depends(get_db)
):
    """Получить список всех автомобилей (для админ панели)"""
    query = db.query(Vehicle)
    
    if is_active is not None:
        query = query.filter(Vehicle.is_active == is_active)
    
    if tariff:
        query = query.filter(Vehicle.tariff == tariff)
    
    vehicles = query.offset(skip).limit(limit).all()
    return vehicles


@router.get("/vehicles/{vehicle_id}", response_model=VehicleResponse)
def get_vehicle(vehicle_id: int, db: Session = Depends(get_db)):
    """Получить автомобиль по ID"""
    vehicle = db.query(Vehicle).filter(Vehicle.id == vehicle_id).first()
    if not vehicle:
        raise HTTPException(status_code=404, detail="Vehicle not found")
    return vehicle


@router.put("/vehicles/{vehicle_id}", response_model=VehicleResponse)
def update_vehicle(
    vehicle_id: int,
    vehicle_update: VehicleUpdate,
    db: Session = Depends(get_db)
):
    """Обновить автомобиль"""
    vehicle = db.query(Vehicle).filter(Vehicle.id == vehicle_id).first()
    if not vehicle:
        raise HTTPException(status_code=404, detail="Vehicle not found")
    
    # Проверить уникальность логина и номера (если изменены)
    if vehicle_update.login != vehicle.login or vehicle_update.car_number != vehicle.car_number:
        existing = db.query(Vehicle).filter(
            (Vehicle.login == vehicle_update.login) | (Vehicle.car_number == vehicle_update.car_number)
        ).filter(Vehicle.id != vehicle_id).first()
        
        if existing:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Vehicle with this login or car number already exists"
            )
    
    # Обновить поля
    vehicle.login = vehicle_update.login
    vehicle.car_number = vehicle_update.car_number
    vehicle.tariff = vehicle_update.tariff
    vehicle.driver_name = vehicle_update.driver_name
    vehicle.phone = vehicle_update.phone
    
    # Обновить пароль только если указан новый
    if vehicle_update.password:
        vehicle.hashed_password = get_password_hash(vehicle_update.password)
    
    db.commit()
    db.refresh(vehicle)
    return vehicle


@router.delete("/vehicles/{vehicle_id}")
def delete_vehicle(vehicle_id: int, db: Session = Depends(get_db)):
    """Удалить автомобиль"""
    vehicle = db.query(Vehicle).filter(Vehicle.id == vehicle_id).first()
    if not vehicle:
        raise HTTPException(status_code=404, detail="Vehicle not found")
    
    db.delete(vehicle)
    db.commit()
    return {"message": "Vehicle deleted successfully"}


# ============ VIDEOS ============

@router.post("/videos", response_model=VideoResponse)
async def upload_video(
    title: str = Form(...),
    video_type: VideoType = Form(...),
    tariffs: str = Form(...),  # JSON string: ["standard", "comfort"]
    plays_per_hour: int = Form(None),
    priority: int = Form(0),
    file: UploadFile = File(...),
    db: Session = Depends(get_db)
):
    """Загрузка видео"""
    # Создать директорию если не существует
    os.makedirs(settings.UPLOAD_DIR, exist_ok=True)
    
    # Сохранить файл на диск
    local_file_path = os.path.join(settings.UPLOAD_DIR, file.filename)
    with open(local_file_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
    
    # Получить размер файла
    file_size = os.path.getsize(local_file_path)
    
    # Парсить тарифы
    tariffs_list = json.loads(tariffs)
    tariffs_str = ",".join(tariffs_list)
    
    # Путь для клиента: /videos/filename (StaticFiles монтируется на /videos)
    client_path = f"/videos/{file.filename}"
    
    # Создать запись видео
    video = Video(
        title=title,
        filename=file.filename,
        file_path=client_path,  # URL путь для клиентов
        file_size=file_size,
        video_type=video_type,
        plays_per_hour=plays_per_hour,
        tariffs=tariffs_str,
        priority=priority
    )
    
    db.add(video)
    db.commit()
    db.refresh(video)
    
    return video


@router.get("/videos", response_model=List[VideoResponse])
def get_videos(
    tariff: VehicleTariff = None,
    video_type: VideoType = None,
    is_active: bool = None,
    include_deleted: bool = False,
    db: Session = Depends(get_db)
):
    """
    Получить список видео с фильтрацией.
    
    По умолчанию возвращаются только активные видео (is_active=True).
    Для показа всех (включая удаленные) используйте include_deleted=true.
    """
    query = db.query(Video)
    
    if tariff:
        query = query.filter(Video.tariffs.contains(tariff.value))
    
    if video_type:
        query = query.filter(Video.video_type == video_type)
    
    # Фильтрация по активности
    if not include_deleted:
        # По умолчанию показываем только активные
        if is_active is None:
            query = query.filter(Video.is_active == True)
        else:
            query = query.filter(Video.is_active == is_active)
    elif is_active is not None:
        # Если include_deleted=true и is_active задан явно
        query = query.filter(Video.is_active == is_active)
    
    return query.order_by(Video.created_at.desc()).all()


@router.get("/videos/{video_id}", response_model=VideoResponse)
def get_video(video_id: int, db: Session = Depends(get_db)):
    """Получить видео по ID"""
    video = db.query(Video).filter(Video.id == video_id).first()
    if not video:
        raise HTTPException(status_code=404, detail="Video not found")
    return video


@router.put("/videos/{video_id}", response_model=VideoResponse)
def update_video(video_id: int, video_update: VideoUpdate, db: Session = Depends(get_db)):
    """Обновить видео"""
    video = db.query(Video).filter(Video.id == video_id).first()
    if not video:
        raise HTTPException(status_code=404, detail="Video not found")
    
    update_data = video_update.model_dump(exclude_unset=True)
    
    if 'tariffs' in update_data:
        update_data['tariffs'] = ",".join(update_data['tariffs'])
    
    for key, value in update_data.items():
        setattr(video, key, value)
    
    db.commit()
    db.refresh(video)
    return video


@router.delete("/videos/{video_id}")
def delete_video(video_id: int, db: Session = Depends(get_db)):
    """
    Удалить видео.
    
    Если видео использовалось (есть playback_logs), выполняется soft delete (деактивация).
    Если видео не использовалось, выполняется физическое удаление + удаление файла.
    """
    video = db.query(Video).filter(Video.id == video_id).first()
    if not video:
        raise HTTPException(status_code=404, detail="Video not found")
    
    # Проверить наличие playback_logs
    from app.models.models import PlaybackLog
    has_playback_logs = db.query(PlaybackLog).filter(
        PlaybackLog.video_id == video_id
    ).first() is not None
    
    if has_playback_logs:
        # Soft delete - деактивировать видео (для сохранения аналитики)
        video.is_active = False
        video.title = f"[УДАЛЕНО] {video.title}" if not video.title.startswith("[УДАЛЕНО]") else video.title
        db.commit()
        return {
            "message": "Video deactivated successfully (soft delete)",
            "note": "Video has playback history, so it was deactivated instead of deleted"
        }
    else:
        # Hard delete - физическое удаление видео и файла
        local_path = os.path.join(settings.UPLOAD_DIR, video.filename)
        if os.path.exists(local_path):
            try:
                os.remove(local_path)
            except Exception as e:
                # Не останавливать удаление если файл не удалился
                print(f"Warning: Could not delete file {local_path}: {e}")
        
        db.delete(video)
        db.commit()
        return {"message": "Video deleted successfully (hard delete)"}


# ============ PLAYLISTS ============

@router.get("/playlists/current", response_model=PlaylistResponse)
def get_current_playlist(
    current_vehicle: Vehicle = Depends(get_current_vehicle),
    db: Session = Depends(get_db)
):
    """Получить текущий плейлист для автомобиля"""
    # Ищем сначала индивидуальный плейлист, потом общий по тарифу
    playlist = PlaylistService.get_active_playlist(
        db, 
        current_vehicle.tariff, 
        current_vehicle.id
    )
    
    if not playlist:
        # Создать новый плейлист по тарифу (без vehicle_id)
        playlist = PlaylistService.create_playlist(
            db, 
            current_vehicle.tariff,
            vehicle_id=None,  # Общий плейлист по тарифу
            hours=24
        )
    
    # Парсить video_sequence
    video_sequence = json.loads(playlist.video_sequence)
    
    return PlaylistResponse(
        id=playlist.id,
        vehicle_id=playlist.vehicle_id,
        tariff=playlist.tariff,
        video_sequence=video_sequence,
        valid_from=playlist.valid_from,
        valid_until=playlist.valid_until,
        created_at=playlist.created_at
    )


@router.post("/playlists/regenerate", response_model=PlaylistResponse)
def regenerate_playlist(
    hours: int = 24,
    current_vehicle: Vehicle = Depends(get_current_vehicle),
    db: Session = Depends(get_db)
):
    """Принудительно сгенерировать новый плейлист по тарифу"""
    playlist = PlaylistService.create_playlist(
        db,
        current_vehicle.tariff,
        vehicle_id=None,  # Общий плейлист по тарифу
        hours=hours
    )
    
    video_sequence = json.loads(playlist.video_sequence)
    
    return PlaylistResponse(
        id=playlist.id,
        vehicle_id=playlist.vehicle_id,
        tariff=playlist.tariff,
        video_sequence=video_sequence,
        valid_from=playlist.valid_from,
        valid_until=playlist.valid_until,
        created_at=playlist.created_at
    )


# ============ PLAYLISTS (Admin — без авторизации) ============

@router.get("/playlists/vehicle/{vehicle_id}", response_model=PlaylistResponse)
def get_playlist_by_vehicle(vehicle_id: int, db: Session = Depends(get_db)):
    """Получить текущий плейлист автомобиля (для админ панели)"""
    vehicle = db.query(Vehicle).filter(Vehicle.id == vehicle_id).first()
    if not vehicle:
        raise HTTPException(status_code=404, detail="Vehicle not found")
    
    # Ищем сначала индивидуальный плейлист, потом общий по тарифу
    playlist = PlaylistService.get_active_playlist(
        db, 
        vehicle.tariff, 
        vehicle_id
    )
    
    if not playlist:
        # Создать новый плейлист по тарифу (без vehicle_id)
        playlist = PlaylistService.create_playlist(
            db, 
            vehicle.tariff,
            vehicle_id=None,  # Общий плейлист по тарифу
            hours=24
        )
    
    video_sequence = json.loads(playlist.video_sequence)
    return PlaylistResponse(
        id=playlist.id,
        vehicle_id=playlist.vehicle_id,
        tariff=playlist.tariff,
        video_sequence=video_sequence,
        valid_from=playlist.valid_from,
        valid_until=playlist.valid_until,
        created_at=playlist.created_at
    )


@router.post("/playlists/vehicle/{vehicle_id}/regenerate", response_model=PlaylistResponse)
def admin_regenerate_playlist(
    vehicle_id: int,
    hours: int = 24,
    db: Session = Depends(get_db)
):
    """Сгенерировать новый плейлист по тарифу (для админ панели)"""
    vehicle = db.query(Vehicle).filter(Vehicle.id == vehicle_id).first()
    if not vehicle:
        raise HTTPException(status_code=404, detail="Vehicle not found")
    
    # Создаем общий плейлист по тарифу
    playlist = PlaylistService.create_playlist(
        db, 
        vehicle.tariff,
        vehicle_id=None,  # Общий плейлист по тарифу
        hours=hours
    )
    video_sequence = json.loads(playlist.video_sequence)
    return PlaylistResponse(
        id=playlist.id,
        vehicle_id=playlist.vehicle_id,
        tariff=playlist.tariff,
        video_sequence=video_sequence,
        valid_from=playlist.valid_from,
        valid_until=playlist.valid_until,
        created_at=playlist.created_at
    )


@router.get("/playlists/tariff/{tariff}", response_model=PlaylistResponse)
def get_playlist_by_tariff(tariff: VehicleTariff, db: Session = Depends(get_db)):
    """Получить текущий плейлист по тарифу (для админ панели)"""
    # Ищем общий плейлист по тарифу
    playlist = PlaylistService.get_active_playlist(
        db, 
        tariff, 
        vehicle_id=None
    )
    
    if not playlist:
        # Создать новый плейлист по тарифу
        playlist = PlaylistService.create_playlist(
            db, 
            tariff,
            vehicle_id=None,  # Общий плейлист по тарифу
            hours=24
        )
    
    video_sequence = json.loads(playlist.video_sequence)
    return PlaylistResponse(
        id=playlist.id,
        vehicle_id=playlist.vehicle_id,
        tariff=playlist.tariff,
        video_sequence=video_sequence,
        valid_from=playlist.valid_from,
        valid_until=playlist.valid_until,
        created_at=playlist.created_at
    )


@router.post("/playlists/tariff/{tariff}/regenerate", response_model=PlaylistResponse)
def admin_regenerate_playlist_by_tariff(
    tariff: VehicleTariff,
    hours: int = 24,
    db: Session = Depends(get_db)
):
    """Сгенерировать новый плейлист по тарифу (для админ панели)"""
    # Создаем общий плейлист по тарифу
    playlist = PlaylistService.create_playlist(
        db, 
        tariff,
        vehicle_id=None,  # Общий плейлист по тарифу
        hours=hours
    )
    video_sequence = json.loads(playlist.video_sequence)
    return PlaylistResponse(
        id=playlist.id,
        vehicle_id=playlist.vehicle_id,
        tariff=playlist.tariff,
        video_sequence=video_sequence,
        valid_from=playlist.valid_from,
        valid_until=playlist.valid_until,
        created_at=playlist.created_at
    )


# ============ SESSIONS ============

@router.post("/sessions/start", response_model=SessionResponse)
def start_session(
    current_vehicle: Vehicle = Depends(get_current_vehicle),
    db: Session = Depends(get_db)
):
    """Начать сессию работы"""
    session = AnalyticsService.start_session(db, current_vehicle.id)
    return session


@router.post("/sessions/end", response_model=SessionResponse)
def end_session(
    session_id: int,
    current_vehicle: Vehicle = Depends(get_current_vehicle),
    db: Session = Depends(get_db)
):
    """Завершить сессию работы"""
    session = AnalyticsService.end_session(db, session_id)
    return session


# ============ PLAYBACK LOGS ============

@router.post("/playback", response_model=PlaybackLogResponse)
def log_playback(
    log_data: PlaybackLogCreate,
    session_id: int = None,
    current_vehicle: Vehicle = Depends(get_current_vehicle),
    db: Session = Depends(get_db)
):
    """Записать лог воспроизведения видео"""
    log = AnalyticsService.log_playback(
        db,
        vehicle_id=current_vehicle.id,
        video_id=log_data.video_id,
        duration_seconds=log_data.duration_seconds,
        session_id=session_id,
        completed=log_data.completed
    )
    return log


# ============ ANALYTICS ============

@router.get("/analytics/me", response_model=VehicleAnalytics)
def get_my_analytics(
    start_date: date = None,
    end_date: date = None,
    current_vehicle: Vehicle = Depends(get_current_vehicle),
    db: Session = Depends(get_db)
):
    """Получить аналитику для текущего автомобиля"""
    if not start_date:
        start_date = date.today() - timedelta(days=30)
    
    if not end_date:
        end_date = date.today()
    
    analytics = AnalyticsService.get_vehicle_analytics(
        db,
        current_vehicle.id,
        start_date,
        end_date
    )
    
    return analytics


@router.get("/analytics/vehicle/{vehicle_id}", response_model=VehicleAnalytics)
def get_vehicle_analytics_by_id(
    vehicle_id: int,
    start_date: date = None,
    end_date: date = None,
    db: Session = Depends(get_db)
):
    """Получить аналитику для конкретного автомобиля (для админов)"""
    if not start_date:
        start_date = date.today() - timedelta(days=30)
    
    if not end_date:
        end_date = date.today()
    
    analytics = AnalyticsService.get_vehicle_analytics(
        db,
        vehicle_id,
        start_date,
        end_date
    )
    
    return analytics
