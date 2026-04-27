// lib/core/models/infusion_session.dart
import 'drug.dart';

class InfusionSession {
  final Drug drug;
  final double patientWeight; // kg
  final double doseRate;      // in drug's dosing units
  final double desiredFlowRate; // calculated mL/hr
  final double syringeVolumeMl; // total syringe volume in mL
  double volumeDelivered;     // accumulated mL
  DateTime startTime;

  InfusionSession({
    required this.drug,
    required this.patientWeight,
    required this.doseRate,
    required this.desiredFlowRate,
    required this.syringeVolumeMl,
    this.volumeDelivered = 0,
    DateTime? startTime,
  }) : startTime = startTime ?? DateTime.now();

  /// 0.0 to 1.0 progress
  double get progressPercent =>
      syringeVolumeMl > 0
          ? (volumeDelivered / syringeVolumeMl).clamp(0.0, 1.0)
          : 0.0;

  /// Volume remaining
  double get volumeRemaining =>
      (syringeVolumeMl - volumeDelivered).clamp(0.0, syringeVolumeMl);

  /// Estimated time remaining based on desired flow rate
  Duration get timeRemaining {
    if (desiredFlowRate <= 0) return Duration.zero;
    final hoursLeft = volumeRemaining / desiredFlowRate;
    return Duration(seconds: (hoursLeft * 3600).round());
  }

  /// Elapsed time since start
  Duration get elapsed => DateTime.now().difference(startTime);

  /// Whether the infusion is complete
  bool get isComplete => volumeDelivered >= syringeVolumeMl;

  /// Format time remaining as HH:MM:SS
  String get timeRemainingFormatted {
    final d = timeRemaining;
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  /// Format elapsed time
  String get elapsedFormatted {
    final d = elapsed;
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m}m ${s}s';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }
}
