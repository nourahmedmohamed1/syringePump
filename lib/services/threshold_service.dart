// lib/services/threshold_service.dart
import '../core/constants/thresholds.dart';
import '../core/models/alarm_event.dart';
import '../core/models/sensor_data.dart';

class ThresholdService {
  /// Check all sensor values against thresholds and return active alarms.
  List<AlarmEvent> checkAll(SensorData data, {double? desiredFlowRate}) {
    final alarms = <AlarmEvent>[];

    // --- FSR Occlusion ---
    if (data.fsrPressure >= Thresholds.fsrOcclusionCritical) {
      alarms.add(AlarmEvent(
        parameter: AlarmParameter.occlusion,
        severity: AlarmSeverity.critical,
        message:
            '🚨 OCCLUSION DETECTED! Line pressure: ${data.fsrPressure.toStringAsFixed(0)}',
      ));
    } else if (data.fsrPressure >= Thresholds.fsrOcclusionWarning) {
      alarms.add(AlarmEvent(
        parameter: AlarmParameter.occlusion,
        severity: AlarmSeverity.warning,
        message:
            '⚠️ High line pressure: ${data.fsrPressure.toStringAsFixed(0)}',
      ));
    }

    // --- IR Syringe Empty ---
    // NOTE: The empty alarm is ONLY triggered by the exact Arduino string
    // "ALARM: EMPTY FLUID!" received via Bluetooth. The app NEVER infers
    // syringe-empty state from IR sensor calculations.

    // --- Heart Rate ---
    if (data.heartRate > 0) {
      if (data.heartRate >= Thresholds.hrCriticalMax) {
        alarms.add(AlarmEvent(
          parameter: AlarmParameter.heartRateHigh,
          severity: AlarmSeverity.critical,
          message:
              '🚨 CRITICAL TACHYCARDIA! HR: ${data.heartRate.toStringAsFixed(0)} BPM',
        ));
      } else if (data.heartRate >= Thresholds.hrMax) {
        alarms.add(AlarmEvent(
          parameter: AlarmParameter.heartRateHigh,
          severity: AlarmSeverity.warning,
          message:
              '⚠️ High heart rate: ${data.heartRate.toStringAsFixed(0)} BPM',
        ));
      }

      if (data.heartRate <= Thresholds.hrCriticalMin && data.heartRate > 0) {
        alarms.add(AlarmEvent(
          parameter: AlarmParameter.heartRateLow,
          severity: AlarmSeverity.critical,
          message:
              '🚨 CRITICAL BRADYCARDIA! HR: ${data.heartRate.toStringAsFixed(0)} BPM',
        ));
      } else if (data.heartRate <= Thresholds.hrMin && data.heartRate > 0) {
        alarms.add(AlarmEvent(
          parameter: AlarmParameter.heartRateLow,
          severity: AlarmSeverity.warning,
          message:
              '⚠️ Low heart rate: ${data.heartRate.toStringAsFixed(0)} BPM',
        ));
      }
    }

    // --- Flow Deviation ---
    if (desiredFlowRate != null && desiredFlowRate > 0 && data.flowRate > 0) {
      final deviationPercent =
          ((data.flowRate - desiredFlowRate) / desiredFlowRate * 100).abs();
      if (deviationPercent >= Thresholds.flowDeviationCritical) {
        alarms.add(AlarmEvent(
          parameter: AlarmParameter.flowDeviation,
          severity: AlarmSeverity.critical,
          message:
              '🚨 Flow deviation ${deviationPercent.toStringAsFixed(0)}%! Actual: ${data.flowRate.toStringAsFixed(1)} mL/hr',
        ));
      } else if (deviationPercent >= Thresholds.flowDeviationWarning) {
        alarms.add(AlarmEvent(
          parameter: AlarmParameter.flowDeviation,
          severity: AlarmSeverity.warning,
          message:
              '⚠️ Flow deviation ${deviationPercent.toStringAsFixed(0)}%. Actual: ${data.flowRate.toStringAsFixed(1)} mL/hr',
        ));
      }
    }

    return alarms;
  }
}
