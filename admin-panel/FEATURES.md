# 🎛️ Админ Панель - Возможности

## Обзор

Современная веб-панель администратора для системы Billboard Mobile. Построена на React + TypeScript + Material-UI.

## Скриншоты интерфейса (описание)

### 📊 Dashboard
```
┌─────────────────────────────────────────────────────┐
│  Dashboard                                          │
├─────────────────────────────────────────────────────┤
│                                                     │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐         │
│  │ 🚗 5     │  │ ✅ 4     │  │ 🎬 12    │         │
│  │ Всего    │  │ Активно  │  │ Видео    │         │
│  │ авто     │  │ авто     │  │          │         │
│  └──────────┘  └──────────┘  └──────────┘         │
│                                                     │
│  ┌─────────────────────────────────┐               │
│  │ Статистика за сегодня           │               │
│  │ • Активных сессий: 3            │               │
│  │ • Заработано: 150,000 сум       │               │
│  └─────────────────────────────────┘               │
│                                                     │
└─────────────────────────────────────────────────────┘
```

### 🚗 Автомобили
- Таблица со всеми автомобилями
- Колонки: ID, Логин, Номер, Тариф, Водитель, Статус
- Кнопки: Добавить, Редактировать, Удалить
- Фильтрация по статусу

### 🎬 Видео
- Таблица со всеми видео
- Колонки: ID, Название, Тип, Размер, Длительность, Показы/час
- Загрузка видео через форму
- Настройка типа (филлер/контракт)
- Привязка к тарифам

### 📈 Аналитика
- Фильтры по датам
- Выбор автомобиля
- Детальная статистика
- (Планируется: графики, экспорт)

### 🎵 Плейлисты
- Просмотр плейлистов
- Принудительная генерация
- Информация о логике

## Основные функции

### 1. Управление автомобилями

#### Добавление
```typescript
POST /api/v1/auth/register
{
  "login": "car001",
  "password": "password123",
  "car_number": "01A001AA",
  "tariff": "standard",
  "driver_name": "Иван Иванов",
  "phone": "+998901234567"
}
```

#### Редактирование
- Изменение тарифа
- Обновление данных водителя
- Активация/деактивация

#### Удаление
- С подтверждением
- Удаляет автомобиль из системы

### 2. Управление видео

#### Загрузка
```
1. Выбрать файл (MP4, до 500 МБ)
2. Указать название
3. Выбрать тип:
   - Филлер (заполняющее)
   - Контрактное (с гарантиями)
4. Для контрактных: указать показов/час
5. Выбрать тарифы
6. Установить приоритет
7. Загрузить
```

#### Просмотр
- Список всех видео
- Сортировка по полям
- Фильтрация по типу
- Статус активности

#### Удаление
- Удаляет запись из БД
- Удаляет файл с диска

### 3. Аналитика

#### Фильтры
- По автомобилю (ID)
- По датам (начало и конец)
- По типу видео
- По тарифу

#### Метрики
- Время работы
- Количество воспроизведений
- Заработок
- Праймтайм статистика

### 4. Плейлисты

#### Просмотр
- Список видео в плейлисте
- Порядок воспроизведения
- Период действия

#### Генерация
- Автоматическая на 24 часа
- Принудительная по запросу
- Учет контрактных видео
- Заполнение филлерами

## UI Компоненты

### Material-UI компоненты:

#### Navigation
- `Drawer` - боковое меню
- `AppBar` - верхняя панель
- `Toolbar` - тулбар

#### Display
- `Table` - таблицы данных
- `Card` - карточки со статистикой
- `Chip` - статусы и теги
- `Paper` - контейнеры

#### Input
- `TextField` - текстовые поля
- `Select` - выпадающие списки
- `Button` - кнопки действий
- `IconButton` - иконочные кнопки

#### Feedback
- `Dialog` - модальные окна
- `Snackbar` - уведомления
- `CircularProgress` - загрузка

## Типы данных (TypeScript)

### Vehicle
```typescript
interface Vehicle {
  id: number;
  login: string;
  car_number: string;
  tariff: 'standard' | 'comfort' | 'business' | 'premium';
  driver_name?: string;
  phone?: string;
  is_active: boolean;
  created_at: string;
}
```

### Video
```typescript
interface Video {
  id: number;
  title: string;
  filename: string;
  file_path: string;
  file_size?: number;
  duration?: number;
  video_type: 'filler' | 'contract';
  plays_per_hour?: number;
  tariffs: string;
  priority: number;
  is_active: boolean;
  created_at: string;
}
```

### Analytics
```typescript
interface VehicleAnalytics {
  vehicle_id: number;
  car_number: string;
  daily_stats: DailyAnalytics[];
  video_stats: VideoAnalytics[];
  total_earnings: number;
}
```

## API Integration

### Axios Client
```typescript
const api = axios.create({
  baseURL: '/api/v1',
  headers: {
    'Content-Type': 'application/json',
  },
});
```

### API Methods
```typescript
// Vehicles
vehiclesApi.getAll()
vehiclesApi.create(data)
vehiclesApi.update(id, data)
vehiclesApi.delete(id)

// Videos
videosApi.getAll(params)
videosApi.create(formData)
videosApi.delete(id)

// Analytics
analyticsApi.getVehicleAnalytics(id, startDate, endDate)
analyticsApi.getDashboardStats()

// Playlists
playlistsApi.getByVehicle(vehicleId)
playlistsApi.regenerate(vehicleId, hours)
```

## Состояние (State Management)

### React Hooks
- `useState` - локальное состояние
- `useEffect` - side effects
- `useNavigate` - навигация
- `useSnackbar` - уведомления

### Пример использования
```typescript
const [vehicles, setVehicles] = useState<Vehicle[]>([]);
const [loading, setLoading] = useState(true);
const { enqueueSnackbar } = useSnackbar();

useEffect(() => {
  loadVehicles();
}, []);

const loadVehicles = async () => {
  try {
    const response = await vehiclesApi.getAll();
    setVehicles(response.data);
    enqueueSnackbar('Загружено', { variant: 'success' });
  } catch (error) {
    enqueueSnackbar('Ошибка', { variant: 'error' });
  } finally {
    setLoading(false);
  }
};
```

## Валидация

### Формы
- Обязательные поля отмечены *
- Валидация перед отправкой
- Отображение ошибок

### Примеры
```typescript
// Проверка обязательных полей
if (!formData.title) {
  enqueueSnackbar('Введите название', { variant: 'warning' });
  return;
}

// Проверка файла
if (!selectedFile) {
  enqueueSnackbar('Выберите файл', { variant: 'warning' });
  return;
}
```

## Уведомления

### Типы
- ✅ **Success** - успешные операции
- ❌ **Error** - ошибки
- ⚠️ **Warning** - предупреждения
- ℹ️ **Info** - информация

### Примеры
```typescript
enqueueSnackbar('Автомобиль создан', { variant: 'success' });
enqueueSnackbar('Ошибка загрузки', { variant: 'error' });
enqueueSnackbar('Выберите файл', { variant: 'warning' });
```

## Навигация

### Роуты
```typescript
<Routes>
  <Route path="/" element={<Navigate to="/dashboard" />} />
  <Route path="/dashboard" element={<Dashboard />} />
  <Route path="/vehicles" element={<Vehicles />} />
  <Route path="/videos" element={<Videos />} />
  <Route path="/analytics" element={<Analytics />} />
  <Route path="/playlists" element={<Playlists />} />
</Routes>
```

### Программная навигация
```typescript
const navigate = useNavigate();
navigate('/vehicles');
```

## Стилизация

### Theme
```typescript
const theme = createTheme({
  palette: {
    mode: 'light',
    primary: {
      main: '#1976d2',
    },
    secondary: {
      main: '#dc004e',
    },
  },
});
```

### Sx Props
```typescript
<Box sx={{ 
  display: 'flex', 
  justifyContent: 'space-between',
  p: 3,
  mb: 2
}}>
```

## Производительность

### Оптимизации
- Lazy loading компонентов
- Мемоизация списков
- Debounce для поиска
- Pagination для больших списков

### Кеширование
- Кеширование запросов
- Local storage для настроек
- Session storage для состояния

## Безопасность

### Аутентификация
- JWT токены (планируется)
- Хранение в localStorage
- Auto-logout при истечении

### Авторизация
- Роли пользователей (планируется)
- Права доступа
- Защита роутов

## Будущие улучшения

### Фаза 2
- [ ] Авторизация админов
- [ ] Роли и права
- [ ] Расширенная аналитика с графиками
- [ ] Экспорт данных (Excel, CSV, PDF)

### Фаза 3
- [ ] Финансовые отчеты
- [ ] Биллинг и выплаты
- [ ] Email уведомления
- [ ] Push уведомления

### Фаза 4
- [ ] Real-time обновления (WebSocket)
- [ ] Logs viewer
- [ ] System monitoring
- [ ] Backup и restore

## Заключение

Админ панель предоставляет полный контроль над системой Billboard Mobile через удобный веб-интерфейс. Современный стек технологий обеспечивает быструю разработку и отличный UX.

---

**Технологии:** React 18, TypeScript 5, Material-UI 5, Vite 5  
**Страниц:** 5  
**Компонентов:** 6  
**API методов:** 15+
