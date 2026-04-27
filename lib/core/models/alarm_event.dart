// lib/core/models/alarm_event.dart

enum AlarmSeverity { warning, critical }

enum AlarmParameter {
  occlusion,
  syringeEmpty,
  heartRateHigh,
  heartRateLow,
  flowDeviation,
  infusionComplete,
}

class AlarmEvent {
  final AlarmParameter parameter;
  final AlarmSeverity severity;
  final String message;
  final DateTime timestamp;

  AlarmEvent({
    required this.parameter,
    required this.severity,
    required this.message,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  String get parameterLabel {
    switch (parameter) {
      case AlarmParameter.occlusion:
        return 'Occlusion';
      case AlarmParameter.syringeEmpty:
        return 'Syringe Empty';
      case AlarmParameter.heartRateHigh:
        return 'Heart Rate High';
      case AlarmParameter.heartRateLow:
        return 'Heart Rate Low';
      case AlarmParameter.flowDeviation:
        return 'Flow Deviation';
      case AlarmParameter.infusionComplete:
        return 'Infusion Complete';
    }
  }

  bool get isCritical => severity == AlarmSeverity.critical;

  /// Unique notification ID per alarm type
  int get notificationId {
    switch (parameter) {
      case AlarmParameter.occlusion:
        return 100;
      case AlarmParameter.syringeEmpty:
        return 101;
      case AlarmParameter.heartRateHigh:
        return 102;
      case AlarmParameter.heartRateLow:
        return 103;
      case AlarmParameter.flowDeviation:
        return 104;
      case AlarmParameter.infusionComplete:
        return 105;
    }
  }
}
