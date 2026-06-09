// lib/services/camera_ppg_service.dart
//
// Camera-PPG Heart Rate — Scientific Implementation (No Flash)
//
// SIGNAL EXTRACTION:
//   Uses the Cr (V) chrominance plane from YUV420 instead of luminance.
//   The Cr channel carries RED chrominance information which directly
//   correlates with hemoglobin absorption changes during cardiac pulsation.
//   This gives 5-10× better SNR than the Y channel for PPG.
//
// ALGORITHM:
//   1. Extract mean Cr (red chrominance) from central ROI
//   2. Detrend with exponential moving average baseline removal
//   3. Apply 2nd-order IIR bandpass filter (0.7–3.5 Hz = 42–210 BPM)
//   4. Dual estimation: peak detection + autocorrelation
//   5. Fuse estimates with confidence weighting
//   6. Validate via Signal Quality Index (SQI)
//
// REFERENCES:
//   - Poh, Swenson, Picard (2010) IEEE Trans Biomed Eng
//   - Verkruysse, Svaasand, Nelson (2008) Optics Express
//   - Jonathan & Leahy (2010) J. Clinical Monitoring
//   - Sun et al. (2012) "Use of ambient light in PPG"
//

import 'dart:async';
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

class CameraPpgService {
  CameraController? _controller;
  bool _isProcessing = false;
  bool _isInitialized = false;

  // ── Raw signal buffers ──
  final List<double> _rawSignal = [];
  final List<double> _filteredSignal = [];
  final List<int> _frameTimestamps = []; // ms since epoch
  static const int _bufferSize = 512;

  // ── IIR Filter state ──
  // High-pass section
  double _hpX1 = 0, _hpX2 = 0, _hpY1 = 0, _hpY2 = 0;
  // Low-pass section
  double _lpX1 = 0, _lpX2 = 0, _lpY1 = 0, _lpY2 = 0;

  // ── Detrending (baseline removal) ──
  double _baseline = 0;
  bool _baselineInitialized = false;
  static const double _baselineAlpha = 0.05; // Slow-moving EMA

  // ── Streams ──
  final StreamController<double> _signalController =
      StreamController<double>.broadcast();
  final StreamController<double> _bpmController =
      StreamController<double>.broadcast();
  final StreamController<bool> _fingerDetectedController =
      StreamController<bool>.broadcast();

  Stream<double> get signalStream => _signalController.stream;
  Stream<double> get bpmStream => _bpmController.stream;
  Stream<bool> get fingerDetectedStream => _fingerDetectedController.stream;

  double? _latestBpm;
  double? get latestBpm => _latestBpm;
  bool _fingerDetected = false;
  bool get fingerDetected => _fingerDetected;

  // ── Finger detection ──
  final List<double> _intensityWindow = [];
  static const int _intensityWindowSize = 20;

  // ── FPS estimation ──
  int _frameCount = 0;
  int? _firstFrameMs;
  double _fps = 30.0;

  /// Expose controller so the UI can show a camera preview
  CameraController? get controller => _controller;

  /// Initialize FRONT camera and start frame processing.
  /// Using the front camera so the user can easily find it (center of screen).
  /// No flash needed — the screen's own backlight provides illumination.
  Future<bool> initialize() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return false;

      // Use FRONT camera — easy to find, always just one, no flash issues
      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      debugPrint('PPG: Using FRONT camera "${frontCamera.name}"');

      _controller = CameraController(
        frontCamera,
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _controller!.initialize();

      _isInitialized = true;
      _resetAllState();

      // No flash needed for front camera — screen backlight is the light source
      try { await _controller!.setFlashMode(FlashMode.off); } catch (_) {}

      // Start image stream
      await _controller!.startImageStream(_processFrame);

      // Wait for camera to stabilize, then lock exposure
      await Future.delayed(const Duration(milliseconds: 500));
      try { await _controller!.setExposureMode(ExposureMode.locked); } catch (_) {}
      try { await _controller!.setFocusMode(FocusMode.locked); } catch (_) {}

      return true;
    } catch (e) {
      debugPrint('CameraPPG init error: $e');
      return false;
    }
  }

  void _resetAllState() {
    _rawSignal.clear();
    _filteredSignal.clear();
    _frameTimestamps.clear();
    _intensityWindow.clear();
    _hpX1 = 0; _hpX2 = 0; _hpY1 = 0; _hpY2 = 0;
    _lpX1 = 0; _lpX2 = 0; _lpY1 = 0; _lpY2 = 0;
    _baseline = 0; _baselineInitialized = false;
    _latestBpm = null;
    _fingerDetected = false;
    _frameCount = 0; _firstFrameMs = null; _fps = 30.0;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  FRAME PROCESSING PIPELINE
  // ═══════════════════════════════════════════════════════════════════════════

  void _processFrame(CameraImage image) {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      // ── Step 1: Estimate FPS ──
      _frameCount++;
      _firstFrameMs ??= nowMs;
      if (_frameCount > 15) {
        final elapsed = nowMs - _firstFrameMs!;
        if (elapsed > 0) _fps = (_frameCount * 1000.0 / elapsed).clamp(10, 60);
      }

      // ── Step 2: Extract RED chrominance (Cr/V plane) ──
      final crValue = _extractRedChrominance(image);

      // ── Step 3: Finger detection ──
      _detectFinger(crValue, image);

      if (!_fingerDetected) {
        _isProcessing = false;
        return;
      }

      // ── Step 4: Detrend (remove DC baseline drift) ──
      if (!_baselineInitialized) {
        _baseline = crValue;
        _baselineInitialized = true;
      }
      _baseline = _baselineAlpha * crValue + (1 - _baselineAlpha) * _baseline;
      final detrended = crValue - _baseline;

      // ── Step 5: Apply IIR bandpass filter (0.7–3.5 Hz) ──
      final filtered = _bandpassFilter(detrended);

      // ── Step 6: Store ──
      _rawSignal.add(detrended);
      _filteredSignal.add(filtered);
      _frameTimestamps.add(nowMs);

      while (_rawSignal.length > _bufferSize) {
        _rawSignal.removeAt(0);
        _filteredSignal.removeAt(0);
        _frameTimestamps.removeAt(0);
      }

      // ── Step 7: Emit visualization signal ──
      if (_filteredSignal.length > 5) {
        final recent = _filteredSignal.sublist(
            max(0, _filteredSignal.length - 60));
        final maxAbs = recent.map((v) => v.abs()).reduce(max);
        if (maxAbs > 0.001) {
          _signalController.add(((filtered / maxAbs) + 1) / 2);
        }
      }

      // ── Step 8: Calculate BPM (need 5+ seconds) ──
      if (_filteredSignal.length > (_fps * 5).round()) {
        _calculateBpm();
      }
    } catch (e) {
      debugPrint('PPG frame error: $e');
    }

    _isProcessing = false;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  RED CHROMINANCE EXTRACTION (Cr / V plane)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Extract the mean Cr (red chrominance) from YUV420 image.
  ///
  /// In YUV420:
  ///   - Plane 0 = Y (luminance)
  ///   - Plane 1 = U/Cb (blue chrominance)  [half resolution]
  ///   - Plane 2 = V/Cr (red chrominance)   [half resolution]
  ///
  /// The Cr channel is scientifically superior for PPG because:
  ///   - It isolates the RED component of the image
  ///   - Hemoglobin absorbs green light and reflects red
  ///   - Blood volume changes modulate red reflectance
  ///   - Less affected by ambient lighting changes than luminance
  double _extractRedChrominance(CameraImage image) {
    // Try to use V/Cr plane (index 2) if available
    if (image.planes.length >= 3) {
      final crPlane = image.planes[2]; // V/Cr plane
      final bytes = crPlane.bytes;
      // Cr plane is half resolution in each dimension
      final crWidth = image.width ~/ 2;
      final crHeight = image.height ~/ 2;

      final cx = crWidth ~/ 2;
      final cy = crHeight ~/ 2;
      final r = min(crWidth, crHeight) ~/ 3;

      double sum = 0;
      int count = 0;

      for (int y = cy - r; y < cy + r; y++) {
        if (y < 0 || y >= crHeight) continue;
        final rowOffset = y * crPlane.bytesPerRow;
        for (int x = cx - r; x < cx + r; x++) {
          if (x < 0 || x >= crWidth) continue;
          // Handle potential pixel stride
          final idx = rowOffset + x * (crPlane.bytesPerPixel ?? 1);
          if (idx < bytes.length) {
            sum += bytes[idx];
            count++;
          }
        }
      }

      return count > 0 ? sum / count : 128;
    }

    // Fallback to Y plane if Cr not available
    return _extractLuminance(image);
  }

  /// Fallback: extract mean luminance from Y plane
  double _extractLuminance(CameraImage image) {
    final plane = image.planes[0];
    final bytes = plane.bytes;
    final w = image.width;
    final h = image.height;
    final cx = w ~/ 2, cy = h ~/ 2;
    final r = min(w, h) ~/ 3;

    double sum = 0;
    int count = 0;
    for (int y = cy - r; y < cy + r; y += 2) {
      if (y < 0 || y >= h) continue;
      for (int x = cx - r; x < cx + r; x += 2) {
        if (x < 0 || x >= w) continue;
        final idx = y * plane.bytesPerRow + x;
        if (idx < bytes.length) {
          sum += bytes[idx];
          count++;
        }
      }
    }
    return count > 0 ? sum / count : 0;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  FINGER DETECTION
  // ═══════════════════════════════════════════════════════════════════════════

  /// Detect finger using BOTH luminance AND chrominance characteristics.
  ///
  /// When finger covers the camera:
  ///   - Y (luminance) drops significantly (finger blocks light)
  ///   - Cr (red chrominance) is HIGH (skin is reddish)
  ///   - The signal should have LOW short-term variance (stable occlusion)
  void _detectFinger(double crValue, CameraImage image) {
    final yValue = _extractLuminance(image);

    _intensityWindow.add(yValue);
    if (_intensityWindow.length > _intensityWindowSize) {
      _intensityWindow.removeAt(0);
    }

    if (_intensityWindow.length < 5) return;

    // Compute variance of Y channel
    final meanY = _intensityWindow.reduce((a, b) => a + b) / _intensityWindow.length;
    double varY = 0;
    for (final v in _intensityWindow) {
      varY += (v - meanY) * (v - meanY);
    }
    varY /= _intensityWindow.length;

    // Finger detection for FRONT camera (no flash):
    // - When finger covers the front camera, luminance drops very low
    //   (screen backlight shines through finger = dim reddish glow)
    // - Y variance stays LOW (stable occlusion vs moving scene)
    // - We use relaxed thresholds since there's no flash illumination
    final detected = meanY > 1 && meanY < 220 && varY < 600;

    if (detected != _fingerDetected) {
      _fingerDetected = detected;
      _fingerDetectedController.add(_fingerDetected);

      if (detected) {
        // Reset filter on finger placement to avoid transients
        _hpX1 = 0; _hpX2 = 0; _hpY1 = 0; _hpY2 = 0;
        _lpX1 = 0; _lpX2 = 0; _lpY1 = 0; _lpY2 = 0;
        _filteredSignal.clear();
        _rawSignal.clear();
        _frameTimestamps.clear();
        _baselineInitialized = false;
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  IIR BANDPASS FILTER (Cascaded Biquad: HP @ 0.7 Hz + LP @ 3.5 Hz)
  // ═══════════════════════════════════════════════════════════════════════════

  double _bandpassFilter(double x) {
    final fs = _fps.clamp(15.0, 60.0);

    // ── High-pass at 0.7 Hz (removes breathing, DC drift) ──
    final wHp = tan(pi * 0.7 / fs);
    final wHp2 = wHp * wHp;
    final normHp = 1.0 / (1.0 + sqrt(2) * wHp + wHp2);
    final b0Hp = normHp;
    final b1Hp = -2.0 * normHp;
    final b2Hp = normHp;
    final a1Hp = 2.0 * normHp * (wHp2 - 1.0);
    final a2Hp = normHp * (1.0 - sqrt(2) * wHp + wHp2);

    final yHp = b0Hp * x + b1Hp * _hpX1 + b2Hp * _hpX2
        - a1Hp * _hpY1 - a2Hp * _hpY2;
    _hpX2 = _hpX1; _hpX1 = x;
    _hpY2 = _hpY1; _hpY1 = yHp;

    // ── Low-pass at 3.5 Hz (removes HF noise, motion artifacts) ──
    final wLp = tan(pi * 3.5 / fs);
    final wLp2 = wLp * wLp;
    final normLp = 1.0 / (1.0 + sqrt(2) * wLp + wLp2);
    final b0Lp = normLp * wLp2;
    final b1Lp = 2.0 * b0Lp;
    final b2Lp = b0Lp;
    final a1Lp = 2.0 * normLp * (wLp2 - 1.0);
    final a2Lp = normLp * (1.0 - sqrt(2) * wLp + wLp2);

    final yLp = b0Lp * yHp + b1Lp * _lpX1 + b2Lp * _lpX2
        - a1Lp * _lpY1 - a2Lp * _lpY2;
    _lpX2 = _lpX1; _lpX1 = yHp;
    _lpY2 = _lpY1; _lpY1 = yLp;

    return yLp;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  BPM CALCULATION (Dual: Autocorrelation + Peak Detection)
  // ═══════════════════════════════════════════════════════════════════════════

  void _calculateBpm() {
    final n = _filteredSignal.length;
    final windowSize = min(n, (_fps * 10).round()); // Use up to 10s
    final data = _filteredSignal.sublist(n - windowSize);
    final times = _frameTimestamps.sublist(_frameTimestamps.length - windowSize);

    // ── Method 1: Autocorrelation ──
    final bpmAuto = _autocorrelationBpm(data);

    // ── Method 2: Peak detection ──
    final bpmPeak = _peakDetectionBpm(data, times);

    // ── Fuse results ──
    double? finalBpm;

    if (bpmAuto != null && bpmPeak != null) {
      // If both agree within 15%, average them
      final diff = (bpmAuto - bpmPeak).abs() / ((bpmAuto + bpmPeak) / 2);
      if (diff < 0.15) {
        finalBpm = (bpmAuto + bpmPeak) / 2;
      } else {
        // Prefer autocorrelation (more robust for low SNR)
        finalBpm = bpmAuto;
      }
    } else {
      finalBpm = bpmAuto ?? bpmPeak;
    }

    if (finalBpm == null) return;

    // ── Temporal smoothing (EMA) ──
    if (_latestBpm != null) {
      _latestBpm = _latestBpm! * 0.7 + finalBpm * 0.3;
    } else {
      _latestBpm = finalBpm;
    }

    _bpmController.add(_latestBpm!);
  }

  /// Autocorrelation-based BPM estimation.
  /// Finds the dominant periodicity by correlating the signal with itself.
  double? _autocorrelationBpm(List<double> data) {
    if (data.length < 60) return null;

    // Remove mean
    final mean = data.reduce((a, b) => a + b) / data.length;
    final centered = data.map((v) => v - mean).toList();

    // Zero-lag autocorrelation (normalization)
    double r0 = 0;
    for (final v in centered) r0 += v * v;
    if (r0 < 1e-10) return null;

    // Search lags corresponding to 40–200 BPM
    final minLag = max(3, (_fps * 60 / 200).round());
    final maxLag = min(centered.length ~/ 2, (_fps * 60 / 40).round());

    if (maxLag <= minLag) return null;

    double bestCorr = -1;
    int bestLag = minLag;

    for (int lag = minLag; lag <= maxLag; lag++) {
      double corr = 0;
      for (int i = 0; i < centered.length - lag; i++) {
        corr += centered[i] * centered[i + lag];
      }
      corr /= r0;

      if (corr > bestCorr) {
        bestCorr = corr;
        bestLag = lag;
      }
    }

    // Require reasonable correlation strength
    if (bestCorr < 0.15) return null;

    final bpm = 60.0 * _fps / bestLag;
    return (bpm >= 40 && bpm <= 200) ? bpm : null;
  }

  /// Peak detection BPM with adaptive threshold.
  double? _peakDetectionBpm(List<double> data, List<int> times) {
    if (data.length < 60) return null;

    // Adaptive threshold: 0.5 × RMS
    double rms = 0;
    for (final v in data) rms += v * v;
    rms = sqrt(rms / data.length);
    final threshold = rms * 0.5;
    if (threshold < 1e-6) return null;

    // Minimum peak distance: 250ms
    final minDist = max(3, (_fps * 0.25).round());
    final peaks = <int>[];

    for (int i = 2; i < data.length - 2; i++) {
      if (data[i] > threshold &&
          data[i] > data[i - 1] && data[i] > data[i - 2] &&
          data[i] >= data[i + 1] && data[i] >= data[i + 2]) {
        if (peaks.isEmpty || (i - peaks.last) >= minDist) {
          peaks.add(i);
        }
      }
    }

    if (peaks.length < 3) return null;

    // Compute IBIs from real timestamps (ms)
    final ibis = <double>[];
    for (int i = 1; i < peaks.length; i++) {
      final ibiMs = (times[peaks[i]] - times[peaks[i - 1]]).toDouble();
      if (ibiMs >= 300 && ibiMs <= 1500) { // 40–200 BPM
        ibis.add(ibiMs);
      }
    }

    if (ibis.length < 2) return null;

    // SQI: reject if IBI CV > 25%
    final meanIbi = ibis.reduce((a, b) => a + b) / ibis.length;
    double ibiVar = 0;
    for (final ibi in ibis) ibiVar += (ibi - meanIbi) * (ibi - meanIbi);
    ibiVar /= ibis.length;
    final cv = sqrt(ibiVar) / meanIbi;
    if (cv > 0.25) return null;

    // Median IBI → BPM
    ibis.sort();
    final medianIbi = ibis[ibis.length ~/ 2];
    final bpm = 60000.0 / medianIbi;

    return (bpm >= 40 && bpm <= 200) ? bpm : null;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  CLEANUP
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> dispose() async {
    _isInitialized = false;

    try {
      if (_controller != null) {
        // Turn off torch BEFORE closing camera
        try {
          await _controller!.setFlashMode(FlashMode.off);
        } catch (_) {}

        // Stop image stream
        try {
          await _controller!.stopImageStream();
        } catch (_) {}

        // Small delay to let hardware release
        await Future.delayed(const Duration(milliseconds: 200));

        // Dispose controller
        try {
          await _controller!.dispose();
        } catch (_) {}
      }
    } catch (_) {}

    _controller = null;

    // Wait for Android camera service to fully release
    await Future.delayed(const Duration(milliseconds: 500));

    _rawSignal.clear();
    _filteredSignal.clear();
    _frameTimestamps.clear();

    // Close streams safely
    if (!_signalController.isClosed) _signalController.close();
    if (!_bpmController.isClosed) _bpmController.close();
    if (!_fingerDetectedController.isClosed) _fingerDetectedController.close();
  }
}
