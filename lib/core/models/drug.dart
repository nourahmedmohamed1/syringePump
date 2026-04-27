// lib/core/models/drug.dart

class Drug {
  final String name;
  final double concentration;
  final String concentrationUnit; // e.g. "mcg/mL", "unit/mL", "units/mL"
  final String dosingUnit;        // e.g. "mcg/kg/min", "units/hr"
  final double minDose;
  final double maxDose;

  const Drug({
    required this.name,
    required this.concentration,
    required this.concentrationUnit,
    required this.dosingUnit,
    required this.minDose,
    required this.maxDose,
  });

  /// Whether this drug's dose depends on patient weight
  bool get isWeightBased =>
      dosingUnit.contains('/kg/');

  /// Whether this drug's dose is per minute (needs ×60 for hourly rate)
  bool get isPerMinute =>
      dosingUnit.contains('/min');

  /// Check if a dose is within the safety limits
  bool isDoseSafe(double dose) => dose >= minDose && dose <= maxDose;

  /// Get dose safety status
  String doseSafetyStatus(double dose) {
    if (dose < minDose) return 'Below minimum ($minDose ${dosingUnit.split("/").first})';
    if (dose > maxDose) return 'Above maximum ($maxDose ${dosingUnit.split("/").first})';
    return 'Within safe range';
  }

  @override
  String toString() => '$name ($concentration $concentrationUnit)';
}
