FROM python:3.11-slim

WORKDIR /app

# Установить зависимости системы
RUN apt-get update && apt-get install -y \
    gcc \
    postgresql-client \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/* \
    && ffprobe -version

# Копировать requirements
COPY requirements.txt .

# Установить Python зависимости
RUN pip install --no-cache-dir -r requirements.txt

# Копировать приложение
COPY . .

# Создать директорию для видео
RUN mkdir -p /app/uploads/videos

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
