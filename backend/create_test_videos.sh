#!/bin/bash
# Скрипт для создания тестовых MP4 видео с помощью ffmpeg

UPLOAD_DIR="./uploads/videos"
mkdir -p "$UPLOAD_DIR"

echo "==============================================="
echo "  Создание тестовых видео"
echo "==============================================="
echo ""

# Функция для создания видео с цветным фоном и текстом
create_video() {
    local filename=$1
    local color=$2
    local text=$3
    local duration=$4
    
    local filepath="$UPLOAD_DIR/$filename"
    
    if [ -f "$filepath" ] && [ $(stat -f%z "$filepath" 2>/dev/null || stat -c%s "$filepath" 2>/dev/null) -gt 100 ]; then
        echo "⏭️  $filename уже существует (пропуск)"
        return
    fi
    
    echo "🎬 Создание: $filename"
    echo "   Цвет: $color, Длительность: ${duration}с"
    
    ffmpeg -f lavfi -i "color=c=$color:s=1280x720:d=$duration" \
           -vf "drawtext=text='$text':fontcolor=white:fontsize=48:x=(w-text_w)/2:y=(h-text_h)/2" \
           -c:v libx264 -pix_fmt yuv420p -preset fast -crf 23 \
           "$filepath" -y 2>&1 | grep -E "(Duration|time=)" | tail -1
    
    if [ $? -eq 0 ]; then
        local size=$(stat -f%z "$filepath" 2>/dev/null || stat -c%s "$filepath" 2>/dev/null)
        echo "   ✅ Размер: $((size / 1024)) KB"
    else
        echo "   ❌ Ошибка создания"
    fi
    echo ""
}

# Создать филлеры (разные цвета и длительность)
create_video "test_filler_1.mp4" "blue" "FILLER 1" 10
create_video "test_filler_2.mp4" "green" "FILLER 2" 8
create_video "test_filler_3.mp4" "purple" "FILLER 3" 12

# Создать контрактные видео (яркие цвета, короче)
create_video "test_contract_a.mp4" "red" "CONTRACT A" 5
create_video "test_contract_b.mp4" "orange" "CONTRACT B" 5

# Создать видео из админки (если есть)
for uuid_file in "$UPLOAD_DIR"/*.mp4; do
    if [ -f "$uuid_file" ]; then
        size=$(stat -f%z "$uuid_file" 2>/dev/null || stat -c%s "$uuid_file" 2>/dev/null)
        if [ $size -lt 100 ]; then
            filename=$(basename "$uuid_file")
            echo "🔄 Пересоздание: $filename (был заглушкой)"
            create_video "$filename" "gray" "TEST VIDEO" 10
        fi
    fi
done

echo "==============================================="
echo "✅ Готово! Проверьте: ls -lh $UPLOAD_DIR"
echo "==============================================="
