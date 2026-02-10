#!/bin/bash

# Скрипт для установки зависимостей с обработкой ошибок

echo "📦 Установка зависимостей для Billboard Backend"
echo "================================================"
echo ""

# Активировать venv если существует
if [ -d "venv" ]; then
    source venv/bin/activate
    echo "✅ Виртуальное окружение активировано"
else
    echo "❌ Виртуальное окружение не найдено. Создайте его сначала:"
    echo "   python3 -m venv venv"
    exit 1
fi

# Обновить pip
echo ""
echo "📦 Обновление pip..."
pip install --upgrade pip setuptools wheel

# Попробовать установить с использованием только binary wheels
echo ""
echo "📦 Установка зависимостей (только binary wheels)..."
pip install --only-binary :all: -r requirements.txt 2>&1 | tee install.log

if [ ${PIPESTATUS[0]} -ne 0 ]; then
    echo ""
    echo "⚠️  Установка с только binary wheels не удалась, пробуем обычную установку..."
    
    # Проверить место на диске
    echo ""
    echo "💾 Проверка свободного места на диске..."
    df -h . | tail -1
    
    # Попробовать установить без компиляции Rust пакетов
    echo ""
    echo "📦 Установка зависимостей (без компиляции Rust)..."
    
    # Установить зависимости по одной, пропуская проблемные
    pip install fastapi uvicorn[standard] sqlalchemy psycopg2-binary alembic
    pip install python-jose[cryptography] passlib[bcrypt] python-multipart
    pip install redis python-dotenv aiofiles requests
    
    # Попробовать установить pydantic с предкомпилированными wheels
    echo ""
    echo "📦 Установка pydantic (попытка с wheels)..."
    pip install --upgrade --only-binary pydantic pydantic || {
        echo ""
        echo "⚠️  Не удалось установить pydantic с wheels"
        echo "💡 Попробуйте один из вариантов:"
        echo "   1. Освободите место на диске (нужно ~500MB)"
        echo "   2. Используйте Python 3.11 или 3.12 вместо 3.13"
        echo "   3. Установите Rust: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
        exit 1
    }
    
    pip install --upgrade --only-binary pydantic-settings pydantic-settings || {
        echo "⚠️  pydantic-settings установлен без binary wheels"
        pip install pydantic-settings
    }
fi

echo ""
echo "✅ Проверка установленных пакетов..."
python -c "import fastapi, uvicorn, sqlalchemy, pydantic; print('✅ Основные пакеты установлены')" || {
    echo "❌ Не все пакеты установлены корректно"
    exit 1
}

echo ""
echo "✅ Установка завершена!"
echo ""
echo "Для запуска сервера:"
echo "  python -m uvicorn app.main:app --reload"
