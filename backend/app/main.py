from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from contextlib import asynccontextmanager
import os
import time

from app.api.routes import router
from app.core.config import settings
from app.db.database import engine, Base


def init_db():
    """Создать таблицы с повторными попытками при старте в Docker."""
    for attempt in range(10):
        try:
            Base.metadata.create_all(bind=engine)
            return
        except Exception as e:
            if attempt < 9:
                time.sleep(2)
                continue
            raise e


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: ждём БД и создаём таблицы
    init_db()
    yield
    # Shutdown (при необходимости)


# Создать директорию для загрузок
os.makedirs(settings.UPLOAD_DIR, exist_ok=True)

app = FastAPI(
    title="Billboard Mobile API",
    description="API для системы цифровой рекламы в такси",
    version="1.0.0",
    lifespan=lifespan,
)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # В продакшене указать конкретные домены
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Подключить роуты
app.include_router(router, prefix="/api/v1")

# Статические файлы (для видео)
# Монтируем /uploads/videos на директорию ./uploads/videos
if os.path.exists(settings.UPLOAD_DIR):
    app.mount("/uploads/videos", StaticFiles(directory=settings.UPLOAD_DIR), name="uploads_videos")


@app.get("/")
def root():
    return {
        "message": "Billboard Mobile API",
        "version": "1.0.0",
        "docs": "/docs"
    }


@app.get("/health")
def health_check():
    return {"status": "ok"}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "app.main:app",
        host=settings.HOST,
        port=settings.PORT,
        reload=settings.DEBUG
    )
