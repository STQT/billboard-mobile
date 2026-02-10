export interface Vehicle {
  id: number;
  login: string;
  car_number: string;
  tariff: 'standard' | 'comfort' | 'business' | 'premium';
  driver_name?: string;
  phone?: string;
  is_active: boolean;
  created_at: string;
}

export interface Video {
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

export interface ContractVideoItem {
  video_id: number;
  start_time: number;  // Время начала в секундах от начала часа (0-3600)
  end_time: number;    // Время окончания в секундах от начала часа (0-3600)
  duration: number;    // Длительность в секундах
  frequency: number;   // Количество повторений этого видео в плейлисте
  file_path: string;   // Путь к файлу (например, /videos/filename.mp4)
  media_url: string;   // Полный URL для доступа к медиа файлу
}

export interface FillerVideoItem {
  video_id: number;
  duration: number;    // Длительность в секундах
  file_path: string;   // Путь к файлу (например, /videos/filename.mp4)
  media_url: string;   // Полный URL для доступа к медиа файлу
}

export interface Playlist {
  id: number;
  vehicle_id: number | null;  // null для плейлиста по тарифу
  tariff: string;
  contract_videos: ContractVideoItem[];
  filler_videos: FillerVideoItem[];
  total_duration: number;  // Общая длительность плейлиста в секундах (3600 для часового)
  valid_from: string;
  valid_until: string;
  created_at: string;
}

export interface Session {
  id: number;
  vehicle_id: number;
  start_time: string;
  end_time?: string;
  total_duration_seconds: number;
  videos_played: number;
}

export interface PlaybackLog {
  id: number;
  vehicle_id: number;
  video_id: number;
  played_at: string;
  duration_seconds: number;
  is_prime_time: boolean;
  completed: boolean;
}

export interface DailyAnalytics {
  date: string;
  total_duration_seconds: number;
  videos_played: number;
  prime_time_duration_seconds: number;
  earnings: number;
}

export interface VideoAnalytics {
  video_id: number;
  video_title: string;
  play_count: number;
  total_duration: number;
}

export interface VehicleAnalytics {
  vehicle_id: number;
  car_number: string;
  daily_stats: DailyAnalytics[];
  video_stats: VideoAnalytics[];
  total_earnings: number;
}

export interface DashboardStats {
  total_vehicles: number;
  active_vehicles: number;
  total_videos: number;
  total_playbacks_today: number;
  total_earnings_today: number;
  active_sessions: number;
}
