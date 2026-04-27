// lib/core/utils/flow_calculator.dart
import '../models/drug.dart';

class FlowCalculator {
  /// Calculate the desired flow rate in mL/hr.
  ///
  /// Formula depends on the drug's dosing unit:
  ///
  /// For weight-based, per-minute drugs (mcg/kg/min):
  ///   Flow Rate = (Dose × Weight × 60) / Concentration
  ///
  /// For weight-based, per-hour drugs (units/kg/hr):
  ///   Flow Rate = (Dose × Weight) / Concentration
  ///
  /// For non-weight-based, per-hour drugs (units/hr, mcg/hr):
  ///   Flow Rate = Dose / Concentration
  ///
  /// For non-weight-based, per-minute drugs (rare):
  ///   Flow Rate = (Dose × 60) / Concentration
  static double calculateFlowRate({
    required Drug drug,
    required double dose,
    required double patientWeight,
  }) {
    double numerator = dose;

    // Multiply by weight if weight-based
    if (drug.isWeightBased) {
      numerator *= patientWeight;
    }

    // Multiply by 60 if dose is per minute (convert to per hour)
    if (drug.isPerMinute) {
      numerator *= 60;
    }

    if (drug.concentration <= 0) return 0;
    return numerator / drug.concentration;
  }

  /// Calculate how much volume (mL) has been delivered given a flow rate
  /// and elapsed time in seconds.
  static double volumeFromFlow(double flowRateMlHr, double elapsedSeconds) {
    return flowRateMlHr * elapsedSeconds / 3600.0;
  }

  /// Calculate time remaining (in seconds) given remaining volume and flow rate.
  static double timeRemainingSeconds(double remainingMl, double flowRateMlHr) {
    if (flowRateMlHr <= 0) return double.infinity;
    return (remainingMl / flowRateMlHr) * 3600.0;
  }
}
