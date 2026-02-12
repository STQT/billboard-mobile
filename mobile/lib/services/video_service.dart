import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'api_service.dart';
import '../models/video.dart';
import '../models/playlist.dart';

class VideoService extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final DefaultCacheManager _cacheManager = DefaultCacheManager();

  Playlist? _currentPlaylist;
  /// Backend dan contract_videos + filler_videos orqali qurilgan ro‘yxat (yoki video_sequence bo‘lsa eski ro‘yxat).
  List<PlaylistPlayItem> _playList = [];
  List<Video> _videos = []; // video_sequence rejimida ishlatiladi
  int _currentVideoIndex = 0;
  bool _isLoading = false;
  bool _usePlayItems = false; // true = contract+filler ro‘yxati ishlatiladi

  Playlist? get currentPlaylist => _currentPlaylist;
  List<PlaylistPlayItem> get playList => _playList;
  List<Video> get videos => _videos;
  int get currentVideoIndex => _currentVideoIndex;
  bool get usePlayItems => _usePlayItems;
  bool get isLoading => _isLoading;

  /// Joriy o‘ynatiladigan element (contract+filler rejimida).
  PlaylistPlayItem? get currentPlayItem {
    if (_playList.isEmpty || _currentVideoIndex >= _playList.length) return null;
    return _playList[_currentVideoIndex];
  }

  Video? get currentVideo {
    if (_videos.isEmpty || _currentVideoIndex >= _videos.length) return null;
    return _videos[_currentVideoIndex];
  }

  Future<void> loadPlaylist() async {
    try {
      _isLoading = true;
      notifyListeners();

      final playlistData = await _apiService.getCurrentPlaylist();
      _currentPlaylist = Playlist.fromJson(playlistData);

      if (_currentPlaylist!.videoSequence.isNotEmpty) {
        _usePlayItems = false;
        await _loadVideosFromSequence();
      } else {
        _usePlayItems = true;
        _playList = _currentPlaylist!.buildPlayItemsFromContractAndFiller();
        _videos = [];
        _cachePlayListUrls();
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _loadVideosFromSequence() async {
    if (_currentPlaylist == null) return;
    final uniqueVideoIds = _currentPlaylist!.allVideoIds;
    final videoFutures = uniqueVideoIds.map((id) => _apiService.getVideo(id));
    final videoDataList = await Future.wait(videoFutures);
    final videoMap = <int, Video>{};
    for (var videoData in videoDataList) {
      final video = Video.fromJson(videoData);
      videoMap[video.id] = video;
    }
    _videos = _currentPlaylist!.videoSequence
        .where((id) => videoMap.containsKey(id))
        .map((id) => videoMap[id]!)
        .toList();
    _playList = [];
    _cacheVideos();
  }

  Future<void> _cacheVideos() async {
    for (var video in _videos) {
      try {
        final videoUrl = '${ApiService.baseUrl.replaceAll('/api/v1', '')}${video.filePath}';
        await _cacheManager.downloadFile(videoUrl);
      } catch (e) {
        debugPrint('Error caching video ${video.id}: $e');
      }
    }
  }

  Future<void> _cachePlayListUrls() async {
    for (var item in _playList) {
      try {
        await _cacheManager.downloadFile(item.mediaUrl);
      } catch (e) {
        debugPrint('Error caching ${item.mediaUrl}: $e');
      }
    }
  }

  Future<String> getVideoUrl(Video video) async {
    final videoUrl = '${ApiService.baseUrl.replaceAll('/api/v1', '')}${video.filePath}';
    try {
      final fileInfo = await _cacheManager.getFileFromCache(videoUrl);
      if (fileInfo != null) return fileInfo.file.path;
      final file = await _cacheManager.getSingleFile(videoUrl);
      return file.path;
    } catch (e) {
      return videoUrl;
    }
  }

  Future<String> getVideoUrlForPlayItem(PlaylistPlayItem item) async {
    try {
      final fileInfo = await _cacheManager.getFileFromCache(item.mediaUrl);
      if (fileInfo != null) return fileInfo.file.path;
      final file = await _cacheManager.getSingleFile(item.mediaUrl);
      return file.path;
    } catch (e) {
      return item.mediaUrl;
    }
  }

  void nextVideo() {
    final len = _usePlayItems ? _playList.length : _videos.length;
    if (len == 0) return;
    _currentVideoIndex = (_currentVideoIndex + 1) % len;
    notifyListeners();
  }

  void previousVideo() {
    final len = _usePlayItems ? _playList.length : _videos.length;
    if (len == 0) return;
    _currentVideoIndex = (_currentVideoIndex - 1 + len) % len;
    notifyListeners();
  }

  Future<void> refreshPlaylist() async {
    await _apiService.regeneratePlaylist();
    await loadPlaylist();
  }
}
