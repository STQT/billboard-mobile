# Инструкция по установке и запуску

## Требования

### Backend
- Python 3.11+
- PostgreSQL 15+
- Redis 7+

### Mobile
- Flutter 3.0+
- Android Studio / Xcode

## Установка Backend

### 1. Клонировать репозиторий и перейти в директорию backend

```bash
cd billboard-mobile/backend
```

### 2. Создать виртуальное окружение

```bash
python -m venv venv
source venv/bin/activate  # Linux/Mac
# или
venv\Scripts\activate  # Windows
```

### 3. Установить зависимости

```bash
pip install -r requirements.txt
```

### 4. Настроить переменные окружения

Скопировать `.env.example` в `.env` и настроить:

```bash
cp .env.example .env
```

Редактировать `.env`:
```env
DATABASE_URL=postgresql://billboard_user:billboard_pass@localhost:5432/billboard_db
REDIS_URL=redis://localhost:6379/0
SECRET_KEY=your-super-secret-key-change-this
```

### 5. Запустить базу данных через Docker (рекомендуется)

```bash
docker-compose up -d postgres redis
```

Или установить PostgreSQL и Redis локально.

### 6. Создать базу данных

```bash
# Подключиться к PostgreSQL
psql -U postgres

# Создать пользователя и базу
CREATE USER billboard_user WITH PASSWORD 'billboard_pass';
CREATE DATABASE billboard_db OWNER billboard_user;
GRANT ALL PRIVILEGES ON DATABASE billboard_db TO billboard_user;
\q
```

### 7. Запустить сервер

```bash
python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Или через Docker:

```bash
docker-compose up -d
```

### 8. Проверить работу

Открыть в браузере:
- API документация: http://localhost:8000/docs
- Health check: http://localhost:8000/health

## Установка Mobile приложения

### 1. Перейти в директорию mobile

```bash
cd billboard-mobile/mobile
```

### 2. Установить зависимости Flutter

```bash
flutter pub get
```

### 3. Настроить API URL

Открыть `lib/services/api_service.dart` и изменить `baseUrl`:

```dart
static const String baseUrl = 'http://YOUR_SERVER_IP:8000/api/v1';
```

Для локальной разработки:
- Android эмулятор: `http://10.0.2.2:8000/api/v1`
- iOS симулятор: `http://localhost:8000/api/v1`
- Реальное устройство: `http://YOUR_LOCAL_IP:8000/api/v1`

### 4. Запустить приложение

```bash
flutter run
```

Или для конкретной платформы:

```bash
flutter run -d android
flutter run -d ios
```

## Первоначальная настройка

### 1. Создать тестового пользователя (автомобиль)

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

### 2. Загрузить тестовое видео

```bash
curl -X POST http://localhost:8000/api/v1/videos \
  -F "title=Тестовое видео" \
  -F "video_type=filler" \
  -F "tariffs=[\"standard\",\"comfort\",\"business\"]" \
  -F "priority=1" \
  -F "file=@/path/to/video.mp4"
```

### 3. Войти в мобильное приложение

- Логин: `car001`
- Пароль: `password123`

## Разработка

### Backend

Запуск с автоперезагрузкой:

```bash
uvicorn app.main:app --reload
```

Тесты (если будут созданы):

```bash
pytest
```

### Mobile

Горячая перезагрузка:

```bash
flutter run --hot
```

Сборка APK:

```bash
flutter build apk --release
```

Сборка iOS:

```bash
flutter build ios --release
```

## Производственное развертывание

### Backend

1. Настроить `.env` с реальными значениями
2. Изменить `SECRET_KEY` на случайную строку
3. Настроить HTTPS (nginx + certbot)
4. Использовать production-ready БД (настроенный PostgreSQL)
5. Настроить бэкапы БД
6. Использовать gunicorn вместо uvicorn:

```bash
gunicorn app.main:app -w 4 -k uvicorn.workers.UvicornWorker
```

### Mobile

1. Изменить `baseUrl` на production URL
2. Создать release build
3. Подписать приложение
4. Опубликовать в Google Play Store

## Структура API

### Endpoints

**Auth:**
- `POST /api/v1/auth/register` - Регистрация автомобиля
- `POST /api/v1/auth/login` - Авторизация
- `GET /api/v1/auth/me` - Информация о текущем автомобиле

**Videos:**
- `GET /api/v1/videos` - Список видео
- `POST /api/v1/videos` - Загрузка видео
- `GET /api/v1/videos/{id}` - Получить видео
- `PUT /api/v1/videos/{id}` - Обновить видео
- `DELETE /api/v1/videos/{id}` - Удалить видео

**Playlists:**
- `GET /api/v1/playlists/current` - Текущий плейлист
- `POST /api/v1/playlists/regenerate` - Сгенерировать новый плейлист

**Sessions:**
- `POST /api/v1/sessions/start` - Начать сессию
- `POST /api/v1/sessions/end` - Завершить сессию

**Playback:**
- `POST /api/v1/playback` - Записать лог воспроизведения

**Analytics:**
- `GET /api/v1/analytics/me` - Аналитика текущего автомобиля
- `GET /api/v1/analytics/vehicle/{id}` - Аналитика конкретного автомобиля

## Troubleshooting

### Backend не запускается

- Проверить что PostgreSQL и Redis запущены
- Проверить правильность `DATABASE_URL` и `REDIS_URL`
- Проверить права доступа к БД

### Mobile не подключается к API

- Проверить `baseUrl` в `api_service.dart`
- Убедиться что backend запущен
- Проверить firewall/network правила
- Для Android эмулятора использовать `10.0.2.2` вместо `localhost`

### Видео не воспроизводятся

- Проверить формат видео (рекомендуется MP4/H264)
- Убедиться что файлы доступны по пути `/videos/`
- Проверить права доступа к директории `uploads/`

## Поддержка

Если возникли вопросы или проблемы, создайте issue в репозитории.
