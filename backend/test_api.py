#!/usr/bin/env python3
"""
Тестовый скрипт для проверки работы Billboard Mobile API
"""

import requests
import json
import sys

BASE_URL = "http://localhost:8000/api/v1"


class APITester:
    def __init__(self):
        self.token = None
        self.vehicle_id = None
        self.session_id = None
        self.video_ids = []

    def print_success(self, message):
        print(f"✅ {message}")

    def print_error(self, message):
        print(f"❌ {message}")

    def print_info(self, message):
        print(f"ℹ️  {message}")

    def test_health(self):
        """Проверка здоровья API"""
        self.print_info("Проверка здоровья API...")
        try:
            response = requests.get(f"{BASE_URL.replace('/api/v1', '')}/health")
            if response.status_code == 200:
                self.print_success("API работает")
                return True
            else:
                self.print_error(f"API не отвечает: {response.status_code}")
                return False
        except Exception as e:
            self.print_error(f"Не удалось подключиться к API: {e}")
            return False

    def test_register(self):
        """Регистрация тестового автомобиля"""
        self.print_info("Регистрация тестового автомобиля...")
        
        data = {
            "login": "test_car_001",
            "password": "test_password_123",
            "car_number": "01T001TT",
            "tariff": "standard",
            "driver_name": "Тестовый Водитель",
            "phone": "+998901234567"
        }

        try:
            response = requests.post(f"{BASE_URL}/auth/register", json=data)
            
            if response.status_code == 200:
                result = response.json()
                self.vehicle_id = result['id']
                self.print_success(f"Автомобиль зарегистрирован: ID={self.vehicle_id}, Номер={result['car_number']}")
                return True
            elif response.status_code == 400:
                self.print_info("Автомобиль уже существует, пытаемся войти...")
                return self.test_login()
            else:
                self.print_error(f"Ошибка регистрации: {response.status_code} - {response.text}")
                return False
        except Exception as e:
            self.print_error(f"Ошибка при регистрации: {e}")
            return False

    def test_login(self):
        """Авторизация"""
        self.print_info("Авторизация...")
        
        data = {
            "login": "test_car_001",
            "password": "test_password_123"
        }

        try:
            response = requests.post(f"{BASE_URL}/auth/login", json=data)
            
            if response.status_code == 200:
                result = response.json()
                self.token = result['access_token']
                self.print_success("Успешная авторизация")
                return True
            else:
                self.print_error(f"Ошибка авторизации: {response.status_code} - {response.text}")
                return False
        except Exception as e:
            self.print_error(f"Ошибка при авторизации: {e}")
            return False

    def test_get_me(self):
        """Получить информацию о текущем автомобиле"""
        self.print_info("Получение информации о текущем автомобиле...")
        
        headers = {"Authorization": f"Bearer {self.token}"}

        try:
            response = requests.get(f"{BASE_URL}/auth/me", headers=headers)
            
            if response.status_code == 200:
                result = response.json()
                self.vehicle_id = result['id']
                self.print_success(f"Получена информация: {result['car_number']} ({result['tariff']})")
                return True
            else:
                self.print_error(f"Ошибка: {response.status_code}")
                return False
        except Exception as e:
            self.print_error(f"Ошибка: {e}")
            return False

    def test_get_videos(self):
        """Получить список видео"""
        self.print_info("Получение списка видео...")
        
        try:
            response = requests.get(f"{BASE_URL}/videos")
            
            if response.status_code == 200:
                videos = response.json()
                self.print_success(f"Найдено {len(videos)} видео")
                
                if videos:
                    self.video_ids = [v['id'] for v in videos]
                    for video in videos[:3]:
                        print(f"   - ID: {video['id']}, Название: {video['title']}, Тип: {video['video_type']}")
                else:
                    self.print_info("⚠️  Видео не найдены. Загрузите видео через API для полного тестирования.")
                
                return True
            else:
                self.print_error(f"Ошибка: {response.status_code}")
                return False
        except Exception as e:
            self.print_error(f"Ошибка: {e}")
            return False

    def test_get_playlist(self):
        """Получить плейлист"""
        self.print_info("Получение плейлиста...")
        
        headers = {"Authorization": f"Bearer {self.token}"}

        try:
            response = requests.get(f"{BASE_URL}/playlists/current", headers=headers)
            
            if response.status_code == 200:
                playlist = response.json()
                video_count = len(playlist['video_sequence'])
                self.print_success(f"Плейлист получен: {video_count} видео")
                print(f"   Действителен с {playlist['valid_from']} до {playlist['valid_until']}")
                return True
            else:
                self.print_error(f"Ошибка: {response.status_code} - {response.text}")
                return False
        except Exception as e:
            self.print_error(f"Ошибка: {e}")
            return False

    def test_start_session(self):
        """Начать сессию"""
        self.print_info("Начало сессии...")
        
        headers = {"Authorization": f"Bearer {self.token}"}

        try:
            response = requests.post(f"{BASE_URL}/sessions/start", headers=headers)
            
            if response.status_code == 200:
                session = response.json()
                self.session_id = session['id']
                self.print_success(f"Сессия начата: ID={self.session_id}")
                return True
            else:
                self.print_error(f"Ошибка: {response.status_code}")
                return False
        except Exception as e:
            self.print_error(f"Ошибка: {e}")
            return False

    def test_log_playback(self):
        """Записать воспроизведение"""
        if not self.video_ids:
            self.print_info("Пропуск: нет видео для воспроизведения")
            return True

        self.print_info("Запись воспроизведения видео...")
        
        headers = {
            "Authorization": f"Bearer {self.token}",
            "Content-Type": "application/json"
        }

        data = {
            "video_id": self.video_ids[0],
            "duration_seconds": 30.5,
            "completed": True
        }

        params = {}
        if self.session_id:
            params['session_id'] = self.session_id

        try:
            response = requests.post(
                f"{BASE_URL}/playback",
                headers=headers,
                json=data,
                params=params
            )
            
            if response.status_code == 200:
                log = response.json()
                self.print_success(f"Воспроизведение записано: ID={log['id']}, Prime time: {log['is_prime_time']}")
                return True
            else:
                self.print_error(f"Ошибка: {response.status_code} - {response.text}")
                return False
        except Exception as e:
            self.print_error(f"Ошибка: {e}")
            return False

    def test_end_session(self):
        """Завершить сессию"""
        if not self.session_id:
            self.print_info("Пропуск: нет активной сессии")
            return True

        self.print_info("Завершение сессии...")
        
        headers = {"Authorization": f"Bearer {self.token}"}
        params = {"session_id": self.session_id}

        try:
            response = requests.post(
                f"{BASE_URL}/sessions/end",
                headers=headers,
                params=params
            )
            
            if response.status_code == 200:
                session = response.json()
                self.print_success(
                    f"Сессия завершена: Длительность={session['total_duration_seconds']}с, "
                    f"Видео={session['videos_played']}"
                )
                return True
            else:
                self.print_error(f"Ошибка: {response.status_code}")
                return False
        except Exception as e:
            self.print_error(f"Ошибка: {e}")
            return False

    def test_get_analytics(self):
        """Получить аналитику"""
        self.print_info("Получение аналитики...")
        
        headers = {"Authorization": f"Bearer {self.token}"}

        try:
            response = requests.get(f"{BASE_URL}/analytics/me", headers=headers)
            
            if response.status_code == 200:
                analytics = response.json()
                self.print_success("Аналитика получена")
                print(f"   Автомобиль: {analytics['car_number']}")
                print(f"   Дней с данными: {len(analytics['daily_stats'])}")
                print(f"   Всего заработано: {analytics['total_earnings']} сум")
                return True
            else:
                self.print_error(f"Ошибка: {response.status_code}")
                return False
        except Exception as e:
            self.print_error(f"Ошибка: {e}")
            return False

    def run_all_tests(self):
        """Запустить все тесты"""
        print("\n" + "="*60)
        print("    Billboard Mobile API - Тестирование")
        print("="*60 + "\n")

        tests = [
            ("Health Check", self.test_health),
            ("Регистрация", self.test_register),
            ("Авторизация", self.test_login),
            ("Получение информации", self.test_get_me),
            ("Список видео", self.test_get_videos),
            ("Получение плейлиста", self.test_get_playlist),
            ("Начало сессии", self.test_start_session),
            ("Запись воспроизведения", self.test_log_playback),
            ("Завершение сессии", self.test_end_session),
            ("Аналитика", self.test_get_analytics),
        ]

        passed = 0
        failed = 0

        for name, test_func in tests:
            print(f"\n--- {name} ---")
            try:
                if test_func():
                    passed += 1
                else:
                    failed += 1
            except Exception as e:
                self.print_error(f"Неожиданная ошибка: {e}")
                failed += 1

        print("\n" + "="*60)
        print(f"Результаты: ✅ Пройдено: {passed} | ❌ Провалено: {failed}")
        print("="*60 + "\n")

        return failed == 0


if __name__ == "__main__":
    tester = APITester()
    success = tester.run_all_tests()
    sys.exit(0 if success else 1)
