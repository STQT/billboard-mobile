#!/usr/bin/env python3
"""
Скрипт для заполнения БД тестовыми данными: автомобили и видео.
Запуск: python seed_test_data.py
"""

from sqlalchemy.orm import Session
from app.db.database import SessionLocal
from app.models.models import Vehicle, Video, VideoType, VehicleTariff
from app.core.security import get_password_hash
import os

def clear_data(db: Session):
    """Очистить тестовые данные"""
    print("🗑️  Очистка старых тестовых данных...")
    db.query(Vehicle).filter(Vehicle.login.startswith("test_")).delete()
    db.query(Video).filter(Video.title.startswith("Тест")).delete()
    db.commit()
    print("✅ Данные очищены")

def seed_vehicles(db: Session):
    """Создать тестовые автомобили"""
    print("🚗 Создание тестовых автомобилей...")
    
    test_vehicles = [
        {
            "login": "test_car_001",
            "password": "test123",
            "car_number": "01T001AA",
            "tariff": VehicleTariff.STANDARD,
            "driver_name": "Тестовый Водитель 1",
            "phone": "+998901234567"
        },
        {
            "login": "test_car_002",
            "password": "test123",
            "car_number": "01T002BB",
            "tariff": VehicleTariff.COMFORT,
            "driver_name": "Тестовый Водитель 2",
            "phone": "+998901234568"
        },
        {
            "login": "test_car_003",
            "password": "test123",
            "car_number": "01T003CC",
            "tariff": VehicleTariff.BUSINESS,
            "driver_name": "Тестовый Водитель 3",
            "phone": "+998901234569"
        },
    ]
    
    created = 0
    for veh_data in test_vehicles:
        existing = db.query(Vehicle).filter(
            (Vehicle.login == veh_data["login"]) | (Vehicle.car_number == veh_data["car_number"])
        ).first()
        
        if not existing:
            vehicle = Vehicle(
                login=veh_data["login"],
                hashed_password=get_password_hash(veh_data["password"]),
                car_number=veh_data["car_number"],
                tariff=veh_data["tariff"],
                driver_name=veh_data["driver_name"],
                phone=veh_data["phone"],
                is_active=True
            )
            db.add(vehicle)
            created += 1
            print(f"  ✅ Создан: {vehicle.car_number} ({vehicle.tariff.value})")
        else:
            print(f"  ℹ️  Уже существует: {existing.car_number}")
    
    db.commit()
    print(f"✅ Автомобилей создано: {created}")
    return created

def seed_videos(db: Session):
    """Создать тестовые видео (без файлов, только записи в БД)"""
    print("🎬 Создание тестовых видео...")
    
    # Создать директорию для uploads если нет
    upload_dir = "./uploads/videos"
    os.makedirs(upload_dir, exist_ok=True)
    
    test_videos = [
        {
            "title": "Тест - Филлер 1",
            "filename": "test_filler_1.mp4",
            "video_type": VideoType.FILLER,
            "duration": 30.0,
            "tariffs": "standard,comfort,business,premium",
            "priority": 1,
        },
        {
            "title": "Тест - Филлер 2",
            "filename": "test_filler_2.mp4",
            "video_type": VideoType.FILLER,
            "duration": 25.0,
            "tariffs": "standard,comfort,business,premium",
            "priority": 1,
        },
        {
            "title": "Тест - Филлер 3",
            "filename": "test_filler_3.mp4",
            "video_type": VideoType.FILLER,
            "duration": 20.0,
            "tariffs": "standard,comfort,business",
            "priority": 1,
        },
        {
            "title": "Тест - Контрактное A",
            "filename": "test_contract_a.mp4",
            "video_type": VideoType.CONTRACT,
            "plays_per_hour": 3,
            "duration": 15.0,
            "tariffs": "standard,comfort,business,premium",
            "priority": 10,
        },
        {
            "title": "Тест - Контрактное B",
            "filename": "test_contract_b.mp4",
            "video_type": VideoType.CONTRACT,
            "plays_per_hour": 2,
            "duration": 20.0,
            "tariffs": "business,premium",
            "priority": 10,
        },
    ]
    
    created = 0
    for vid_data in test_videos:
        existing = db.query(Video).filter(Video.title == vid_data["title"]).first()
        
        if not existing:
            local_path = f"{upload_dir}/{vid_data['filename']}"
            # Создать пустой файл если нет (для теста)
            if not os.path.exists(local_path):
                with open(local_path, 'w') as f:
                    f.write("# Тестовый файл - замените на реальное видео MP4")
            
            # URL путь для клиентов (StaticFiles на /videos)
            client_path = f"/videos/{vid_data['filename']}"
            
            video = Video(
                title=vid_data["title"],
                filename=vid_data["filename"],
                file_path=client_path,  # URL путь
                file_size=os.path.getsize(local_path) if os.path.exists(local_path) else 0,
                duration=vid_data["duration"],
                video_type=vid_data["video_type"],
                plays_per_hour=vid_data.get("plays_per_hour"),
                tariffs=vid_data["tariffs"],
                priority=vid_data["priority"],
                is_active=True
            )
            db.add(video)
            created += 1
            print(f"  ✅ Создано: {video.title} ({video.video_type.value})")
        else:
            print(f"  ℹ️  Уже существует: {existing.title}")
    
    db.commit()
    print(f"✅ Видео создано: {created}")
    return created

def main():
    print("\n" + "="*60)
    print("  Billboard Mobile - Заполнение тестовыми данными")
    print("="*60 + "\n")
    
    db = SessionLocal()
    
    try:
        # Очистка (опционально)
        # clear_data(db)
        
        # Создать автомобили
        veh_count = seed_vehicles(db)
        print()
        
        # Создать видео
        vid_count = seed_videos(db)
        print()
        
        print("="*60)
        print(f"✅ Готово! Создано автомобилей: {veh_count}, видео: {vid_count}")
        print()
        print("Тестовые логины:")
        print("  • test_car_001 / test123  (Standard)")
        print("  • test_car_002 / test123  (Comfort)")
        print("  • test_car_003 / test123  (Business)")
        print()
        print("Проверка плейлиста:")
        print("  python check_playlist.py http://localhost:8000 1")
        print()
        print("Или через curl:")
        print("  curl http://localhost:8000/api/v1/playlists/vehicle/1")
        print("="*60 + "\n")
        
    finally:
        db.close()

if __name__ == "__main__":
    main()
