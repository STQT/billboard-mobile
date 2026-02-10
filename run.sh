#!/bin/bash

# Billboard Mobile - Скрипт быстрого запуска
# Этот скрипт поможет быстро запустить проект

echo "🚕 Billboard Mobile - Быстрый запуск"
echo "===================================="
echo ""

# Проверка что мы в правильной директории
if [ ! -d "backend" ] || [ ! -d "mobile" ]; then
    echo "❌ Ошибка: Запустите скрипт из корневой директории billboard-mobile"
    exit 1
fi

# Функция для проверки команды
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Проверка зависимостей
echo "📋 Проверка зависимостей..."

if ! command_exists python3; then
    echo "❌ Python 3 не установлен"
    exit 1
fi
echo "✅ Python 3 найден"

if ! command_exists docker; then
    echo "⚠️  Docker не установлен (опционально)"
else
    echo "✅ Docker найден"
fi

if ! command_exists flutter; then
    echo "⚠️  Flutter не установлен (для mobile приложения)"
else
    echo "✅ Flutter найден"
fi

echo ""

# Меню
echo "Выберите действие:"
echo "1) Запустить Backend (FastAPI)"
echo "2) Запустить Mobile приложение (Flutter)"
echo "3) Запустить Admin Panel (React)"
echo "4) Запустить базы данных (Docker)"
echo "5) Протестировать API"
echo "6) Установить все зависимости"
echo "7) Показать статус"
echo "0) Выход"
echo ""

read -p "Ваш выбор: " choice

case $choice in
    1)
        echo ""
        echo "🚀 Запуск Backend..."
        cd backend
        
        if [ ! -d "venv" ]; then
            echo "📦 Создание виртуального окружения..."
            python3 -m venv venv
        fi
        
        source venv/bin/activate
        
        # Проверка и установка зависимостей
        if ! python -c "import uvicorn" 2>/dev/null || [ ! -f "venv/.installed" ]; then
            echo "📦 Установка зависимостей..."
            pip install -r requirements.txt
            
            # Попробовать установить с binary wheels сначала
            echo "📦 Попытка установки с binary wheels..."
            if pip install -q --only-binary :all: -r requirements.txt 2>/dev/null; then
                echo "✅ Зависимости установлены (binary wheels)"
                touch venv/.installed
            else
                echo "⚠️  Binary wheels недоступны, пробуем обычную установку..."
                echo "💡 Если возникнут ошибки, см. backend/TROUBLESHOOTING.md"
                pip install -q -r requirements.txt || {
                    echo ""
                    echo "❌ Ошибка установки зависимостей"
                    echo "💡 Попробуйте:"
                    echo "   1. Освободите место на диске (нужно ~500MB)"
                    echo "   2. Запустите: bash backend/install_requirements.sh"
                    echo "   3. Или используйте Docker: docker-compose up -d"
                    exit 1
                }
                touch venv/.installed
                echo "✅ Зависимости установлены"
            fi
        fi
        
        if [ ! -f ".env" ]; then
            echo "📝 Создание .env файла..."
            cp .env.example .env
            echo "⚠️  Не забудьте настроить .env файл!"
        fi
        
        echo "🌐 Запуск сервера на http://localhost:8000"
        echo "📚 API документация: http://localhost:8000/docs"
        python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
        ;;
        
    2)
        echo ""
        echo "📱 Запуск Mobile приложения..."
        cd mobile
        
        echo "📦 Проверка зависимостей..."
        flutter pub get
        
        echo "🚀 Запуск приложения..."
        flutter run
        ;;
        
    3)
        echo ""
        echo "🌐 Запуск Admin Panel..."
        cd admin-panel
        
        if [ ! -d "node_modules" ]; then
            echo "📦 Установка зависимостей..."
            npm install
            echo "✅ Зависимости установлены"
        fi
        
        echo "🚀 Запуск на http://localhost:3000"
        echo "⚠️  Убедитесь что Backend запущен на http://localhost:8000"
        npm run dev
        ;;
        
    4)
        echo ""
        echo "🐳 Запуск баз данных..."
        cd backend
        
        if command_exists docker-compose; then
            docker-compose up -d postgres redis
            echo "✅ PostgreSQL и Redis запущены"
            echo "   PostgreSQL: localhost:5432"
            echo "   Redis: localhost:6379"
        else
            echo "❌ docker-compose не найден"
            exit 1
        fi
        ;;
        
    5)
        echo ""
        echo "🧪 Тестирование API..."
        cd backend
        
        if [ ! -d "venv" ]; then
            echo "❌ Виртуальное окружение не создано. Сначала запустите опцию 1 или 6"
            exit 1
        fi
        
        source venv/bin/activate
        
        # Проверка зависимостей
        if ! python -c "import requests" 2>/dev/null; then
            echo "📦 Установка зависимостей для тестов..."
            pip install -q -r requirements.txt
        fi
        
        echo "⚠️  Убедитесь что Backend запущен на http://localhost:8000"
        python test_api.py
        ;;
        
    6)
        echo ""
        echo "📦 Установка зависимостей..."
        
        echo "Backend:"
        cd backend
        python3 -m venv venv
        source venv/bin/activate
        pip install -r requirements.txt
        echo "✅ Backend зависимости установлены"
        
        echo ""
        echo "Mobile:"
        cd ../mobile
        flutter pub get
        echo "✅ Mobile зависимости установлены"
        
        echo ""
        echo "Admin Panel:"
        cd ../admin-panel
        npm install
        echo "✅ Admin Panel зависимости установлены"
        
        echo ""
        echo "✅ Все зависимости установлены!"
        ;;
        
    7)
        echo ""
        echo "📊 Статус проекта:"
        echo ""
        
        # Backend
        echo "Backend:"
        if [ -d "backend/venv" ]; then
            echo "  ✅ Virtual environment создан"
        else
            echo "  ❌ Virtual environment не создан"
        fi
        
        if [ -f "backend/.env" ]; then
            echo "  ✅ .env файл существует"
        else
            echo "  ⚠️  .env файл не создан"
        fi
        
        # Mobile
        echo ""
        echo "Mobile:"
        if [ -d "mobile/.dart_tool" ]; then
            echo "  ✅ Flutter зависимости установлены"
        else
            echo "  ❌ Flutter зависимости не установлены"
        fi
        
        # Docker
        echo ""
        echo "Docker:"
        if command_exists docker; then
            if docker ps | grep -q billboard_postgres; then
                echo "  ✅ PostgreSQL запущен"
            else
                echo "  ⚠️  PostgreSQL не запущен"
            fi
            
            if docker ps | grep -q billboard_redis; then
                echo "  ✅ Redis запущен"
            else
                echo "  ⚠️  Redis не запущен"
            fi
        else
            echo "  ⚠️  Docker не установлен"
        fi
        
        echo ""
        echo "Для детальной информации см. START_HERE.md"
        ;;
        
    0)
        echo "Выход..."
        exit 0
        ;;
        
    *)
        echo "❌ Неверный выбор"
        exit 1
        ;;
esac
