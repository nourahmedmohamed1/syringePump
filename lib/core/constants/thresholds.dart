// lib/core/constants/thresholds.dart
import 'package:shared_preferences/shared_preferences.dart';

class Thresholds {
  // ── Default Constants ──
  static const double defaultFsrOcclusionWarning = 700;
  static const double defaultFsrOcclusionCritical = 850;
  static const double defaultIrEmptyThreshold = 1;
  static const double defaultHrMin = 40;
  static const double defaultHrMax = 180;
  static const double defaultHrCriticalMin = 30;
  static const double defaultHrCriticalMax = 200;
  static const double defaultFlowDeviationWarning = 20;
  static const double defaultFlowDeviationCritical = 40;

  // IR Sensor Calibration defaults (analog 0-1024)
  static const double defaultIrStartPoint = 0;
  static const double defaultIrEndPoint = 1024;

  // Safe HR Range defaults (for fingerprint HR alarm)
  static const double defaultSafeHrMin = 60;
  static const double defaultSafeHrMax = 120;

  // ── Active Values (mutable) ──
  // FSR - Force Sensitive Resistor (occlusion detection)
  // Analog 0-1023: higher = more pressure = potential blockage
  static double fsrOcclusionWarning = defaultFsrOcclusionWarning;
  static double fsrOcclusionCritical = defaultFsrOcclusionCritical;

  // IR Sensor - Syringe empty / plunger end detection
  // 1 = beam broken (plunger at end = syringe empty)
  static double irEmptyThreshold = defaultIrEmptyThreshold;

  // IR Sensor Calibration - Maps analog range to plunger position
  static double irStartPoint = defaultIrStartPoint;
  static double irEndPoint = defaultIrEndPoint;

  // Heart Rate BPM
  static double hrMin = defaultHrMin;
  static double hrMax = defaultHrMax;
  static double hrCriticalMin = defaultHrCriticalMin;
  static double hrCriticalMax = defaultHrCriticalMax;

  // Safe HR Range (fingerprint alarm triggers outside this range)
  static double safeHrMin = defaultSafeHrMin;
  static double safeHrMax = defaultSafeHrMax;

  // Flow Rate deviation from desired (percentage)
  static double flowDeviationWarning = defaultFlowDeviationWarning; // ±20%
  static double flowDeviationCritical = defaultFlowDeviationCritical; // ±40%

  // ── Persistence ──

  static Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    fsrOcclusionWarning = prefs.getDouble('thresh_fsr_warn') ?? defaultFsrOcclusionWarning;
    fsrOcclusionCritical = prefs.getDouble('thresh_fsr_crit') ?? defaultFsrOcclusionCritical;
    hrMin = prefs.getDouble('thresh_hr_min') ?? defaultHrMin;
    hrMax = prefs.getDouble('thresh_hr_max') ?? defaultHrMax;
    hrCriticalMin = prefs.getDouble('thresh_hr_crit_min') ?? defaultHrCriticalMin;
    hrCriticalMax = prefs.getDouble('thresh_hr_crit_max') ?? defaultHrCriticalMax;
    flowDeviationWarning = prefs.getDouble('thresh_flow_warn') ?? defaultFlowDeviationWarning;
    flowDeviationCritical = prefs.getDouble('thresh_flow_crit') ?? defaultFlowDeviationCritical;
    irStartPoint = prefs.getDouble('thresh_ir_start') ?? defaultIrStartPoint;
    irEndPoint = prefs.getDouble('thresh_ir_end') ?? defaultIrEndPoint;
    safeHrMin = prefs.getDouble('thresh_safe_hr_min') ?? defaultSafeHrMin;
    safeHrMax = prefs.getDouble('thresh_safe_hr_max') ?? defaultSafeHrMax;
  }

  static Future<void> saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('thresh_fsr_warn', fsrOcclusionWarning);
    await prefs.setDouble('thresh_fsr_crit', fsrOcclusionCritical);
    await prefs.setDouble('thresh_hr_min', hrMin);
    await prefs.setDouble('thresh_hr_max', hrMax);
    await prefs.setDouble('thresh_hr_crit_min', hrCriticalMin);
    await prefs.setDouble('thresh_hr_crit_max', hrCriticalMax);
    await prefs.setDouble('thresh_flow_warn', flowDeviationWarning);
    await prefs.setDouble('thresh_flow_crit', flowDeviationCritical);
    await prefs.setDouble('thresh_ir_start', irStartPoint);
    await prefs.setDouble('thresh_ir_end', irEndPoint);
    await prefs.setDouble('thresh_safe_hr_min', safeHrMin);
    await prefs.setDouble('thresh_safe_hr_max', safeHrMax);
  }

  static void resetToDefaults() {
    fsrOcclusionWarning = defaultFsrOcclusionWarning;
    fsrOcclusionCritical = defaultFsrOcclusionCritical;
    irEmptyThreshold = defaultIrEmptyThreshold;
    hrMin = defaultHrMin;
    hrMax = defaultHrMax;
    hrCriticalMin = defaultHrCriticalMin;
    hrCriticalMax = defaultHrCriticalMax;
    flowDeviationWarning = defaultFlowDeviationWarning;
    flowDeviationCritical = defaultFlowDeviationCritical;
    irStartPoint = defaultIrStartPoint;
    irEndPoint = defaultIrEndPoint;
    safeHrMin = defaultSafeHrMin;
    safeHrMax = defaultSafeHrMax;
  }

  /// Calculate plunger position (0.0 = start, 1.0 = end) from raw IR value
  static double getPlungerPosition(int irRawValue) {
    final range = irEndPoint - irStartPoint;
    if (range.abs() < 1) return 0.0;
    return ((irRawValue - irStartPoint) / range).clamp(0.0, 1.0);
  }
}
