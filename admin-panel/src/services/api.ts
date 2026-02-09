import axios from 'axios';
import type {
  Vehicle,
  Video,
  Playlist,
  Session,
  VehicleAnalytics,
  DashboardStats,
} from '../types';

const API_BASE_URL = '/api/v1';

const api = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Interceptor для добавления токена (если потребуется авторизация админа)
api.interceptors.request.use((config) => {
  const token = localStorage.getItem('admin_token');
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

// Vehicles
export const vehiclesApi = {
  getAll: () => api.get<Vehicle[]>('/vehicles'),
  getById: (id: number) => api.get<Vehicle>(`/vehicles/${id}`),
  create: (data: Partial<Vehicle>) => api.post<Vehicle>('/auth/register', data),
  update: (id: number, data: Partial<Vehicle>) => api.put<Vehicle>(`/vehicles/${id}`, data),
  delete: (id: number) => api.delete(`/vehicles/${id}`),
};

// Videos
export const videosApi = {
  getAll: (params?: { tariff?: string; video_type?: string; is_active?: boolean }) =>
    api.get<Video[]>('/videos', { params }),
  getById: (id: number) => api.get<Video>(`/videos/${id}`),
  create: (formData: FormData) =>
    api.post<Video>('/videos', formData, {
      headers: { 'Content-Type': 'multipart/form-data' },
    }),
  update: (id: number, data: Partial<Video>) => api.put<Video>(`/videos/${id}`, data),
  delete: (id: number) => api.delete(`/videos/${id}`),
};

// Playlists
export const playlistsApi = {
  getByVehicle: (vehicleId: number) => api.get<Playlist>(`/playlists/current?vehicle_id=${vehicleId}`),
  regenerate: (vehicleId: number, hours: number = 24) =>
    api.post<Playlist>(`/playlists/regenerate?hours=${hours}&vehicle_id=${vehicleId}`),
};

// Sessions
export const sessionsApi = {
  getAll: () => api.get<Session[]>('/sessions'),
  getByVehicle: (vehicleId: number) => api.get<Session[]>(`/sessions?vehicle_id=${vehicleId}`),
};

// Analytics
export const analyticsApi = {
  getVehicleAnalytics: (vehicleId: number, startDate?: string, endDate?: string) => {
    const params: any = {};
    if (startDate) params.start_date = startDate;
    if (endDate) params.end_date = endDate;
    return api.get<VehicleAnalytics>(`/analytics/vehicle/${vehicleId}`, { params });
  },
  getDashboardStats: async (): Promise<DashboardStats> => {
    // Собрать статистику из разных endpoints
    const [vehicles, videos] = await Promise.all([
      api.get<Vehicle[]>('/vehicles'),
      api.get<Video[]>('/videos'),
    ]);

    // В реальности нужно добавить endpoints для этой статистики в backend
    // Пока возвращаем mock данные
    return {
      total_vehicles: vehicles.data.length,
      active_vehicles: vehicles.data.filter(v => v.is_active).length,
      total_videos: videos.data.length,
      total_playbacks_today: 0, // TODO: добавить endpoint
      total_earnings_today: 0, // TODO: добавить endpoint
      active_sessions: 0, // TODO: добавить endpoint
    };
  },
};

export default api;
