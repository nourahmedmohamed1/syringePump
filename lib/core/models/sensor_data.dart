// lib/core/models/sensor_data.dart

class SensorData {
  final double flowRate;     // Flowmeter: actual mL/hr
  final double fsrPressure;  // FSR: 0-1023 analog value
  final bool irBlocked;      // IR: true = syringe empty / plunger at end
  final double heartRate;    // Pulse Sensor: BPM
  final DateTime timestamp;

  SensorData({
    required this.flowRate,
    required this.fsrPressure,
    required this.irBlocked,
    required this.heartRate,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Demo / mock data
  factory SensorData.demo() => SensorData(
        flowRate: 12.5,
        fsrPressure: 120,
        irBlocked: false,
        heartRate: 78,
      );

  /// Empty (initial) state
  factory SensorData.empty() => SensorData(
        flowRate: 0,
        fsrPressure: 0,
        irBlocked: false,
        heartRate: 0,
      );

  Map<String, dynamic> toMap() => {
        'flow_rate': flowRate,
        'fsr_pressure': fsrPressure,
        'ir_blocked': irBlocked ? 1 : 0,
        'heart_rate': heartRate,
        'timestamp': timestamp.millisecondsSinceEpoch,
      };

  factory SensorData.fromMap(Map<String, dynamic> map) => SensorData(
        flowRate: (map['flow_rate'] as num).toDouble(),
        fsrPressure: (map['fsr_pressure'] as num).toDouble(),
        irBlocked: map['ir_blocked'] == 1,
        heartRate: (map['heart_rate'] as num).toDouble(),
        timestamp:
            DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      );
}
