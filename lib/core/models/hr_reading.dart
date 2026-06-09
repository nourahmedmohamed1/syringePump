// lib/core/models/hr_reading.dart

enum HrSource { camera, sensor, fingerprint }

class HrReading {
  final double bpm;
  final DateTime timestamp;
  final HrSource source;

  HrReading({
    required this.bpm,
    required this.timestamp,
    this.source = HrSource.camera,
  });

  Map<String, dynamic> toMap() => {
        'bpm': bpm,
        'timestamp': timestamp.millisecondsSinceEpoch,
        'source': source.index,
      };

  factory HrReading.fromMap(Map<String, dynamic> map) => HrReading(
        bpm: (map['bpm'] as num).toDouble(),
        timestamp:
            DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
        source: HrSource.values[map['source'] as int],
      );
}
