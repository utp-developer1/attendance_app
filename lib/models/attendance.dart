class Attendance {
  final String id;
  final String event; // 'check-in' or 'check-out'
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final String locationType; // In-Office, Work From Home, Alternate Location, etc.

  Attendance({
    required this.id,
    required this.event,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    required this.locationType,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'event': event,
        'timestamp': timestamp.toIso8601String(),
        'latitude': latitude,
        'longitude': longitude,
        'locationType': locationType,
      };

  factory Attendance.fromJson(Map<String, dynamic> j) => Attendance(
        id: j['id'] as String,
        event: j['event'] as String,
        timestamp: DateTime.parse(j['timestamp'] as String),
        latitude: (j['latitude'] as num).toDouble(),
        longitude: (j['longitude'] as num).toDouble(),
        locationType: j['locationType'] as String,
      );
}
