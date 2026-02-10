import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';

import '../services/auth_service.dart';
import '../services/video_service.dart';
import '../services/analytics_service.dart';
import '../models/video.dart';

class VideoPlayerScreen extends StatefulWidget {
  const VideoPlayerScreen({super.key});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  VideoPlayerController? _controller;
  bool _isInitializing = true;
  Video? _currentVideo;
  bool _isDisposing = false;
  VoidCallback? _videoEndListener;
  Set<int> _failedVideoIds = {}; // Отслеживание видео, которые не удалось воспроизвести

  @override
  void initState() {
    super.initState();
    _initialize();
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
      debugPrint('No playable videos found. All videos failed or playlist is empty.');
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
      
      _controller!.setLooping(false);
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
        debugPrint('Video format not supported by iOS, marking as failed and skipping');
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
    final maxAttempts = videos.length * 2; // Даем два полных прохода по плейлисту
    
    // Попробовать найти видео, которое еще не было помечено как неудачное
    while (attempts < maxAttempts) {
      final index = (startIndex + attempts) % videos.length;
      final video = videos[index];
      
      if (!_failedVideoIds.contains(video.id)) {
        // Установить индекс на найденное видео
        while (videoService.currentVideoIndex != index && attempts < maxAttempts) {
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
    
    // Удалить listener перед dispose
    if (_videoEndListener != null && _controller != null) {
      _controller!.removeListener(_videoEndListener!);
      _videoEndListener = null;
    }
    
    _controller?.dispose();
    _controller = null;
    
    // Завершить сессию при выходе
    try {
      context.read<AnalyticsService>().endSession();
    } catch (e) {
      debugPrint('Error ending session: $e');
    }
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Загрузка плейлиста...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Video Player
          Center(
            child: _controller != null && _controller!.value.isInitialized
                ? AspectRatio(
                    aspectRatio: _controller!.value.aspectRatio,
                    child: VideoPlayer(_controller!),
                  )
                : const CircularProgressIndicator(),
          ),
          
          // Overlay with info
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: _buildOverlay(),
          ),
          
          // Control buttons (hidden by default, show on tap)
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: _buildControls(),
          ),
        ],
      ),
    );
  }

  Widget _buildOverlay() {
    final authService = context.watch<AuthService>();
    final videoService = context.watch<VideoService>();
    final analyticsService = context.watch<AnalyticsService>();
    final vehicle = authService.currentVehicle;
    final video = videoService.currentVideo;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                vehicle?.carNumber ?? '',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Тариф: ${vehicle?.tariff ?? ''}',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              if (video != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Видео: ${video.title}',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    if (_failedVideoIds.isNotEmpty)
                      Text(
                        'Пропущено видео: ${_failedVideoIds.length}',
                        style: const TextStyle(color: Colors.orange, fontSize: 10),
                      ),
                  ],
                ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Видео: ${videoService.currentVideoIndex + 1}/${videoService.videos.length}',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              if (analyticsService.hasActiveSession)
                Text(
                  'Время: ${_formatDuration(analyticsService.getSessionDuration())}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    final authService = context.read<AuthService>();
    final videoService = context.read<VideoService>();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          icon: const Icon(Icons.skip_previous, color: Colors.white, size: 32),
          onPressed: () async {
            videoService.previousVideo();
            await _playCurrentVideo();
          },
        ),
        IconButton(
          icon: Icon(
            _controller?.value.isPlaying ?? false ? Icons.pause : Icons.play_arrow,
            color: Colors.white,
            size: 48,
          ),
          onPressed: () {
            if (_controller?.value.isPlaying ?? false) {
              _controller?.pause();
            } else {
              _controller?.play();
            }
            setState(() {});
          },
        ),
        IconButton(
          icon: const Icon(Icons.skip_next, color: Colors.white, size: 32),
          onPressed: () async {
            videoService.nextVideo();
            await _playCurrentVideo();
          },
        ),
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white, size: 32),
          onPressed: () async {
            await videoService.refreshPlaylist();
            await _playCurrentVideo();
          },
        ),
        IconButton(
          icon: const Icon(Icons.logout, color: Colors.white, size: 32),
          onPressed: () {
            authService.logout();
          },
        ),
      ],
    );
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return '00:00:00';
    
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    
    return '$hours:$minutes:$seconds';
  }
}
