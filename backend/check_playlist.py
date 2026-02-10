#!/usr/bin/env python3
"""
Проверка плейлиста для автомобиля (vehicle_id=1).
Использует админский endpoint без авторизации.
Запуск: python check_playlist.py [BASE_URL] [VEHICLE_ID]
Пример: python check_playlist.py
        python check_playlist.py http://localhost:8000 1
"""

import requests
import json
import sys

DEFAULT_BASE = "http://localhost:8000/api/v1"


def check_playlist(base_url: str = DEFAULT_BASE, vehicle_id: int = 1) -> bool:
    url = f"{base_url}/playlists/vehicle/{vehicle_id}"
    print(f"Запрос: GET {url}")
    try:
        r = requests.get(url, timeout=60)
        r.raise_for_status()
        data = r.json()
        print("OK: плейлист получен")
        print(f"  ID плейлиста: {data.get('id')}")
        print(f"  vehicle_id: {data.get('vehicle_id')}")
        print(f"  tariff: {data.get('tariff')}")
        print(f"  Действует с: {data.get('valid_from')}")
        print(f"  Действует до: {data.get('valid_until')}")
        seq = data.get("video_sequence") or []
        print(f"  Видео в плейлисте: {len(seq)}")
        if seq:
            print(f"  Первые 5 ID: {seq[:5]}")
        return True
    except requests.exceptions.Timeout:
        print("Ошибка: таймаут (генерация плейлиста заняла > 60 сек)")
        return False
    except requests.exceptions.RequestException as e:
        print(f"Ошибка запроса: {e}")
        if hasattr(e, "response") and e.response is not None:
            print(f"  Ответ: {e.response.text[:500]}")
        return False


if __name__ == "__main__":
    base = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_BASE
    if not base.endswith("/api/v1"):
        base = base.rstrip("/") + "/api/v1"
    vid = int(sys.argv[2]) if len(sys.argv) > 2 else 1
    ok = check_playlist(base, vid)
    sys.exit(0 if ok else 1)
