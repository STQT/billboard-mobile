# 🚕 Billboard Mobile - Система цифровой рекламы в такси

<div align="center">

**Современное решение для управления и воспроизведения видеорекламы в такси**

[![FastAPI](https://img.shields.io/badge/FastAPI-0.109.0-009688?style=flat&logo=fastapi)](https://fastapi.tiangolo.com/)
[![Flutter](https://img.shields.io/badge/Flutter-3.0+-02569B?style=flat&logo=flutter)](https://flutter.dev/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-15-336791?style=flat&logo=postgresql)](https://www.postgresql.org/)
[![Python](https://img.shields.io/badge/Python-3.11+-3776AB?style=flat&logo=python)](https://www.python.org/)

</div>

---

## 📋 Описание проекта

**Billboard Mobile** - это комплексная система для управления видеорекламой в автомобилях такси с детальной аналитикой и монетизацией для водителей.

### ✨ Ключевые возможности

🎬 **Типы видео контента**
- **Филлеры** - заполняющие видео, показываются по умолчанию
- **Контрактные** - рекламные видео с гарантированным количеством показов в час

🚗 **Тарифы автомобилей**
- Стандарт, Комфорт, Бизнес, Премиум
- Гибкая настройка показа видео по тарифам

📊 **Детальная аналитика**
- Время работы каждого автомобиля
- Количество воспроизведений каждого видео
- Статистика по дням и видео

💰 **Монетизация**
- Базовая ставка: 100 сум/секунда
- Праймтайм бонус (18:00-22:00): 1.5x
- Автоматический подсчет заработка

## Структура проекта

```
billboard-mobile/
├── backend/                 # FastAPI бэкенд
│   ├── app/
│   │   ├── api/            # API endpoints
│   │   ├── core/           # Конфигурация и утилиты
│   │   ├── models/         # SQLAlchemy модели
│   │   ├── schemas/        # Pydantic схемы
│   │   ├── services/       # Бизнес-логика
│   │   └── db/             # База данных
│   ├── requirements.txt
│   └── docker-compose.yml
│
└── mobile/                  # Flutter приложение
    ├── lib/
    │   ├── models/         # Data модели
    │   ├── services/       # API & бизнес-логика
    │   ├── screens/        # UI экраны
    │   ├── widgets/        # Переиспользуемые виджеты
    │   └── main.dart
    └── pubspec.yaml
```

## Основные функции

### Бэкенд
- ✅ Управление видео контентом (upload, delete, update)
- ✅ Генерация плейлистов по тарифам и временным слотам
- ✅ Учет частоты показов контрактных видео (показов/час)
- ✅ Аутентификация автомобилей (login/password для каждой машины)
- ✅ Детальная аналитика: время работы, количество воспроизведений
- ✅ Праймтайм логика (18:00-22:00)

### Mobile приложение
- ✅ Видео плеер с автоматическим воспроизведением
- ✅ Offline кеширование видео
- ✅ Автоматическая синхронизация плейлистов
- ✅ Отправка аналитики воспроизведения
- ✅ Приложение для водителей с личной статистикой

## Технологии

### Backend
- **FastAPI** - современный Python веб-фреймворк
- **PostgreSQL** - основная база данных
- **Redis** - кеширование плейлистов
- **SQLAlchemy** - ORM
- **Alembic** - миграции БД
- **JWT** - аутентификация

### Mobile
- **Flutter** - кроссплатформенная разработка
- **video_player** - воспроизведение видео
- **dio** - HTTP клиент
- **hive** - локальное хранилище
- **flutter_cache_manager** - кеширование видео

## Установка и запуск

### Backend
```bash
cd backend
python -m venv venv
source venv/bin/activate  # или venv\Scripts\activate на Windows
pip install -r requirements.txt
uvicorn app.main:app --reload
```

### Mobile
```bash
cd mobile
flutter pub get
flutter run
```

## API Документация

После запуска бэкенда доступна по адресу:
- Swagger UI: `http://localhost:8000/docs`
- ReDoc: `http://localhost:8000/redoc`

## База данных

### Основные таблицы:
- `videos` - видео контент
- `vehicles` - автомобили (пользователи)
- `playlists` - сгенерированные плейлисты
- `playback_logs` - логи воспроизведения
- `vehicle_sessions` - сессии работы автомобилей

## Монетизация

Система поддерживает:
- Подсчет времени воспроизведения
- Повышенные коэффициенты в праймтайм (18:00-22:00)
- Детальная статистика для каждого водителя

## 🎯 Быстрый старт

### Минимальная установка (5 минут)

```bash
# 1. Backend
cd backend
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
docker-compose up -d postgres redis
uvicorn app.main:app --reload

# 2. Mobile
cd mobile
flutter pub get
flutter run

# 3. Admin Panel
cd admin-panel
npm install
npm run dev
```

Подробная инструкция: [QUICKSTART.md](QUICKSTART.md)

## 🧪 Тестирование

```bash
# Автоматическое тестирование API
python backend/test_api.py
```

## 📚 Документация

| Файл | Описание |
|------|----------|
| [QUICKSTART.md](QUICKSTART.md) | Быстрая установка за 5 минут |
| [SETUP.md](SETUP.md) | Детальная инструкция по установке |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Архитектура системы |
| [API_EXAMPLES.md](API_EXAMPLES.md) | Примеры использования API |
| [PROJECT_SUMMARY.md](PROJECT_SUMMARY.md) | Краткое резюме проекта |
| [STRUCTURE.txt](STRUCTURE.txt) | Структура файлов проекта |

## 🚀 Статус проекта

### Реализовано ✅
- [x] Backend API (FastAPI)
- [x] База данных (PostgreSQL + Redis)
- [x] JWT аутентификация
- [x] Управление видео (CRUD)
- [x] Умная генерация плейлистов
- [x] Детальная аналитика
- [x] Расчет заработка с праймтаймом
- [x] Flutter mobile приложение
- [x] Video player с автоматическим воспроизведением
- [x] Offline кеширование видео
- [x] Отправка аналитики
- [x] Docker поддержка
- [x] Полная документация

- [x] Web админ панель (React + Material-UI)

### В разработке 🔄
- [ ] Приложение для водителей с личным кабинетом
- [ ] Платежные интеграции
- [ ] Machine Learning для оптимизации плейлистов
- [ ] Расширенная аналитика с графиками

## 👥 Использование

### Для администраторов

1. **Загрузка видео** - через API или будущую админ панель
2. **Регистрация автомобилей** - создание логинов для каждого авто
3. **Настройка тарифов** - привязка видео к типам автомобилей
4. **Просмотр аналитики** - статистика по всем автомобилям

### Для водителей

1. **Авторизация** - вход по логину/паролю
2. **Автоматическое воспроизведение** - плейлист генерируется автоматически
3. **Просмотр статистики** - сколько видео показано, сколько заработано
4. **Праймтайм бонусы** - повышенная оплата в часы пик

## 🏗️ Архитектура

```
┌─────────────────────────────────────┐
│   Flutter Mobile App (Android)      │
│   - Video Player                    │
│   - Offline Cache                   │
│   - Analytics                       │
└─────────────┬───────────────────────┘
              │ REST API (JWT)
┌─────────────▼───────────────────────┐
│   FastAPI Backend                   │
│   - Auth & Users                    │
│   - Video Management                │
│   - Playlist Generation             │
│   - Analytics Service               │
└─────────────┬───────────────────────┘
              │
    ┌─────────┴─────────┐
    │                   │
┌───▼──────┐   ┌────────▼─────┐
│PostgreSQL│   │ Redis Cache  │
│   DB     │   │              │
└──────────┘   └──────────────┘
```

## 🔐 Безопасность

- JWT токены для аутентификации
- Bcrypt хеширование паролей
- Защищенные API endpoints
- Валидация данных через Pydantic
- CORS настройки

## 🌟 Особенности

### Умная генерация плейлистов

Алгоритм автоматически:
1. Получает контрактные видео с заданной частотой показов
2. Заполняет оставшееся время филлерами
3. Равномерно распределяет контрактные видео по времени
4. Генерирует плейлист на 24 часа

### Offline работа

- Автоматическое кеширование видео
- Работа без интернета
- Синхронизация аналитики при подключении

### Детальная аналитика

- Время работы по дням
- Количество показов каждого видео
- Заработок с учетом праймтайма
- Статистика по автомобилям

## 🛠️ Разработка

### Технологический стек

**Backend:**
- FastAPI - веб-фреймворк
- PostgreSQL - база данных
- Redis - кеширование
- SQLAlchemy - ORM
- Alembic - миграции
- Pydantic - валидация

**Mobile:**
- Flutter - фреймворк
- video_player - воспроизведение
- dio - HTTP клиент
- hive - локальная БД
- provider - state management
- flutter_cache_manager - кеширование

### Структура проекта

```
billboard-mobile/
├── backend/           # FastAPI Backend
│   ├── app/
│   │   ├── api/      # API endpoints
│   │   ├── models/   # Database models
│   │   ├── services/ # Business logic
│   │   └── ...
│   └── ...
├── mobile/           # Flutter App
│   └── lib/
│       ├── models/   # Data models
│       ├── services/ # API & logic
│       ├── screens/  # UI screens
│       └── ...
└── admin-panel/      # React Admin Panel
    └── src/
        ├── pages/    # Admin pages
        ├── components/ # UI components
        └── services/ # API integration
```

## 📊 API Endpoints

```
POST   /api/v1/auth/register       # Регистрация
POST   /api/v1/auth/login          # Авторизация
GET    /api/v1/auth/me             # Текущий пользователь

GET    /api/v1/videos              # Список видео
POST   /api/v1/videos              # Загрузка видео
PUT    /api/v1/videos/{id}         # Обновление
DELETE /api/v1/videos/{id}         # Удаление

GET    /api/v1/playlists/current   # Текущий плейлист
POST   /api/v1/playlists/regenerate # Новый плейлист

POST   /api/v1/sessions/start      # Начать сессию
POST   /api/v1/sessions/end        # Завершить сессию

POST   /api/v1/playback            # Лог воспроизведения

GET    /api/v1/analytics/me        # Моя аналитика
```

Полная документация: http://localhost:8000/docs

## 🤝 Contributing

Проект открыт для улучшений и предложений!

## 📄 Лицензия

Проект разработан для коммерческого использования.

## 📞 Контакты

Для вопросов и предложений свяжитесь с командой разработки.

---

<div align="center">

**Billboard Mobile** - Современное решение для цифровой рекламы в такси 🚕📱

Made with ❤️ using FastAPI and Flutter

</div>
