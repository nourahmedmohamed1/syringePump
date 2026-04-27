// lib/services/drug_library_service.dart
import 'package:flutter/services.dart';
import '../core/models/drug.dart';

/// Loads and provides access to the drug library from the bundled CSV.
class DrugLibraryService {
  static final DrugLibraryService _instance = DrugLibraryService._internal();
  factory DrugLibraryService() => _instance;
  DrugLibraryService._internal();

  final List<Drug> _drugs = [];
  bool _loaded = false;

  List<Drug> get drugs => List.unmodifiable(_drugs);
  bool get isLoaded => _loaded;

  /// Load drugs from the bundled CSV asset.
  Future<void> load() async {
    if (_loaded) return;
    try {
      final csvString = await rootBundle.loadString('assets/data/drug_library.csv');
      final lines = csvString.split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();

      if (lines.isEmpty) return;

      // Skip header row
      for (int i = 1; i < lines.length; i++) {
        final parts = lines[i].split(',');
        if (parts.length < 6) continue;

        try {
          _drugs.add(Drug(
            name: parts[0].trim(),
            concentration: double.parse(parts[1].trim()),
            concentrationUnit: parts[2].trim(),
            dosingUnit: parts[3].trim(),
            minDose: double.parse(parts[4].trim()),
            maxDose: double.parse(parts[5].trim()),
          ));
        } catch (_) {
          // Skip malformed rows
        }
      }

      _loaded = true;
    } catch (e) {
      // Asset not found or parse error
      _loaded = false;
    }
  }

  /// Get a drug by name (case-insensitive).
  Drug? getDrugByName(String name) {
    final lower = name.toLowerCase();
    try {
      return _drugs.firstWhere(
        (d) => d.name.toLowerCase() == lower,
      );
    } catch (_) {
      return null;
    }
  }

  /// Search drugs by partial name match.
  List<Drug> searchDrugs(String query) {
    if (query.isEmpty) return _drugs;
    final lower = query.toLowerCase();
    return _drugs.where((d) => d.name.toLowerCase().contains(lower)).toList();
  }
}
