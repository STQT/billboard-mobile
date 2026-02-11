import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:kiosk_mode/kiosk_mode.dart';

import '../services/video_service.dart';
import '../services/analytics_service.dart';
import '../models/video.dart';

class VideoPlayerScreen extends StatefulWidget {
  const VideoPlayerScreen({super.key});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  bool _isInitializing = true;
  Video? _currentVideo;
  bool _isDisposing = false;
  VoidCallback? _videoEndListener;
  Set<int> _failedVideoIds = {};

  void _applyImmersiveAndKiosk() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ));
    startKioskMode();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WakelockPlus.enable();
    _applyImmersiveAndKiosk();
    _initialize();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isDisposing) return;
    switch (state) {
      case AppLifecycleState.resumed:
        _applyImmersiveAndKiosk();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
        // Foydalanuvchi chiqishga urinsa, qayta kiosk va immersive qo'llash
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted && !_isDisposing) _applyImmersiveAndKiosk();
        });
        break;
      default:
        break;
    }
  }

  Future<void> _initialize() async {
    final videoService = context.read<VideoService>();
    final analyticsService = context.read<AnalyticsService>();

    try {
      // Начать сессию
      await analyticsService.startSession();

      // Загрузить плейлист
      await videoService.loadPlaylist();

      // Сбросить список неудачных видео при загрузке нового плейлиста
      _failedVideoIds.clear();

      // Начать воспроизведение первого видео
      await _playCurrentVideo();
    } catch (e) {
      debugPrint('Error initializing video player: $e');
    } finally {
      if (mounted) {
        setState(() => _isInitializing = false);
      }
    }
  }

  Future<void> _playCurrentVideo() async {
    if (_isDisposing || !mounted) return;

    final videoService = context.read<VideoService>();
    final analyticsService = context.read<AnalyticsService>();

    // Найти следующее доступное видео (пропуская те, что уже не удалось воспроизвести)
    Video? video = _findNextPlayableVideo(videoService);

    if (video == null) {
      debugPrint(
          'No playable videos found. All videos failed or playlist is empty.');
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
      return;
    }

    // Логировать предыдущее видео если было (и оно было успешно воспроизведено)
    if (_currentVideo != null &&
        _currentVideo!.id != video.id &&
        !_failedVideoIds.contains(_currentVideo!.id)) {
      await analyticsService.logVideoPlayback(
        videoId: _currentVideo!.id,
        completed: true,
      );
    }

    _currentVideo = video;

    // Удалить старый listener если есть
    if (_videoEndListener != null && _controller != null) {
      _controller!.removeListener(_videoEndListener!);
      _videoEndListener = null;
    }

    // Dispose old controller
    await _controller?.dispose();
    _controller = null;

    if (_isDisposing || !mounted) return;

    // Получить URL видео (из кеша или сервера)
    final videoUrl = await videoService.getVideoUrl(video);

    if (_isDisposing || !mounted) return;

    // Создать новый controller
    if (videoUrl.startsWith('http')) {
      _controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
    } else {
      _controller = VideoPlayerController.file(File(videoUrl));
    }

    // Начать отслеживание воспроизведения
    analyticsService.startVideoPlayback();

    try {
      await _controller!.initialize();

      if (_isDisposing || !mounted || _controller == null) return;

      // Проверить что видео действительно инициализировано
      if (!_controller!.value.isInitialized) {
        throw Exception('Video controller not initialized properly');
      }

      _controller!.setLooping(true);
      _controller!.play();

      // Создать и добавить слушателя для окончания видео
      _videoEndListener = () {
        if (_controller != null &&
            _controller!.value.isInitialized &&
            _controller!.value.position >= _controller!.value.duration &&
            _controller!.value.duration > Duration.zero) {
          _onVideoEnded();
        }
      };
      _controller!.addListener(_videoEndListener!);

      // Успешно воспроизводится - убрать из списка неудачных если был там
      _failedVideoIds.remove(video.id);

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error initializing video ${video.id} (${video.title}): $e');

      // Проверить тип ошибки
      final errorString = e.toString().toLowerCase();
      final isFormatError = errorString.contains('format') ||
          errorString.contains('codec') ||
          errorString.contains('not supported') ||
          errorString.contains('osstatus') ||
          errorString.contains('-12847') ||
          errorString.contains('cannot open');

      if (isFormatError) {
        debugPrint(
            'Video format not supported by iOS, marking as failed and skipping');
        _failedVideoIds.add(video.id);
      }

      // Очистить controller
      await _controller?.dispose();
      _controller = null;

      if (mounted && !_isDisposing) {
        // Попробовать следующее видео при ошибке
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && !_isDisposing) {
            videoService.nextVideo();
            _playCurrentVideo();
          }
        });
      }
    }
  }

  /// Найти следующее видео, которое можно воспроизвести
  Video? _findNextPlayableVideo(VideoService videoService) {
    final videos = videoService.videos;
    if (videos.isEmpty) return null;

    final startIndex = videoService.currentVideoIndex;
    int attempts = 0;
    final maxAttempts =
        videos.length * 2; // Даем два полных прохода по плейлисту

    // Попробовать найти видео, которое еще не было помечено как неудачное
    while (attempts < maxAttempts) {
      final index = (startIndex + attempts) % videos.length;
      final video = videos[index];

      if (!_failedVideoIds.contains(video.id)) {
        // Установить индекс на найденное видео
        while (
            videoService.currentVideoIndex != index && attempts < maxAttempts) {
          videoService.nextVideo();
          attempts++;
        }
        return video;
      }

      attempts++;
    }

    // Если все видео были неудачными, попробовать первое доступное
    if (videos.isNotEmpty) {
      debugPrint('All videos marked as failed, trying first video anyway');
      return videos[0];
    }

    return null;
  }

  void _onVideoEnded() {
    if (_isDisposing || !mounted) return;

    final videoService = context.read<VideoService>();
    final analyticsService = context.read<AnalyticsService>();

    // Логировать завершение текущего видео
    if (_currentVideo != null) {
      analyticsService.logVideoPlayback(
        videoId: _currentVideo!.id,
        completed: true,
      );
    }

    // Переключиться на следующее видео
    videoService.nextVideo();
    _playCurrentVideo();
  }

  @override
  void dispose() {
    _isDisposing = true;
    WidgetsBinding.instance.removeObserver(this);
    WakelockPlus.disable();
    stopKioskMode();

    if (_videoEndListener != null && _controller != null) {
      _controller!.removeListener(_videoEndListener!);
      _videoEndListener = null;
    }

    _controller?.dispose();
    _controller = null;

    try {
      context.read<AnalyticsService>().endSession();
    } catch (e) {
      debugPrint('Error ending session: $e');
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: _isInitializing
          ? const Scaffold(
              backgroundColor: Colors.black,
              body: Center(
                child: CircularProgressIndicator(color: Colors.white54),
              ),
            )
          : Scaffold(
              backgroundColor: Colors.black,
              body: _controller != null && _controller!.value.isInitialized
                  ? IgnorePointer(
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: _controller!.value.aspectRatio,
                          child: VideoPlayer(_controller!),
                        ),
                      ),
                    )
                  : const Center(
                      child: CircularProgressIndicator(color: Colors.white54),
                    ),
            ),
    );
  }
}
