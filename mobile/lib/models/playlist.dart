class Playlist {
  final int id;
  final int vehicleId;
  final String tariff;
  final List<int> videoSequence;
  final DateTime validFrom;
  final DateTime validUntil;
  final DateTime createdAt;

  Playlist({
    required this.id,
    required this.vehicleId,
    required this.tariff,
    required this.videoSequence,
    required this.validFrom,
    required this.validUntil,
    required this.createdAt,
  });

  factory Playlist.fromJson(Map<String, dynamic> json) {
    return Playlist(
      id: json['id'],
      vehicleId: json['vehicle_id'],
      tariff: json['tariff'],
      videoSequence: List<int>.from(json['video_sequence']),
      validFrom: DateTime.parse(json['valid_from']),
      validUntil: DateTime.parse(json['valid_until']),
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  bool isValid() {
    final now = DateTime.now();
    return now.isAfter(validFrom) && now.isBefore(validUntil);
  }
}
