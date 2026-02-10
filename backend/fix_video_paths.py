#!/usr/bin/env python3
"""
Скрипт для исправления file_path в существующих видео.
Меняет локальные пути (./uploads/videos/...) на URL пути (/videos/...)
"""
import sys
import os

# Добавить корневую директорию в путь для импорта модулей
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app.db.database import SessionLocal
from app.models.models import Video


def fix_video_paths():
    """Обновить file_path для всех видео"""
    print("\n" + "="*60)
    print("  Исправление путей видео")
    print("="*60 + "\n")
    
    db = SessionLocal()
    
    try:
        videos = db.query(Video).all()
        
        if not videos:
            print("❌ Нет видео в БД")
            return 0
        
        updated = 0
        for video in videos:
            old_path = video.file_path
            
            # Если путь уже в формате /videos/, пропустить
            if old_path.startswith("/videos/"):
                continue
            
            # Извлечь filename из старого пути
            # ./uploads/videos/test.mp4 -> test.mp4
            # или uploads/videos/test.mp4 -> test.mp4
            filename = video.filename or os.path.basename(old_path)
            
            # Новый URL путь
            new_path = f"/videos/{filename}"
            
            video.file_path = new_path
            updated += 1
            
            print(f"✅ {video.id}: {video.title}")
            print(f"   Старый путь: {old_path}")
            print(f"   Новый путь:  {new_path}")
        
        if updated > 0:
            db.commit()
            print(f"\n{'='*60}")
            print(f"✅ Обновлено {updated} видео")
            print(f"{'='*60}\n")
        else:
            print("\n✅ Все пути уже актуальны\n")
        
        return updated
        
    except Exception as e:
        print(f"\n❌ Ошибка: {e}\n")
        db.rollback()
        return 0
    finally:
        db.close()


if __name__ == "__main__":
    fix_video_paths()
