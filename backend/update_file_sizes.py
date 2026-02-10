#!/usr/bin/env python3
"""
Обновить file_size для всех видео из реальных размеров файлов
"""
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app.db.database import SessionLocal
from app.models.models import Video
from app.core.config import settings


def update_file_sizes():
    print("\n" + "="*60)
    print("  Обновление размеров файлов")
    print("="*60 + "\n")
    
    db = SessionLocal()
    
    try:
        videos = db.query(Video).all()
        
        if not videos:
            print("❌ Нет видео в БД")
            return 0
        
        updated = 0
        for video in videos:
            # Построить локальный путь из filename
            local_path = os.path.join(settings.UPLOAD_DIR, video.filename)
            
            if not os.path.exists(local_path):
                print(f"⚠️  {video.id}: {video.title}")
                print(f"   Файл не найден: {local_path}")
                continue
            
            real_size = os.path.getsize(local_path)
            
            if real_size == video.file_size:
                continue  # Размер уже правильный
            
            old_size = video.file_size
            video.file_size = real_size
            updated += 1
            
            print(f"✅ {video.id}: {video.title}")
            print(f"   Старый размер: {old_size} байт")
            print(f"   Новый размер:  {real_size} байт ({real_size / 1024:.1f} KB)")
        
        if updated > 0:
            db.commit()
            print(f"\n{'='*60}")
            print(f"✅ Обновлено {updated} видео")
            print(f"{'='*60}\n")
        else:
            print("\n✅ Все размеры уже актуальны\n")
        
        return updated
        
    except Exception as e:
        print(f"\n❌ Ошибка: {e}\n")
        db.rollback()
        return 0
    finally:
        db.close()


if __name__ == "__main__":
    update_file_sizes()
