class Video {
  final int id;
  final String title;
  final String filename;
  final String filePath;
  final int? fileSize;
  final double? duration;
  final String videoType;
  final int? playsPerHour;
  final String tariffs;
  final int priority;
  final bool isActive;
  final DateTime createdAt;

  Video({
    required this.id,
    required this.title,
    required this.filename,
    required this.filePath,
    this.fileSize,
    this.duration,
    required this.videoType,
    this.playsPerHour,
    required this.tariffs,
    required this.priority,
    required this.isActive,
    required this.createdAt,
  });

  factory Video.fromJson(Map<String, dynamic> json) {
    return Video(
      id: json['id'],
      title: json['title'],
      filename: json['filename'],
      filePath: json['file_path'],
      fileSize: json['file_size'],
      duration: json['duration']?.toDouble(),
      videoType: json['video_type'],
      playsPerHour: json['plays_per_hour'],
      tariffs: json['tariffs'],
      priority: json['priority'],
      isActive: json['is_active'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'filename': filename,
      'file_path': filePath,
      'file_size': fileSize,
      'duration': duration,
      'video_type': videoType,
      'plays_per_hour': playsPerHour,
      'tariffs': tariffs,
      'priority': priority,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
