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

  Future<bool> login(String login, String password) async {
    try {
      _errorMessage = null;
      
      // Получить токен
      final tokenData = await _apiService.login(login, password);
      final token = tokenData['access_token'];
      
      // Сохранить токен
      await _apiService.setToken(token);
      
      // Получить данные автомобиля
      final vehicleData = await _apiService.getCurrentVehicle();
      _currentVehicle = Vehicle.fromJson(vehicleData);
      
      _isAuthenticated = true;
      notifyListeners();
      
      return true;
    } catch (e) {
      _errorMessage = 'Ошибка авторизации: ${e.toString()}';
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

  Future<void> checkAuth() async {
    try {
      final vehicleData = await _apiService.getCurrentVehicle();
      _currentVehicle = Vehicle.fromJson(vehicleData);
      _isAuthenticated = true;
      notifyListeners();
    } catch (e) {
      _isAuthenticated = false;
      notifyListeners();
    }
  }
}
