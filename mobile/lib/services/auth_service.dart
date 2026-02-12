import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'api_service.dart';
import '../models/vehicle.dart';

class AuthService extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  Vehicle? _currentVehicle;
  bool _isAuthenticated = false;
  String? _errorMessage;

  Vehicle? get currentVehicle => _currentVehicle;
  bool get isAuthenticated => _isAuthenticated;
  String? get errorMessage => _errorMessage;

  String _userFriendlyError(dynamic e) {
    if (e is DioException) {
      if (e.type == DioExceptionType.connectionError ||
          e.error is SocketException ||
          (e.error != null && e.error.toString().contains('Failed host lookup'))) {
        return 'Serverga ulanish imkonsiz. Internet va Wi‑Fi/mobil ma\'lumotlarni tekshiring. '
            'Agar server boshqa manzilda bo\'lsa, lib/config/app_config.dart da apiBaseUrl ni o\'zgartiring.';
      }
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        return 'Server javob bermadi (vaqt tugadi). Internet va server manzilini tekshiring.';
      }
      if (e.response != null && e.response!.statusCode == 401) {
        return 'Login yoki parol noto\'g\'ri.';
      }
    }
    if (e is SocketException) {
      return 'Serverga ulanish imkonsiz. Internet va server manzilini tekshiring.';
    }
    return 'Ошибка авторизации: ${e.toString()}';
  }

  Future<bool> login(String login, String password) async {
    try {
      _errorMessage = null;

      final tokenData = await _apiService.login(login, password);
      final token = tokenData['access_token'];

      await _apiService.setToken(token);

      final vehicleData = await _apiService.getCurrentVehicle();
      _currentVehicle = Vehicle.fromJson(vehicleData);

      _isAuthenticated = true;
      notifyListeners();

      return true;
    } catch (e) {
      _errorMessage = _userFriendlyError(e);
      _isAuthenticated = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _apiService.clearToken();
    _currentVehicle = null;
    _isAuthenticated = false;
    notifyListeners();
  }

  /// Проверить сохраненный токен и восстановить сессию
  Future<bool> checkAuth() async {
    try {
      // Проверить наличие токена
      final hasToken = await _apiService.hasToken();
      if (!hasToken) {
        _isAuthenticated = false;
        notifyListeners();
        return false;
      }

      // Проверить валидность токена через API
      final vehicleData = await _apiService.getCurrentVehicle();
      _currentVehicle = Vehicle.fromJson(vehicleData);
      _isAuthenticated = true;
      notifyListeners();
      return true;
    } catch (e) {
      // Токен невалиден или ошибка сети
      _isAuthenticated = false;
      _errorMessage = null; // Не показывать ошибку при автоматической проверке
      await _apiService.clearToken();
      notifyListeners();
      return false;
    }
  }
}
