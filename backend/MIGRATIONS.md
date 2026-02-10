# Миграции базы данных

Этот проект использует [Alembic](https://alembic.sqlalchemy.org/) для управления миграциями базы данных, аналогично Django migrations.

## Структура

- `alembic/` - директория с конфигурацией Alembic
- `alembic/versions/` - директория с файлами миграций
- `alembic.ini` - конфигурационный файл Alembic
- `alembic/env.py` - настройки окружения для миграций

## Основные команды

### Применение миграций через Docker

```bash
# Применить все миграции
docker-compose exec backend alembic upgrade head

# Откатить последнюю миграцию
docker-compose exec backend alembic downgrade -1

# Откатить все миграции
docker-compose exec backend alembic downgrade base

# Показать текущую версию
docker-compose exec backend alembic current

# Показать историю миграций
docker-compose exec backend alembic history

# Показать какие миграции будут применены
docker-compose exec backend alembic upgrade head --sql
```

### Создание новых миграций

```bash
# Автоматическое создание миграции на основе изменений в моделях
docker-compose exec backend alembic revision --autogenerate -m "описание изменений"

# Создание пустой миграции (для ручных изменений)
docker-compose exec backend alembic revision -m "описание изменений"
```

## Применение миграций при старте контейнера

Миграции можно автоматически применять при старте backend контейнера. 
Для этого добавьте в `docker-compose.yml` в секцию `command`:

```yaml
command: >
  sh -c "
  alembic upgrade head &&
  if [ \"$${DEBUG:-true}\" = \"true\" ]; then
    uvicorn app.main:app --host $${HOST} --port $${PORT} --reload
  else
    uvicorn app.main:app --host $${HOST} --port $${PORT}
  fi
  "
```

## История миграций

### 001 - make playlist vehicle_id nullable
- Дата: 2025-02-10
- Изменения:
  - Сделал `vehicle_id` nullable в таблице `playlists` для поддержки плейлистов по тарифу
  - Добавил индекс на `tariff` для быстрого поиска
