from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
import os

from app.api.routes import router
from app.core.config import settings
from app.db.database import engine, Base

# Создать таблицы
Base.metadata.create_all(bind=engine)

# Создать директорию для загрузок
os.makedirs(settings.UPLOAD_DIR, exist_ok=True)

app = FastAPI(
    title="Billboard Mobile API",
    description="API для системы цифровой рекламы в такси",
    version="1.0.0"
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
if os.path.exists(settings.UPLOAD_DIR):
    app.mount("/videos", StaticFiles(directory=settings.UPLOAD_DIR), name="videos")


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
        reload=True
    )
