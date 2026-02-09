# Примеры использования API

## Аутентификация

### Регистрация нового автомобиля

```bash
curl -X POST http://localhost:8000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "login": "car001",
    "password": "password123",
    "car_number": "01A001AA",
    "tariff": "standard",
    "driver_name": "Иван Иванов",
    "phone": "+998901234567"
  }'
```

**Ответ:**
```json
{
  "id": 1,
  "login": "car001",
  "car_number": "01A001AA",
  "tariff": "standard",
  "driver_name": "Иван Иванов",
  "phone": "+998901234567",
  "is_active": true,
  "created_at": "2026-02-09T10:00:00Z"
}
```

### Авторизация

```bash
curl -X POST http://localhost:8000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "login": "car001",
    "password": "password123"
  }'
```

**Ответ:**
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer"
}
```

### Получить информацию о текущем автомобиле

```bash
curl -X GET http://localhost:8000/api/v1/auth/me \
  -H "Authorization: Bearer YOUR_TOKEN"
```

## Управление видео

### Загрузить видео (Филлер)

```bash
curl -X POST http://localhost:8000/api/v1/videos \
  -F "title=Реклама продукта A" \
  -F "video_type=filler" \
  -F 'tariffs=["standard","comfort","business"]' \
  -F "priority=1" \
  -F "file=@/path/to/video.mp4"
```

### Загрузить контрактное видео (3 показа в час)

```bash
curl -X POST http://localhost:8000/api/v1/videos \
  -F "title=Контрактная реклама компании X" \
  -F "video_type=contract" \
  -F "plays_per_hour=3" \
  -F 'tariffs=["business","premium"]' \
  -F "priority=10" \
  -F "file=@/path/to/contract_video.mp4"
```

### Получить список всех видео

```bash
curl -X GET http://localhost:8000/api/v1/videos
```

### Фильтр видео по тарифу

```bash
curl -X GET "http://localhost:8000/api/v1/videos?tariff=business&video_type=contract"
```

### Обновить видео

```bash
curl -X PUT http://localhost:8000/api/v1/videos/1 \
  -H "Content-Type: application/json" \
  -d '{
    "plays_per_hour": 5,
    "priority": 15,
    "is_active": true
  }'
```

### Удалить видео

```bash
curl -X DELETE http://localhost:8000/api/v1/videos/1
```

## Плейлисты

### Получить текущий плейлист

```bash
curl -X GET http://localhost:8000/api/v1/playlists/current \
  -H "Authorization: Bearer YOUR_TOKEN"
```

**Ответ:**
```json
{
  "id": 1,
  "vehicle_id": 1,
  "tariff": "standard",
  "video_sequence": [1, 5, 3, 2, 1, 4, 5, 3, ...],
  "valid_from": "2026-02-09T00:00:00Z",
  "valid_until": "2026-02-10T00:00:00Z",
  "created_at": "2026-02-09T00:00:00Z"
}
```

### Принудительно сгенерировать новый плейлист

```bash
curl -X POST "http://localhost:8000/api/v1/playlists/regenerate?hours=24" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

## Сессии работы

### Начать сессию

```bash
curl -X POST http://localhost:8000/api/v1/sessions/start \
  -H "Authorization: Bearer YOUR_TOKEN"
```

**Ответ:**
```json
{
  "id": 1,
  "vehicle_id": 1,
  "start_time": "2026-02-09T08:00:00Z",
  "end_time": null,
  "total_duration_seconds": 0,
  "videos_played": 0
}
```

### Завершить сессию

```bash
curl -X POST "http://localhost:8000/api/v1/sessions/end?session_id=1" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

**Ответ:**
```json
{
  "id": 1,
  "vehicle_id": 1,
  "start_time": "2026-02-09T08:00:00Z",
  "end_time": "2026-02-09T16:00:00Z",
  "total_duration_seconds": 28800,
  "videos_played": 145
}
```

## Логирование воспроизведения

### Записать воспроизведение видео

```bash
curl -X POST "http://localhost:8000/api/v1/playback?session_id=1" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "video_id": 1,
    "duration_seconds": 30.5,
    "completed": true
  }'
```

**Ответ:**
```json
{
  "id": 1,
  "vehicle_id": 1,
  "video_id": 1,
  "played_at": "2026-02-09T08:05:30Z",
  "duration_seconds": 30.5,
  "is_prime_time": false,
  "completed": true
}
```

## Аналитика

### Получить аналитику за последние 30 дней

```bash
curl -X GET http://localhost:8000/api/v1/analytics/me \
  -H "Authorization: Bearer YOUR_TOKEN"
```

**Ответ:**
```json
{
  "vehicle_id": 1,
  "car_number": "01A001AA",
  "daily_stats": [
    {
      "date": "2026-02-09",
      "total_duration_seconds": 28800,
      "videos_played": 145,
      "prime_time_duration_seconds": 10800,
      "earnings": 4320000.0
    }
  ],
  "video_stats": [
    {
      "video_id": 1,
      "video_title": "Реклама продукта A",
      "play_count": 25,
      "total_duration": 625.0
    }
  ],
  "total_earnings": 4320000.0
}
```

### Получить аналитику за конкретный период

```bash
curl -X GET "http://localhost:8000/api/v1/analytics/me?start_date=2026-02-01&end_date=2026-02-09" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

### Получить аналитику для конкретного автомобиля (админ)

```bash
curl -X GET "http://localhost:8000/api/v1/analytics/vehicle/1?start_date=2026-02-01&end_date=2026-02-09"
```

## Полный пример работы

### 1. Регистрация и авторизация

```bash
# Регистрация
curl -X POST http://localhost:8000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "login": "taxi123",
    "password": "secure_pass",
    "car_number": "01B123BB",
    "tariff": "comfort"
  }'

# Авторизация
TOKEN=$(curl -X POST http://localhost:8000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "login": "taxi123",
    "password": "secure_pass"
  }' | jq -r '.access_token')

echo "Token: $TOKEN"
```

### 2. Начать рабочую смену

```bash
# Начать сессию
SESSION_ID=$(curl -X POST http://localhost:8000/api/v1/sessions/start \
  -H "Authorization: Bearer $TOKEN" | jq -r '.id')

echo "Session ID: $SESSION_ID"
```

### 3. Получить плейлист и воспроизвести видео

```bash
# Получить плейлист
PLAYLIST=$(curl -X GET http://localhost:8000/api/v1/playlists/current \
  -H "Authorization: Bearer $TOKEN")

echo "Playlist: $PLAYLIST"

# Записать воспроизведение первого видео
curl -X POST "http://localhost:8000/api/v1/playback?session_id=$SESSION_ID" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "video_id": 1,
    "duration_seconds": 30,
    "completed": true
  }'
```

### 4. Завершить смену

```bash
# Завершить сессию
curl -X POST "http://localhost:8000/api/v1/sessions/end?session_id=$SESSION_ID" \
  -H "Authorization: Bearer $TOKEN"
```

### 5. Посмотреть статистику

```bash
# Получить аналитику
curl -X GET http://localhost:8000/api/v1/analytics/me \
  -H "Authorization: Bearer $TOKEN" | jq
```

## Тестовые данные

### Скрипт для создания тестовых данных

```bash
#!/bin/bash

BASE_URL="http://localhost:8000/api/v1"

# Создать несколько автомобилей
for i in {1..5}; do
  curl -X POST $BASE_URL/auth/register \
    -H "Content-Type: application/json" \
    -d "{
      \"login\": \"car00$i\",
      \"password\": \"password123\",
      \"car_number\": \"01A00${i}AA\",
      \"tariff\": \"standard\",
      \"driver_name\": \"Водитель $i\"
    }"
  echo ""
done

# Создать тестовые видео (требуются реальные видеофайлы)
# curl -X POST $BASE_URL/videos \
#   -F "title=Тестовое видео 1" \
#   -F "video_type=filler" \
#   -F 'tariffs=["standard","comfort"]' \
#   -F "file=@./test_video_1.mp4"
```

## Мониторинг

### Проверка здоровья системы

```bash
curl http://localhost:8000/health
```

### Просмотр API документации

Открыть в браузере: http://localhost:8000/docs

## Примечания

- Все времена в UTC
- Токены действительны 30 дней
- Праймтайм: 18:00-22:00 (UTC) с множителем 1.5x
- Размер видео ограничен 500 МБ по умолчанию
- Видео доступны по пути: `http://localhost:8000/videos/{filename}`
