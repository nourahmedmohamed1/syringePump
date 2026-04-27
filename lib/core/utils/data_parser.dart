// lib/core/utils/data_parser.dart
import '../models/sensor_data.dart';

/// Result of parsing a single line.
class ParseResult {
  final String tag;
  final String rawLine;
  final SensorData data;
  final Map<String, dynamic> parsedFields;

  ParseResult({
    required this.tag,
    required this.rawLine,
    required this.data,
    required this.parsedFields,
  });
}

/// Robust parser for Arduino serial data from the syringe pump.
///
/// Recognized prefixes/keywords:
///   Flow:    F, FLOW, FLOWRATE, FR
///   FSR:     P, FSR, PRESSURE, FORCE
///   IR:      I, IR, INFRARED, PLUNGER
///   Heart:   H, HR, PULSE, BPM, HEART
///
/// Supported formats:
///   F:12.5,P:340,IR:1,HR:78   (keyed CSV)
///   12.5,340,1,78              (positional CSV: Flow, FSR, IR, HR)
///   F12.5                      (single-char prefix)
///   FLOW:12.5                  (keyword:value)
///   F=12.5                     (keyword=value)
class DataParser {
  double _flowRate = 0;
  double _fsrPressure = 0;
  bool _irBlocked = false;
  double _heartRate = 0;

  final List<String> _rawLog = [];
  List<String> get rawLog => List.unmodifiable(_rawLog);

  final List<String> _parsedLog = [];
  List<String> get parsedLog => List.unmodifiable(_parsedLog);

  void _log(String line) {
    _rawLog.add(line);
    if (_rawLog.length > 300) _rawLog.removeAt(0);
  }

  void _logParsed(String msg) {
    _parsedLog.add(msg);
    if (_parsedLog.length > 300) _parsedLog.removeAt(0);
  }

  ParseResult? parseLine(String raw) {
    final line = raw.trim();
    if (line.isEmpty) return null;

    _log(line);

    // Try CSV format first
    if (line.contains(',')) {
      final csvResult = _parseCsvLine(line);
      if (csvResult != null) return csvResult;
    }

    // Try key:value or key=value
    final kvResult = _parseKeyValue(line);
    if (kvResult != null) return kvResult;

    // Try single-char prefix
    final prefixResult = _parseSingleCharPrefix(line);
    if (prefixResult != null) return prefixResult;

    _logParsed('❌ UNPARSED: "$line"');
    return null;
  }

  ParseResult? _parseSingleCharPrefix(String line) {
    if (line.length < 2) return null;

    int numStart = 0;
    for (int i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '.' || ch == '-' ||
          (ch.codeUnitAt(0) >= 48 && ch.codeUnitAt(0) <= 57)) {
        numStart = i;
        break;
      }
      if (ch == ':' || ch == '=' || ch == ' ') {
        numStart = i + 1;
        break;
      }
    }

    if (numStart == 0 && line[0].codeUnitAt(0) >= 65) {
      numStart = 1;
    }

    if (numStart <= 0 || numStart >= line.length) return null;

    final prefix = line.substring(0, numStart).trim().toUpperCase();
    String valueStr = line.substring(numStart).trim();

    if (valueStr.isNotEmpty && (valueStr[0] == ':' || valueStr[0] == '=')) {
      valueStr = valueStr.substring(1).trim();
    }

    final value = double.tryParse(valueStr);
    if (value == null) return null;

    var field = _keywordToField(prefix);
    if (field == null && prefix.length == 1) {
      field = _charToField(prefix);
    }
    if (field == null) return null;

    _setField(field, value);
    _logParsed('✓ ${_fieldName(field)} = $value (prefix: "$prefix")');
    return ParseResult(
      tag: prefix,
      rawLine: line,
      data: _buildSnapshot(),
      parsedFields: {_fieldName(field): value},
    );
  }

  ParseResult? _parseKeyValue(String line) {
    final colonIdx = line.indexOf(':');
    final equalsIdx = line.indexOf('=');

    int sepIdx = -1;
    if (colonIdx > 0) sepIdx = colonIdx;
    if (equalsIdx > 0 && (sepIdx == -1 || equalsIdx < sepIdx)) {
      sepIdx = equalsIdx;
    }

    if (sepIdx <= 0) {
      final spaceIdx = line.indexOf(' ');
      if (spaceIdx > 0 && spaceIdx <= 11) {
        final candidate = line.substring(0, spaceIdx).trim();
        if (_isAllLetters(candidate) &&
            _keywordToField(candidate.toUpperCase()) != null) {
          sepIdx = spaceIdx;
        }
      }
    }

    if (sepIdx <= 0) return null;

    final key = line.substring(0, sepIdx).trim().toUpperCase();
    String valueStr = _stripUnit(line.substring(sepIdx + 1).trim());

    final value = double.tryParse(valueStr);
    if (value == null) return null;

    final field = _keywordToField(key);
    if (field == null) return null;

    _setField(field, value);
    _logParsed('✓ ${_fieldName(field)} = $value (key: "$key")');
    return ParseResult(
      tag: key,
      rawLine: line,
      data: _buildSnapshot(),
      parsedFields: {_fieldName(field): value},
    );
  }

  ParseResult? _parseCsvLine(String line) {
    final parts = line.split(',');
    if (parts.length < 2) return null;

    bool anyParsed = false;
    final parsedFields = <String, dynamic>{};

    bool hasKeys = parts.any((p) => p.contains(':') || p.contains('='));

    if (hasKeys) {
      for (final part in parts) {
        final trimmed = part.trim();
        if (trimmed.isEmpty) continue;

        String? key;
        String? valueStr;

        final colonIdx = trimmed.indexOf(':');
        final equalsIdx = trimmed.indexOf('=');

        if (colonIdx > 0) {
          key = trimmed.substring(0, colonIdx).trim().toUpperCase();
          valueStr = trimmed.substring(colonIdx + 1).trim();
        } else if (equalsIdx > 0) {
          key = trimmed.substring(0, equalsIdx).trim().toUpperCase();
          valueStr = trimmed.substring(equalsIdx + 1).trim();
        } else {
          if (trimmed.length >= 2) {
            int numIdx = 0;
            for (int i = 0; i < trimmed.length; i++) {
              final ch = trimmed[i];
              if (ch == '.' || ch == '-' ||
                  (ch.codeUnitAt(0) >= 48 && ch.codeUnitAt(0) <= 57)) {
                numIdx = i;
                break;
              }
            }
            if (numIdx > 0) {
              key = trimmed.substring(0, numIdx).trim().toUpperCase();
              valueStr = trimmed.substring(numIdx).trim();
            }
          }
          if (key == null) continue;
        }

        valueStr = _stripUnit(valueStr!);
        final value = double.tryParse(valueStr);
        if (value == null) continue;

        var field = _keywordToField(key);
        if (field == null && key.length == 1) {
          field = _charToField(key);
        }
        if (field != null) {
          _setField(field, value);
          parsedFields[_fieldName(field)] = value;
          anyParsed = true;
        }
      }
    } else {
      // Positional CSV: Flow, FSR, IR, HR
      final fields = [
        _SensorField.flow,
        _SensorField.fsr,
        _SensorField.ir,
        _SensorField.heartRate,
      ];

      for (int i = 0; i < parts.length && i < fields.length; i++) {
        final valueStr = _stripUnit(parts[i].trim());
        final value = double.tryParse(valueStr);
        if (value == null) continue;

        _setField(fields[i], value);
        parsedFields[_fieldName(fields[i])] = value;
        anyParsed = true;
      }
    }

    if (!anyParsed) return null;
    _logParsed(
        '✓ CSV: ${parsedFields.entries.map((e) => "${e.key}=${e.value}").join(", ")}');
    return ParseResult(
      tag: 'CSV',
      rawLine: line,
      data: _buildSnapshot(),
      parsedFields: parsedFields,
    );
  }

  _SensorField? _charToField(String ch) {
    return switch (ch) {
      'F' => _SensorField.flow,
      'P' => _SensorField.fsr,
      'I' => _SensorField.ir,
      'H' => _SensorField.heartRate,
      'R' => _SensorField.heartRate,
      _ => null,
    };
  }

  _SensorField? _keywordToField(String key) {
    return switch (key) {
      'F' || 'FL' || 'FLOW' || 'FLOWRATE' || 'FLOW_RATE' || 'FR' =>
        _SensorField.flow,
      'P' || 'FSR' || 'PRESSURE' || 'FORCE' || 'PRESS' =>
        _SensorField.fsr,
      'I' || 'IR' || 'INFRARED' || 'PLUNGER' || 'EMPTY' =>
        _SensorField.ir,
      'H' || 'HR' || 'PULSE' || 'BPM' || 'HEART' || 'HEARTRATE' ||
      'HEART_RATE' || 'R' =>
        _SensorField.heartRate,
      _ => null,
    };
  }

  void _setField(_SensorField field, double value) {
    switch (field) {
      case _SensorField.flow:
        _flowRate = value;
      case _SensorField.fsr:
        _fsrPressure = value;
      case _SensorField.ir:
        _irBlocked = value >= 1;
      case _SensorField.heartRate:
        _heartRate = value;
    }
  }

  String _fieldName(_SensorField field) {
    return switch (field) {
      _SensorField.flow => 'Flow',
      _SensorField.fsr => 'FSR',
      _SensorField.ir => 'IR',
      _SensorField.heartRate => 'HR',
    };
  }

  SensorData _buildSnapshot() {
    return SensorData(
      flowRate: _flowRate,
      fsrPressure: _fsrPressure,
      irBlocked: _irBlocked,
      heartRate: _heartRate,
    );
  }

  void reset() {
    _flowRate = 0;
    _fsrPressure = 0;
    _irBlocked = false;
    _heartRate = 0;
  }

  void clearLog() {
    _rawLog.clear();
    _parsedLog.clear();
  }

  bool _isAllLetters(String s) {
    if (s.isEmpty) return false;
    for (int i = 0; i < s.length; i++) {
      final c = s.codeUnitAt(i);
      if (!((c >= 65 && c <= 90) || (c >= 97 && c <= 122) || c == 95)) {
        return false;
      }
    }
    return true;
  }

  String _stripUnit(String s) {
    return s
        .replaceAll('mL/hr', '')
        .replaceAll('ml/hr', '')
        .replaceAll('BPM', '')
        .replaceAll('bpm', '')
        .replaceAll('%', '')
        .trim();
  }
}

enum _SensorField {
  flow,
  fsr,
  ir,
  heartRate,
}
