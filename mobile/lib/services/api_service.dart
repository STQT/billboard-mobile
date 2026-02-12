import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';

class ApiService {
  static String get baseUrl => apiBaseUrl;

  late Dio _dio;
  String? _token;
  bool _isInitialized = false;

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: apiBaseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
      },
    ));

    // Interceptor для добавления токена
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Убедиться что токен загружен
        if (!_isInitialized) {
          await _loadToken();
        }
        if (_token != null) {
          options.headers['Authorization'] = 'Bearer $_token';
        }
        return handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          // Token expired, logout
          await clearToken();
        }
        return handler.next(error);
      },
    ));
  }

  Future<void> _loadToken() async {
    if (_isInitialized) return;
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    _isInitialized = true;
  }

  /// Проверить наличие сохраненного токена
  Future<bool> hasToken() async {
    await _loadToken();
    return _token != null && _token!.isNotEmpty;
  }

  Future<void> setToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  // Auth
  Future<Map<String, dynamic>> login(String login, String password) async {
    final response = await _dio.post('/auth/login', data: {
      'login': login,
      'password': password,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> getCurrentVehicle() async {
    final response = await _dio.get('/auth/me');
    return response.data;
  }

  // Videos
  Future<List<dynamic>> getVideos() async {
    final response = await _dio.get('/videos');
    return response.data;
  }

  Future<Map<String, dynamic>> getVideo(int id) async {
    final response = await _dio.get('/videos/$id');
    return response.data;
  }

  // Playlists (генерация на 24ч может занимать время — увеличен таймаут)
  Future<Map<String, dynamic>> getCurrentPlaylist() async {
    final response = await _dio.get(
      '/playlists/current',
      options: Options(receiveTimeout: const Duration(seconds: 90)),
    );
    return response.data;
  }

  Future<Map<String, dynamic>> regeneratePlaylist({int hours = 24}) async {
    final response = await _dio.post('/playlists/regenerate', queryParameters: {
      'hours': hours,
    });
    return response.data;
  }

  // Sessions
  Future<Map<String, dynamic>> startSession() async {
    final response = await _dio.post('/sessions/start');
    return response.data;
  }

  Future<Map<String, dynamic>> endSession(int sessionId) async {
    final response = await _dio.post('/sessions/end', queryParameters: {
      'session_id': sessionId,
    });
    return response.data;
  }

  // Playback logs
  Future<Map<String, dynamic>> logPlayback({
    required int videoId,
    required double durationSeconds,
    int? sessionId,
    bool completed = true,
  }) async {
    final response = await _dio.post(
      '/playback',
      data: {
        'video_id': videoId,
        'duration_seconds': durationSeconds,
        'completed': completed,
      },
      queryParameters: sessionId != null ? {'session_id': sessionId} : null,
    );
    return response.data;
  }

  // Analytics
  Future<Map<String, dynamic>> getMyAnalytics({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final queryParams = <String, dynamic>{};
    if (startDate != null) {
      queryParams['start_date'] = startDate.toIso8601String().split('T')[0];
    }
    if (endDate != null) {
      queryParams['end_date'] = endDate.toIso8601String().split('T')[0];
    }

    final response = await _dio.get('/analytics/me', queryParameters: queryParams);
    return response.data;
  }
}
