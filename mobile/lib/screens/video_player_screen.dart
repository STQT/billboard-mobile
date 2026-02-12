import 'dart:async';
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
import '../models/playlist.dart';

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
  PlaylistPlayItem? _currentPlayItem;
  bool _isDisposing = false;
  VoidCallback? _videoEndListener;
  final Set<int> _failedVideoIds = {};
  bool _showStatusOverlay = true;
  Duration _playPosition = Duration.zero;
  Duration _playDuration = Duration.zero;
  Timer? _statusUpdateTimer;

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
    _statusUpdateTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (mounted &&
          !_isDisposing &&
          _controller != null &&
          _controller!.value.isInitialized) {
        setState(() {
          _playPosition = _controller!.value.position;
          _playDuration = _controller!.value.duration;
        });
      }
    });
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

    if (videoService.usePlayItems) {
      await _playNextPlayItem(videoService, analyticsService);
    } else {
      await _playNextVideoFromSequence(videoService, analyticsService);
    }
  }

  Future<void> _playNextPlayItem(
      VideoService videoService, AnalyticsService analyticsService) async {
    final item = _findNextPlayableItem(videoService);
    if (item == null) {
      debugPrint('No playable items (contract+filler list empty or all failed).');
      if (mounted) setState(() => _isInitializing = false);
      return;
    }

    if (_currentPlayItem != null &&
        _currentPlayItem!.videoId != item.videoId &&
        !_failedVideoIds.contains(_currentPlayItem!.videoId)) {
      await analyticsService.logVideoPlayback(
        videoId: _currentPlayItem!.videoId,
        completed: true,
      );
    }

    _currentVideo = null;
    _currentPlayItem = item;

    if (_videoEndListener != null && _controller != null) {
      _controller!.removeListener(_videoEndListener!);
      _videoEndListener = null;
    }
    await _controller?.dispose();
    _controller = null;
    if (_isDisposing || !mounted) return;

    final videoUrl = await videoService.getVideoUrlForPlayItem(item);
    if (_isDisposing || !mounted) return;

    if (videoUrl.startsWith('http')) {
      _controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
    } else {
      _controller = VideoPlayerController.file(File(videoUrl));
    }

    analyticsService.startVideoPlayback();

    try {
      await _controller!.initialize();
      if (_isDisposing || !mounted || _controller == null) return;
      if (!_controller!.value.isInitialized) {
        throw Exception('Video controller not initialized properly');
      }

      _controller!.setLooping(false);
      final startMs = (item.startTime * 1000).round();
      await _controller!.seekTo(Duration(milliseconds: startMs));
      _controller!.play();

      final endTimeSec = item.endTime;
      _videoEndListener = () {
        if (_controller == null || !_controller!.value.isInitialized) return;
        final posSec = _controller!.value.position.inMilliseconds / 1000.0;
        if (posSec >= endTimeSec - 0.1) _onVideoEnded();
      };
      _controller!.addListener(_videoEndListener!);

      _failedVideoIds.remove(item.videoId);
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error initializing play item ${item.videoId}: $e');
      final err = e.toString().toLowerCase();
      if (err.contains('format') ||
          err.contains('codec') ||
          err.contains('not supported') ||
          err.contains('osstatus') ||
          err.contains('-12847') ||
          err.contains('cannot open')) {
        _failedVideoIds.add(item.videoId);
      }
      await _controller?.dispose();
      _controller = null;
      if (mounted && !_isDisposing) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && !_isDisposing) {
            videoService.nextVideo();
            _playCurrentVideo();
          }
        });
      }
    }
  }

  Future<void> _playNextVideoFromSequence(
      VideoService videoService, AnalyticsService analyticsService) async {
    Video? video = _findNextPlayableVideo(videoService);
    if (video == null) {
      debugPrint(
          'No playable videos found. All videos failed or playlist is empty.');
      if (mounted) setState(() => _isInitializing = false);
      return;
    }

    if (_currentVideo != null &&
        _currentVideo!.id != video.id &&
        !_failedVideoIds.contains(_currentVideo!.id)) {
      await analyticsService.logVideoPlayback(
        videoId: _currentVideo!.id,
        completed: true,
      );
    }

    _currentPlayItem = null;
    _currentVideo = video;

    if (_videoEndListener != null && _controller != null) {
      _controller!.removeListener(_videoEndListener!);
      _videoEndListener = null;
    }
    await _controller?.dispose();
    _controller = null;
    if (_isDisposing || !mounted) return;

    final videoUrl = await videoService.getVideoUrl(video);
    if (_isDisposing || !mounted) return;

    if (videoUrl.startsWith('http')) {
      _controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
    } else {
      _controller = VideoPlayerController.file(File(videoUrl));
    }

    analyticsService.startVideoPlayback();

    try {
      await _controller!.initialize();
      if (_isDisposing || !mounted || _controller == null) return;
      if (!_controller!.value.isInitialized) {
        throw Exception('Video controller not initialized properly');
      }

      _controller!.setLooping(true);
      _controller!.play();

      _videoEndListener = () {
        if (_controller != null &&
            _controller!.value.isInitialized &&
            _controller!.value.position >= _controller!.value.duration &&
            _controller!.value.duration > Duration.zero) {
          _onVideoEnded();
        }
      };
      _controller!.addListener(_videoEndListener!);

      _failedVideoIds.remove(video.id);
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error initializing video ${video.id} (${video.title}): $e');
      final errorString = e.toString().toLowerCase();
      final isFormatError = errorString.contains('format') ||
          errorString.contains('codec') ||
          errorString.contains('not supported') ||
          errorString.contains('osstatus') ||
          errorString.contains('-12847') ||
          errorString.contains('cannot open');
      if (isFormatError) _failedVideoIds.add(video.id);
      await _controller?.dispose();
      _controller = null;
      if (mounted && !_isDisposing) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && !_isDisposing) {
            videoService.nextVideo();
            _playCurrentVideo();
          }
        });
      }
    }
  }

  PlaylistPlayItem? _findNextPlayableItem(VideoService videoService) {
    final list = videoService.playList;
    if (list.isEmpty) return null;
    final startIndex = videoService.currentVideoIndex;
    for (var i = 0; i < list.length; i++) {
      final index = (startIndex + i) % list.length;
      final item = list[index];
      if (!_failedVideoIds.contains(item.videoId)) {
        for (var k = 0; k < list.length && videoService.currentVideoIndex != index; k++) {
          videoService.nextVideo();
        }
        return item;
      }
    }
    return list.isNotEmpty ? list[0] : null;
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

    final videoId = _currentVideo?.id ?? _currentPlayItem?.videoId;
    if (videoId != null) {
      analyticsService.logVideoPlayback(videoId: videoId, completed: true);
    }

    videoService.nextVideo();
    _playCurrentVideo();
  }

  @override
  void dispose() {
    _isDisposing = true;
    _statusUpdateTimer?.cancel();
    _statusUpdateTimer = null;
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

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  /// Sekundlar bilan aniq vaqt (backend tekshiruvi uchun)
  String _formatDurationSeconds(Duration d) {
    final sec = d.inMilliseconds / 1000.0;
    return '${sec.toStringAsFixed(2)} s';
  }

  /// Hozirgi soat (soat:minut:sekund)
  static String _formatCurrentTime(DateTime t) {
    return '${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}:'
        '${t.second.toString().padLeft(2, '0')}';
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
              body: Stack(
                fit: StackFit.expand,
                children: [
                  if (_controller != null && _controller!.value.isInitialized)
                    IgnorePointer(
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: _controller!.value.aspectRatio,
                          child: VideoPlayer(_controller!),
                        ),
                      ),
                    )
                  else
                    const Center(
                      child: CircularProgressIndicator(color: Colors.white54),
                    ),
                  if (_showStatusOverlay)
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      child: GestureDetector(
                        onTap: () => setState(() => _showStatusOverlay = false),
                        behavior: HitTestBehavior.opaque,
                        child: Consumer<VideoService>(
                          builder: (context, videoService, _) {
                            final usePlayItems = videoService.usePlayItems;
                            final playList = videoService.playList;
                            final videos = videoService.videos;
                            final idx = videoService.currentVideoIndex;
                            final total = usePlayItems ? playList.length : videos.length;
                            final v = _currentVideo;
                            final item = _currentPlayItem;
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: const BoxDecoration(
                                color: Colors.black87,
                                border: Border(
                                  bottom: BorderSide(
                                      color: Colors.white24, width: 1),
                                ),
                              ),
                              child: SafeArea(
                                bottom: false,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Soat: ${_formatCurrentTime(DateTime.now())}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        fontFeatures: [
                                          FontFeature.tabularFigures()
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Ketma-ketlik: ${idx + 1} / $total',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        usePlayItems
                                            ? 'Rejim: contract+filler (har biri 1 marta)'
                                            : 'Rejim: video_sequence',
                                        style: const TextStyle(
                                          color: Colors.amberAccent,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                    if (item != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'ID: ${item.videoId}  •  segment ${item.startTime.toStringAsFixed(1)}–${item.endTime.toStringAsFixed(1)} s',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                    if (v != null) ...[
                                      const SizedBox(height: 4),
                                      Builder(
                                        builder: (context) {
                                          final timesInPlaylist = videos.where((e) => e.id == v.id).length;
                                          return Padding(
                                            padding: const EdgeInsets.only(bottom: 4),
                                            child: Text(
                                              'Bu video (ID ${v.id}) pleylistda: $timesInPlaylist marta',
                                              style: const TextStyle(
                                                color: Colors.orangeAccent,
                                                fontSize: 11,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                      Text(
                                        'ID: ${v.id}  •  ${v.title}',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                    const SizedBox(height: 4),
                                    Text(
                                      'Vaqt: ${_formatDuration(_playPosition)} / ${_formatDuration(_playDuration)}  '
                                      '(${_formatDurationSeconds(_playPosition)} / ${_formatDurationSeconds(_playDuration)})',
                                      style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 12,
                                      ),
                                    ),
                                    if (_failedVideoIds.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          'O\'tkazib yuborilgan: ${_failedVideoIds.length}',
                                          style: const TextStyle(
                                            color: Colors.orangeAccent,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Statusni yopish uchun bosing',
                                      style: TextStyle(
                                        color:
                                            Colors.white.withValues(alpha: 0.5),
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  if (!_showStatusOverlay)
                    Positioned(
                      right: 12,
                      top: 0,
                      child: SafeArea(
                        bottom: false,
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _showStatusOverlay = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Status',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
