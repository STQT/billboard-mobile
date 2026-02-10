#!/usr/bin/env python3
"""
Скрипт для удаления всех таблиц из базы данных.
Используйте если нужно сбросить структуру БД без удаления volume.
"""
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app.db.database import engine, Base
from app.models.models import Vehicle, Video, VehicleSession, PlaybackLog, Playlist


def drop_all_tables():
    """Удалить все таблицы"""
    print("\n" + "="*60)
    print("  Удаление всех таблиц из базы данных")
    print("="*60 + "\n")
    
    confirm = input("⚠️  Это удалит ВСЕ таблицы и данные! Продолжить? (yes/N): ")
    if confirm.lower() != 'yes':
        print("Отменено.")
        return
    
    try:
        print("\n🗑️  Удаление таблиц...")
        Base.metadata.drop_all(bind=engine)
        print("✅ Все таблицы удалены")
        
        print("\n📝 Для пересоздания таблиц запустите backend или выполните:")
        print("   docker compose exec backend python -c 'from app.db.database import Base, engine; Base.metadata.create_all(bind=engine)'")
        
    except Exception as e:
        print(f"\n❌ Ошибка: {e}")


def recreate_tables():
    """Удалить и создать таблицы заново"""
    print("\n" + "="*60)
    print("  Пересоздание таблиц базы данных")
    print("="*60 + "\n")
    
    confirm = input("⚠️  Это удалит ВСЕ данные и пересоздаст таблицы! Продолжить? (yes/N): ")
    if confirm.lower() != 'yes':
        print("Отменено.")
        return
    
    try:
        print("\n🗑️  Удаление таблиц...")
        Base.metadata.drop_all(bind=engine)
        print("✅ Таблицы удалены")
        
        print("\n🔨 Создание таблиц...")
        Base.metadata.create_all(bind=engine)
        print("✅ Таблицы созданы")
        
        print("\n" + "="*60)
        print("✅ База данных пересоздана!")
        print("="*60)
        print("\n📝 Теперь можно заполнить тестовыми данными:")
        print("   docker compose exec backend python seed_test_data.py")
        
    except Exception as e:
        print(f"\n❌ Ошибка: {e}")


if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description='Управление таблицами базы данных')
    parser.add_argument(
        'action',
        choices=['drop', 'recreate'],
        help='drop - удалить таблицы, recreate - удалить и создать заново'
    )
    
    args = parser.parse_args()
    
    if args.action == 'drop':
        drop_all_tables()
    elif args.action == 'recreate':
        recreate_tables()
