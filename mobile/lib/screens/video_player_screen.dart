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
  VideoPlayerController? _oldController; // Smooth transition uchun eski controller
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
  int? _lastPlayedVideoId; // Oxirgi o'ynatilgan video ID ni tracking qilish
  bool _isTransitioning = false; // Video o'tish jarayonida

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
    _lastPlayedVideoId = item.videoId; // Oxirgi o'ynatilgan video ID ni saqlash

    // Eski controller ni saqlash (smooth transition uchun)
    if (_videoEndListener != null && _controller != null) {
      _controller!.removeListener(_videoEndListener!);
      _videoEndListener = null;
    }
    _oldController = _controller;
    _controller = null;
    if (_isDisposing || !mounted) return;

    final videoUrl = await videoService.getVideoUrlForPlayItem(item);
    if (_isDisposing || !mounted) return;

    // Yangi controller yaratish
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
      await _controller!.play();

      final endTimeSec = item.endTime;
      _videoEndListener = () {
        if (_controller == null || !_controller!.value.isInitialized) return;
        final posSec = _controller!.value.position.inMilliseconds / 1000.0;
        // 300ms oldin keyingi videoga o'tish (smooth transition)
        if (posSec >= endTimeSec - 0.3) _onVideoEnded();
      };
      _controller!.addListener(_videoEndListener!);

      _failedVideoIds.remove(item.videoId);
      _isTransitioning = false; // O'tish tugadi
      
      // Eski controller ni background da dispose qilish
      if (_oldController != null) {
        _oldController!.dispose();
        _oldController = null;
      }
      
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error initializing play item ${item.videoId}: $e');
      _isTransitioning = false; // Error bo'lsa ham reset qilish
      final err = e.toString().toLowerCase();
      if (err.contains('format') ||
          err.contains('codec') ||
          err.contains('not supported') ||
          err.contains('osstatus') ||
          err.contains('-12847') ||
          err.contains('cannot open')) {
        _failedVideoIds.add(item.videoId);
      }
      _controller?.dispose();
      _controller = _oldController; // Eski controller ga qaytish
      _oldController = null;
      if (mounted && !_isDisposing) {
        Future.delayed(const Duration(milliseconds: 200), () {
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
    _lastPlayedVideoId = video.id; // Oxirgi o'ynatilgan video ID ni saqlash

    // Eski controller ni saqlash (smooth transition uchun)
    if (_videoEndListener != null && _controller != null) {
      _controller!.removeListener(_videoEndListener!);
      _videoEndListener = null;
    }
    _oldController = _controller;
    _controller = null;
    if (_isDisposing || !mounted) return;

    final videoUrl = await videoService.getVideoUrl(video);
    if (_isDisposing || !mounted) return;

    // Yangi controller yaratish
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
      await _controller!.play();

      _videoEndListener = () {
        if (_controller == null || !_controller!.value.isInitialized) return;
        final position = _controller!.value.position;
        final duration = _controller!.value.duration;
        
        // 300ms oldin keyingi videoga o'tish (smooth transition)
        if (duration > Duration.zero && position >= duration - const Duration(milliseconds: 300)) {
          _onVideoEnded();
        }
      };
      _controller!.addListener(_videoEndListener!);

      _failedVideoIds.remove(video.id);
      _isTransitioning = false; // O'tish tugadi
      
      // Eski controller ni background da dispose qilish
      if (_oldController != null) {
        _oldController!.dispose();
        _oldController = null;
      }
      
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error initializing video ${video.id} (${video.title}): $e');
      _isTransitioning = false; // Error bo'lsa ham reset qilish
      final errorString = e.toString().toLowerCase();
      final isFormatError = errorString.contains('format') ||
          errorString.contains('codec') ||
          errorString.contains('not supported') ||
          errorString.contains('osstatus') ||
          errorString.contains('-12847') ||
          errorString.contains('cannot open');
      if (isFormatError) _failedVideoIds.add(video.id);
      _controller?.dispose();
      _controller = _oldController; // Eski controller ga qaytish
      _oldController = null;
      if (mounted && !_isDisposing) {
        Future.delayed(const Duration(milliseconds: 200), () {
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
      
      // Video failed bo'lmasligi VA oxirgi o'ynatilgan video bo'lmasligi kerak
      // (agar playlist > 1 bo'lsa)
      final shouldSkipBecauseSameAsLast = 
          list.length > 1 && _lastPlayedVideoId != null && item.videoId == _lastPlayedVideoId && i == 0;
      
      if (!_failedVideoIds.contains(item.videoId) && !shouldSkipBecauseSameAsLast) {
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

      // Video failed bo'lmasligi VA oxirgi o'ynatilgan video bo'lmasligi kerak
      // (agar playlist > 1 bo'lsa)
      final shouldSkipBecauseSameAsLast = 
          videos.length > 1 && _lastPlayedVideoId != null && video.id == _lastPlayedVideoId;

      if (!_failedVideoIds.contains(video.id) && !shouldSkipBecauseSameAsLast) {
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
    if (_isDisposing || !mounted || _isTransitioning) return;
    
    _isTransitioning = true; // Bir marta trigger bo'lishi uchun

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
    
    _oldController?.dispose();
    _oldController = null;

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

  /// Hozirgi soat (soat:minut:sekund)
  static String _formatCurrentTime(DateTime t) {
    return '${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}:'
        '${t.second.toString().padLeft(2, '0')}';
  }

  /// Ma'lumot qatori
  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
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
                    Positioned.fill(
                      child: GestureDetector(
                        onTap: () => setState(() => _showStatusOverlay = false),
                        child: Container(
                          color: Colors.black.withOpacity(0.85),
                          child: Consumer<VideoService>(
                            builder: (context, videoService, _) {
                              final usePlayItems = videoService.usePlayItems;
                              final playList = videoService.playList;
                              final videos = videoService.videos;
                              final idx = videoService.currentVideoIndex;
                              final total = usePlayItems ? playList.length : videos.length;
                              final v = _currentVideo;
                              final item = _currentPlayItem;
                              
                              // Keyingi video
                              final nextIndex = (idx + 1) % total;
                              final nextItem = usePlayItems && playList.isNotEmpty 
                                  ? playList[nextIndex] 
                                  : null;
                              final nextVideo = !usePlayItems && videos.isNotEmpty 
                                  ? videos[nextIndex] 
                                  : null;

                              // Contract yoki Filler ekanligini aniqlash
                              bool isCurrentContract = false;
                              bool isNextContract = false;
                              if (usePlayItems && videoService.currentPlaylist != null) {
                                final contractVideoIds = videoService.currentPlaylist!.contractVideos
                                    .map((c) => c.videoId)
                                    .toSet();
                                if (item != null) {
                                  isCurrentContract = contractVideoIds.contains(item.videoId);
                                }
                                if (nextItem != null) {
                                  isNextContract = contractVideoIds.contains(nextItem.videoId);
                                }
                              }

                              return SafeArea(
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // ═══════════════════════════════════════
                                      // HEADER
                                      // ═══════════════════════════════════════
                                      const Text(
                                        '🎬 Billboard Player Status',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 16),

                                      // ═══════════════════════════════════════
                                      // HOZIRGI VAQT
                                      // ═══════════════════════════════════════
                                      _buildInfoRow('🕐 Soat', _formatCurrentTime(DateTime.now())),
                                      _buildInfoRow('📍 Pozitsiya', '${idx + 1} / $total'),
                                      _buildInfoRow('🎯 Rejim', usePlayItems ? 'Contract + Filler' : 'Video Sequence'),
                                      
                                      const Divider(color: Colors.white38, height: 24),

                                      // ═══════════════════════════════════════
                                      // HOZIRGI VIDEO
                                      // ═══════════════════════════════════════
                                      Row(
                                        children: [
                                          Text(
                                            isCurrentContract
                                                ? '📺 Contract Video'
                                                : '🎞️ ${usePlayItems ? "Filler Video" : "Video"}',
                                            style: TextStyle(
                                              color: isCurrentContract
                                                  ? Colors.green
                                                  : Colors.orange,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      
                                      if (item != null) ...[
                                        _buildInfoRow('Video ID', item.videoId.toString()),
                                        _buildInfoRow('Pozitsiya', _formatDuration(_playPosition)),
                                        _buildInfoRow('Duration', _formatDuration(_playDuration)),
                                        if (isCurrentContract)
                                          _buildInfoRow(
                                            'Segment',
                                            '${item.startTime.toStringAsFixed(1)}s - ${item.endTime.toStringAsFixed(1)}s',
                                          ),
                                      ] else if (v != null) ...[
                                        _buildInfoRow('Video ID', v.id.toString()),
                                        _buildInfoRow('Nomi', v.title),
                                        _buildInfoRow('Pozitsiya', _formatDuration(_playPosition)),
                                        _buildInfoRow('Duration', _formatDuration(_playDuration)),
                                      ],

                                      if (_failedVideoIds.isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        _buildInfoRow('❌ O\'tkazilgan', '${_failedVideoIds.length} ta', valueColor: Colors.red),
                                      ],

                                      // ═══════════════════════════════════════
                                      // KEYINGI VIDEO
                                      // ═══════════════════════════════════════
                                      if (nextItem != null || nextVideo != null) ...[
                                        const Divider(color: Colors.white38, height: 24),
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.withOpacity(0.2),
                                            border: Border.all(color: Colors.blue, width: 2),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                isNextContract
                                                    ? '⏭️ Keyingi Contract Video'
                                                    : '⏭️ Keyingi ${usePlayItems ? "Filler" : "Video"}',
                                                style: const TextStyle(
                                                  color: Colors.blue,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              if (nextItem != null) ...[
                                                _buildInfoRow('Video ID', nextItem.videoId.toString()),
                                                _buildInfoRow(
                                                  'Duration',
                                                  '${(nextItem.endTime - nextItem.startTime).toStringAsFixed(1)}s',
                                                ),
                                                if (isNextContract)
                                                  _buildInfoRow(
                                                    'Segment',
                                                    '${nextItem.startTime.toStringAsFixed(1)}-${nextItem.endTime.toStringAsFixed(1)}s',
                                                  ),
                                                _buildInfoRow(
                                                  '⏱️ Boshlanadi',
                                                  '${(_playDuration.inMilliseconds / 1000 - _playPosition.inMilliseconds / 1000).toStringAsFixed(1)}s ichida',
                                                  valueColor: Colors.greenAccent,
                                                ),
                                              ] else if (nextVideo != null) ...[
                                                _buildInfoRow('Video ID', nextVideo.id.toString()),
                                                _buildInfoRow('Nomi', nextVideo.title),
                                                _buildInfoRow(
                                                  '⏱️ Boshlanadi',
                                                  '${(_playDuration.inMilliseconds / 1000 - _playPosition.inMilliseconds / 1000).toStringAsFixed(1)}s ichida',
                                                  valueColor: Colors.greenAccent,
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],

                                      const Divider(color: Colors.white38, height: 24),

                                      // ═══════════════════════════════════════
                                      // PLAYLIST STATISTIKA
                                      // ═══════════════════════════════════════
                                      const Text(
                                        '📊 Playlist Statistika',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      if (usePlayItems) ...[
                                        _buildInfoRow('Contract', '${videoService.currentPlaylist?.contractVideos.length ?? 0} ta'),
                                        _buildInfoRow('Filler', '${videoService.currentPlaylist?.fillerVideos.length ?? 0} ta'),
                                      ] else ...[
                                        _buildInfoRow('Videolar', '$total ta'),
                                      ],
                                      _buildInfoRow('Jami', '$total ta video'),
                                      _buildInfoRow('💾 Rejim', 'OFFLINE-READY', valueColor: Colors.greenAccent),

                                      const SizedBox(height: 24),

                                      // ═══════════════════════════════════════
                                      // YOPISH
                                      // ═══════════════════════════════════════
                                      Center(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.touch_app, color: Colors.white, size: 20),
                                              SizedBox(width: 8),
                                              Text(
                                                'Yopish uchun bosing',
                                                style: TextStyle(color: Colors.white),
                                              ),
                                            ],
                                          ),
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
                    ),
                  if (!_showStatusOverlay)
                    Positioned(
                      right: 12,
                      top: 12,
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _showStatusOverlay = true),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.3),
                            border: Border.all(color: Colors.green.withOpacity(0.6), width: 1),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.green.withOpacity(0.2),
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.info_outline, color: Colors.green, size: 14),
                              SizedBox(width: 4),
                              Text(
                                'Status',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
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
