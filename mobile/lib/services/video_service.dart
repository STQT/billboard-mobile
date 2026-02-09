import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'api_service.dart';
import '../models/video.dart';
import '../models/playlist.dart';

class VideoService extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final DefaultCacheManager _cacheManager = DefaultCacheManager();
  
  Playlist? _currentPlaylist;
  List<Video> _videos = [];
  int _currentVideoIndex = 0;
  bool _isLoading = false;

  Playlist? get currentPlaylist => _currentPlaylist;
  List<Video> get videos => _videos;
  int get currentVideoIndex => _currentVideoIndex;
  bool get isLoading => _isLoading;

  Video? get currentVideo {
    if (_videos.isEmpty || _currentVideoIndex >= _videos.length) {
      return null;
    }
    return _videos[_currentVideoIndex];
  }

  Future<void> loadPlaylist() async {
    try {
      _isLoading = true;
      notifyListeners();

      // Получить плейлист
      final playlistData = await _apiService.getCurrentPlaylist();
      _currentPlaylist = Playlist.fromJson(playlistData);

      // Загрузить информацию о видео
      await _loadVideos();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _loadVideos() async {
    if (_currentPlaylist == null) return;

    // Получить уникальные ID видео
    final uniqueVideoIds = _currentPlaylist!.videoSequence.toSet().toList();

    // Загрузить информацию о каждом видео
    final videoFutures = uniqueVideoIds.map((id) => _apiService.getVideo(id));
    final videoDataList = await Future.wait(videoFutures);

    // Создать map для быстрого доступа
    final videoMap = <int, Video>{};
    for (var videoData in videoDataList) {
      final video = Video.fromJson(videoData);
      videoMap[video.id] = video;
    }

    // Создать упорядоченный список видео по плейлисту
    _videos = _currentPlaylist!.videoSequence
        .map((id) => videoMap[id]!)
        .toList();

    // Начать кеширование видео в фоне
    _cacheVideos();
  }

  Future<void> _cacheVideos() async {
    // Кешировать видео в фоновом режиме
    for (var video in _videos) {
      try {
        final videoUrl = '${ApiService.baseUrl.replaceAll('/api/v1', '')}${video.filePath}';
        await _cacheManager.downloadFile(videoUrl);
      } catch (e) {
        debugPrint('Error caching video ${video.id}: $e');
      }
    }
  }

  Future<String> getVideoUrl(Video video) async {
    final videoUrl = '${ApiService.baseUrl.replaceAll('/api/v1', '')}${video.filePath}';
    
    try {
      // Проверить в кеше
      final fileInfo = await _cacheManager.getFileFromCache(videoUrl);
      if (fileInfo != null) {
        return fileInfo.file.path;
      }
      
      // Скачать если нет в кеше
      final file = await _cacheManager.getSingleFile(videoUrl);
      return file.path;
    } catch (e) {
      // Вернуть URL для стриминга если кеширование не удалось
      return videoUrl;
    }
  }

  void nextVideo() {
    if (_videos.isEmpty) return;
    
    _currentVideoIndex = (_currentVideoIndex + 1) % _videos.length;
    notifyListeners();
  }

  void previousVideo() {
    if (_videos.isEmpty) return;
    
    _currentVideoIndex = (_currentVideoIndex - 1 + _videos.length) % _videos.length;
    notifyListeners();
  }

  Future<void> refreshPlaylist() async {
    await _apiService.regeneratePlaylist();
    await loadPlaylist();
  }
}
