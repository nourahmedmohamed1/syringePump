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

  // ── Active Values (mutable) ──
  // FSR - Force Sensitive Resistor (occlusion detection)
  // Analog 0-1023: higher = more pressure = potential blockage
  static double fsrOcclusionWarning = defaultFsrOcclusionWarning;
  static double fsrOcclusionCritical = defaultFsrOcclusionCritical;

  // IR Sensor - Syringe empty / plunger end detection
  // 1 = beam broken (plunger at end = syringe empty)
  static double irEmptyThreshold = defaultIrEmptyThreshold;

  // Heart Rate BPM
  static double hrMin = defaultHrMin;
  static double hrMax = defaultHrMax;
  static double hrCriticalMin = defaultHrCriticalMin;
  static double hrCriticalMax = defaultHrCriticalMax;

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
  }
}
