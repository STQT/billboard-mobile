import 'package:flutter/foundation.dart';
import 'api_service.dart';

class AnalyticsService extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  
  int? _currentSessionId;
  DateTime? _sessionStartTime;
  DateTime? _currentVideoStartTime;

  int? get currentSessionId => _currentSessionId;
  bool get hasActiveSession => _currentSessionId != null;

  Future<void> startSession() async {
    try {
      final sessionData = await _apiService.startSession();
      _currentSessionId = sessionData['id'];
      _sessionStartTime = DateTime.now();
      notifyListeners();
    } catch (e) {
      debugPrint('Error starting session: $e');
    }
  }

  Future<void> endSession() async {
    if (_currentSessionId == null) return;

    try {
      await _apiService.endSession(_currentSessionId!);
      _currentSessionId = null;
      _sessionStartTime = null;
      notifyListeners();
    } catch (e) {
      debugPrint('Error ending session: $e');
    }
  }

  void startVideoPlayback() {
    _currentVideoStartTime = DateTime.now();
  }

  Future<void> logVideoPlayback({
    required int videoId,
    bool completed = true,
  }) async {
    if (_currentVideoStartTime == null) return;

    try {
      final duration = DateTime.now().difference(_currentVideoStartTime!).inSeconds.toDouble();
      
      await _apiService.logPlayback(
        videoId: videoId,
        durationSeconds: duration,
        sessionId: _currentSessionId,
        completed: completed,
      );

      _currentVideoStartTime = null;
    } catch (e) {
      debugPrint('Error logging playback: $e');
    }
  }

  Future<Map<String, dynamic>> getAnalytics({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      return await _apiService.getMyAnalytics(
        startDate: startDate,
        endDate: endDate,
      );
    } catch (e) {
      debugPrint('Error getting analytics: $e');
      return {};
    }
  }

  Duration? getSessionDuration() {
    if (_sessionStartTime == null) return null;
    return DateTime.now().difference(_sessionStartTime!);
  }
}
