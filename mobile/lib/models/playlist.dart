class ContractVideoItem {
  final int videoId;
  final double startTime; // Время начала в секундах от начала часа (0-3600)
  final double endTime;   // Время окончания в секундах от начала часа (0-3600)
  final double duration;  // Длительность в секундах
  final int frequency;    // Количество повторений этого видео в плейлисте
  final String filePath;  // Путь к файлу (например, /videos/filename.mp4)
  final String mediaUrl; // Полный URL для доступа к медиа файлу

  ContractVideoItem({
    required this.videoId,
    required this.startTime,
    required this.endTime,
    required this.duration,
    required this.frequency,
    required this.filePath,
    required this.mediaUrl,
  });

  factory ContractVideoItem.fromJson(Map<String, dynamic> json) {
    return ContractVideoItem(
      videoId: json['video_id'],
      startTime: (json['start_time'] as num).toDouble(),
      endTime: (json['end_time'] as num).toDouble(),
      duration: (json['duration'] as num).toDouble(),
      frequency: json['frequency'] ?? 1,
      filePath: json['file_path'] ?? '',
      mediaUrl: json['media_url'] ?? '',
    );
  }
}

class FillerVideoItem {
  final int videoId;
  final double duration; // Длительность в секундах
  final String filePath; // Путь к файлу (например, /videos/filename.mp4)
  final String mediaUrl; // Полный URL для доступа к медиа файлу

  FillerVideoItem({
    required this.videoId,
    required this.duration,
    required this.filePath,
    required this.mediaUrl,
  });

  factory FillerVideoItem.fromJson(Map<String, dynamic> json) {
    return FillerVideoItem(
      videoId: json['video_id'],
      duration: (json['duration'] as num).toDouble(),
      filePath: json['file_path'] ?? '',
      mediaUrl: json['media_url'] ?? '',
    );
  }
}

class Playlist {
  final int id;
  final int? vehicleId; // null для плейлиста по тарифу
  final String tariff;
  final List<ContractVideoItem> contractVideos;
  final List<FillerVideoItem> fillerVideos;
  final double totalDuration; // Общая длительность плейлиста в секундах (3600 для часового)
  final DateTime validFrom;
  final DateTime validUntil;
  final DateTime createdAt;

  Playlist({
    required this.id,
    this.vehicleId, // Теперь опциональный
    required this.tariff,
    required this.contractVideos,
    required this.fillerVideos,
    required this.totalDuration,
    required this.validFrom,
    required this.validUntil,
    required this.createdAt,
  });

  factory Playlist.fromJson(Map<String, dynamic> json) {
    return Playlist(
      id: json['id'],
      vehicleId: json['vehicle_id'], // Может быть null
      tariff: json['tariff'],
      contractVideos: (json['contract_videos'] as List<dynamic>?)
          ?.map((item) => ContractVideoItem.fromJson(item))
          .toList() ?? [],
      fillerVideos: (json['filler_videos'] as List<dynamic>?)
          ?.map((item) => FillerVideoItem.fromJson(item))
          .toList() ?? [],
      totalDuration: (json['total_duration'] as num?)?.toDouble() ?? 3600.0,
      validFrom: DateTime.parse(json['valid_from']),
      validUntil: DateTime.parse(json['valid_until']),
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  bool isValid() {
    final now = DateTime.now();
    return now.isAfter(validFrom) && now.isBefore(validUntil);
  }

  /// Проверить, является ли плейлист общим по тарифу
  bool get isTariffBased => vehicleId == null;
  
  /// Получить список всех ID видео (контрактные + филлеры)
  List<int> get allVideoIds {
    final ids = <int>[];
    ids.addAll(contractVideos.map((v) => v.videoId));
    ids.addAll(fillerVideos.map((v) => v.videoId));
    return ids;
  }
}
