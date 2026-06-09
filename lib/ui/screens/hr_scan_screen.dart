// lib/ui/screens/hr_scan_screen.dart
import 'dart:async';
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/thresholds.dart';
import '../../core/models/hr_reading.dart';
import '../../providers/pump_provider.dart';
import '../../services/camera_ppg_service.dart';

enum ScanMode { fingerprint, camera }

/// Full-screen heart rate scan page supporting Fingerprint mock and Camera PPG.
class HrScanScreen extends StatefulWidget {
  /// If true, this was triggered by the periodic timer (cannot be dismissed manually).
  final bool isInterruption;

  const HrScanScreen({super.key, this.isInterruption = false});

  @override
  State<HrScanScreen> createState() => _HrScanScreenState();
}

class _HrScanScreenState extends State<HrScanScreen>
    with TickerProviderStateMixin {
  // Mode Selection
  ScanMode _scanMode = ScanMode.fingerprint;

  // Fingerprint State
  bool _fingerPressed = false;
  bool _scanComplete = false;
  double? _measuredBpm;
  int _scanSeconds = 0;
  static const int _scanDuration = 8; // seconds to complete scan
  Timer? _scanTimer;

  // Mock BPM generation
  final _random = Random();
  double _currentMockBpm = 0;
  final List<double> _bpmReadings = [];

  // Camera PPG State
  final CameraPpgService _cameraPpgService = CameraPpgService();
  bool _isCameraInitialized = false;
  double? _cameraBpm;
  bool _cameraFingerDetected = false;
  double _cameraSignal = 0.5;

  StreamSubscription? _bpmSub;
  StreamSubscription? _fingerSub;
  StreamSubscription? _signalSub;

  // Animations
  late AnimationController _pulseController;
  late AnimationController _glowController;
  late AnimationController _successController;
  late AnimationController _rippleController;
  late AnimationController _scanLineController;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  void _onFingerDown() {
    if (_scanComplete) return;
    HapticFeedback.mediumImpact();
    setState(() => _fingerPressed = true);

    // Initialize mock BPM base
    _currentMockBpm = 75.0 + _random.nextInt(11); // 75-85 starting range
    _bpmReadings.clear();
    _scanSeconds = 0;

    _scanTimer?.cancel();
    _scanTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || !_fingerPressed) {
        timer.cancel();
        return;
      }

      // Generate realistic BPM drift
      _currentMockBpm += (_random.nextDouble() * 6 - 3); // ±3 BPM drift
      _currentMockBpm = _currentMockBpm.clamp(65.0, 115.0);
      _bpmReadings.add(_currentMockBpm);

      setState(() {
        _scanSeconds++;
        _measuredBpm = _currentMockBpm;
      });

      HapticFeedback.lightImpact();

      if (_scanSeconds >= _scanDuration) {
        timer.cancel();
        _finishScan();
      }
    });
  }

  void _onFingerUp() {
    if (_scanComplete) return;
    _scanTimer?.cancel();

    // If scan was running long enough (at least 5 seconds), finish it
    if (_scanSeconds >= 5 && _bpmReadings.isNotEmpty) {
      _finishScan();
    } else {
      setState(() {
        _fingerPressed = false;
        _scanSeconds = 0;
        _measuredBpm = null;
        _bpmReadings.clear();
      });
    }
  }

  void _finishScan() {
    if (_scanComplete) return;

    // Calculate final BPM as average of last 5 readings for stability
    final recentReadings = _bpmReadings.length > 5
        ? _bpmReadings.sublist(_bpmReadings.length - 5)
        : _bpmReadings;
    final avgBpm = recentReadings.reduce((a, b) => a + b) / recentReadings.length;
    final finalBpm = avgBpm.roundToDouble();

    setState(() {
      _scanComplete = true;
      _fingerPressed = false;
      _measuredBpm = finalBpm;
    });
    _successController.forward();
    HapticFeedback.heavyImpact();

    // Record the reading
    if (finalBpm >= 40 && finalBpm <= 220) {
      final provider = context.read<PumpProvider>();
      provider.recordHrReading(finalBpm, HrSource.fingerprint);
    }

    // Auto-dismiss after showing result
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        final provider = context.read<PumpProvider>();
        provider.setHrScanActive(false);
        Navigator.of(context).pop();
      }
    });
  }

  void _setScanMode(ScanMode mode) async {
    if (_scanMode == mode) return;
    setState(() => _scanMode = mode);
    
    if (mode == ScanMode.camera) {
      final success = await _cameraPpgService.initialize();
      if (success && mounted) {
        setState(() => _isCameraInitialized = true);
        _bpmSub = _cameraPpgService.bpmStream.listen((bpm) {
          if (mounted) setState(() => _cameraBpm = bpm);
        });
        _fingerSub = _cameraPpgService.fingerDetectedStream.listen((detected) {
          if (mounted) setState(() => _cameraFingerDetected = detected);
        });
        _signalSub = _cameraPpgService.signalStream.listen((val) {
          if (mounted) setState(() => _cameraSignal = val);
        });
      }
    } else {
      await _cameraPpgService.dispose();
      _bpmSub?.cancel();
      _fingerSub?.cancel();
      _signalSub?.cancel();
      if (mounted) {
        setState(() {
          _isCameraInitialized = false;
          _cameraBpm = null;
          _cameraFingerDetected = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _cameraPpgService.dispose();
    _bpmSub?.cancel();
    _fingerSub?.cancel();
    _signalSub?.cancel();
    _scanTimer?.cancel();
    _pulseController.dispose();
    _glowController.dispose();
    _successController.dispose();
    _rippleController.dispose();
    _scanLineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Check if measured BPM is outside safe range
    final isOutOfRange = _measuredBpm != null &&
        (_measuredBpm! < Thresholds.safeHrMin || _measuredBpm! > Thresholds.safeHrMax);

    return PopScope(
      canPop: !widget.isInterruption || _scanComplete,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0A1A),
        body: _scanComplete 
            ? _buildSuccessView(isOutOfRange) 
            : (_scanMode == ScanMode.fingerprint 
                ? _buildScanningView() 
                : _buildCameraScanningView()),
      ),
    );
  }

  Widget _buildSuccessView(bool isOutOfRange) {
    return SafeArea(
      child: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildSuccess(isOutOfRange)),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildScanningView() {
    final screenHeight = MediaQuery.of(context).size.height;
    
    // Precisely target the hardware fingerprint scanner location
    // Typically 12-15% of the physical screen height from the bottom edge
    final sensorCenterY = screenHeight * 0.14; 
    
    // The _buildFingerprintScanArea is a 240x240 widget (due to ripples)
    // Offset by half its height to place the center exactly at sensorCenterY
    final sensorBottom = sensorCenterY - 120;

    return Stack(
      children: [
        // Top Info (Header & text)
        SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              _buildTopInfo(),
            ],
          ),
        ),

        // Bottom Section (Instruction box)
        Positioned(
          bottom: sensorCenterY + 140, // Place it nicely above the 240px ripple box
          left: 0,
          right: 0,
          child: _buildBottomSection(),
        ),

        // Fingerprint Scanner
        Positioned(
          bottom: sensorBottom,
          left: 0,
          right: 0,
          child: _buildFingerprintScanArea(),
        ),
      ],
    );
  }

  Widget _buildCameraScanningView() {
    return SafeArea(
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _cameraFingerDetected
                      ? 'Reading your heart rate...'
                      : 'Place finger over FRONT camera',
                  style: GoogleFonts.outfit(
                    color: _cameraFingerDetected ? AppColors.heartColor : Colors.white70,
                    fontWeight: FontWeight.w600,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Make sure your fingertip fully covers the lens',
                  style: GoogleFonts.outfit(
                    color: Colors.white38,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 40),

                // Camera Preview Box
                Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _cameraFingerDetected
                          ? AppColors.heartColor
                          : Colors.white.withValues(alpha: 0.2),
                      width: 4,
                    ),
                    boxShadow: _cameraFingerDetected
                        ? [
                            BoxShadow(
                              color: AppColors.heartColor.withValues(alpha: 0.3),
                              blurRadius: 30,
                              spreadRadius: 5,
                            )
                          ]
                        : [],
                  ),
                  child: ClipOval(
                    child: _isCameraInitialized && _cameraPpgService.controller != null
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              CameraPreview(_cameraPpgService.controller!),
                              if (!_cameraFingerDetected)
                                Container(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  child: const Icon(
                                    Icons.touch_app,
                                    color: Colors.white54,
                                    size: 48,
                                  ),
                                ),
                            ],
                          )
                        : Container(
                            color: Colors.black26,
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: AppColors.heartColor,
                              ),
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 32),

                // BPM Display
                if (_cameraBpm != null)
                  Column(
                    children: [
                      Text(
                        _cameraBpm!.toStringAsFixed(0),
                        style: GoogleFonts.outfit(
                          color: AppColors.heartColor,
                          fontWeight: FontWeight.w900,
                          fontSize: 64,
                          letterSpacing: -3,
                        ),
                      ),
                      Text(
                        'BPM',
                        style: GoogleFonts.outfit(
                          color: AppColors.heartColor.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.heartColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                        onPressed: () {
                          _finishCameraScan(_cameraBpm!);
                        },
                        child: Text('Confirm Reading', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  )
                else
                  SizedBox(
                    height: 90,
                    child: Center(
                      child: Text(
                        '-- BPM',
                        style: GoogleFonts.outfit(
                          color: Colors.white30,
                          fontWeight: FontWeight.w700,
                          fontSize: 32,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _finishCameraScan(double finalBpm) {
    setState(() {
      _scanComplete = true;
      _measuredBpm = finalBpm;
    });
    _successController.forward();
    HapticFeedback.heavyImpact();

    if (finalBpm >= 40 && finalBpm <= 220) {
      final provider = context.read<PumpProvider>();
      provider.recordHrReading(finalBpm, HrSource.camera);
    }

    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        final provider = context.read<PumpProvider>();
        provider.setHrScanActive(false);
        Navigator.of(context).pop();
      }
    });
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              if (!widget.isInterruption || _scanComplete)
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () {
                    final provider = context.read<PumpProvider>();
                    provider.setHrScanActive(false);
                    Navigator.of(context).pop();
                  },
                )
              else
                const SizedBox(width: 48),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.heartColor.withValues(alpha: 0.2),
                      AppColors.heartColor.withValues(alpha: 0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.heartColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.fingerprint, color: AppColors.heartColor, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Heart Rate Scan',
                      style: GoogleFonts.outfit(
                        color: AppColors.heartColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              const SizedBox(width: 48),
            ],
          ),
        ),
        if (!_scanComplete)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
            child: CupertinoSlidingSegmentedControl<ScanMode>(
              groupValue: _scanMode,
              backgroundColor: Colors.white.withValues(alpha: 0.05),
              thumbColor: AppColors.heartColor.withValues(alpha: 0.3),
              children: {
                ScanMode.fingerprint: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                  child: Text('Screen Sensor', style: GoogleFonts.outfit(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                ),
                ScanMode.camera: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                  child: Text('Camera Sensor', style: GoogleFonts.outfit(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              },
              onValueChanged: (mode) {
                if (mode != null) _setScanMode(mode);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildTopInfo() {
    return Column(
      children: [
        Text(
          _fingerPressed
              ? 'Scanning... hold still'
              : 'Press & hold the fingerprint',
          style: GoogleFonts.outfit(
            color: _fingerPressed ? AppColors.heartColor : Colors.white70,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _fingerPressed
              ? 'Reading your heart rate from fingerprint'
              : 'Place your finger on the sensor below',
          style: GoogleFonts.outfit(
            color: Colors.white38,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 40),

        // Real-time BPM display
        if (_measuredBpm != null && _fingerPressed)
          AnimatedOpacity(
            opacity: 1.0,
            duration: const Duration(milliseconds: 500),
            child: Column(
              children: [
                Text(
                  _measuredBpm!.toStringAsFixed(0),
                  style: GoogleFonts.outfit(
                    color: AppColors.heartColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 64,
                    letterSpacing: -3,
                  ),
                ),
                Text(
                  'BPM',
                  style: GoogleFonts.outfit(
                    color: AppColors.heartColor.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          )
        else
          SizedBox(
            height: 90,
            child: Center(
              child: Text(
                '-- BPM',
                style: GoogleFonts.outfit(
                  color: Colors.white30,
                  fontWeight: FontWeight.w700,
                  fontSize: 32,
                ),
              ),
            ),
          ),

        const SizedBox(height: 24),

        // Progress dots
        if (_fingerPressed) _buildProgressDots(),
      ],
    );
  }

  Widget _buildFingerprintScanArea() {
    return GestureDetector(
      onTapDown: (_) => _onFingerDown(),
      onTapUp: (_) => _onFingerUp(),
      onTapCancel: () => _onFingerUp(),
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, _) {
          final pulseScale = _fingerPressed
              ? 1.0 + _pulseController.value * 0.08
              : 1.0 + _pulseController.value * 0.04;

          return Stack(
            alignment: Alignment.center,
            children: [
              // Ripple rings (when scanning)
              if (_fingerPressed) ...[
                AnimatedBuilder(
                  animation: _rippleController,
                  builder: (context, _) {
                    return CustomPaint(
                      size: const Size(240, 240),
                      painter: _RipplePainter(
                        progress: _rippleController.value,
                        color: AppColors.heartColor,
                      ),
                    );
                  },
                ),
              ],

              // Outer glow ring
              AnimatedBuilder(
                animation: _glowController,
                builder: (context, _) {
                  return Container(
                    width: 180 + _glowController.value * 16,
                    height: 180 + _glowController.value * 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _fingerPressed
                            ? AppColors.heartColor.withValues(
                                alpha: 0.25 + _glowController.value * 0.15)
                            : Colors.white.withValues(alpha: 0.06),
                        width: 2,
                      ),
                    ),
                  );
                },
              ),

              // Main fingerprint circle
              Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: _fingerPressed
                        ? [
                            AppColors.heartColor.withValues(alpha: 0.3),
                            AppColors.heartColor.withValues(alpha: 0.08),
                          ]
                        : [
                            Colors.white.withValues(alpha: 0.08),
                            Colors.white.withValues(alpha: 0.02),
                          ],
                  ),
                  border: Border.all(
                    color: _fingerPressed
                        ? AppColors.heartColor.withValues(alpha: 0.5)
                        : Colors.white.withValues(alpha: 0.12),
                    width: 2.5,
                  ),
                  boxShadow: _fingerPressed
                      ? [
                          BoxShadow(
                            color: AppColors.heartColor.withValues(alpha: 0.35),
                            blurRadius: 40,
                            spreadRadius: 8,
                          ),
                        ]
                      : [],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Fingerprint icon
                    Transform.scale(
                      scale: pulseScale,
                      child: Icon(
                        Icons.fingerprint,
                        size: 72,
                        color: _fingerPressed
                            ? AppColors.heartColor
                            : Colors.white.withValues(alpha: 0.35),
                      ),
                    ),

                    // Scan line overlay
                    if (_fingerPressed)
                      AnimatedBuilder(
                        animation: _scanLineController,
                        builder: (context, _) {
                          return ClipOval(
                            child: SizedBox(
                              width: 150,
                              height: 150,
                              child: Align(
                                alignment: Alignment(
                                    0, -1.0 + _scanLineController.value * 2.0),
                                child: Container(
                                  width: 150,
                                  height: 3,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.transparent,
                                        AppColors.heartColor
                                            .withValues(alpha: 0.6),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProgressDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_scanDuration, (index) {
        final isActive = index < _scanSeconds;
        final isCurrent = index == _scanSeconds;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isCurrent ? 24 : 10,
          height: 10,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(5),
            color: isActive
                ? AppColors.heartColor
                : isCurrent
                    ? AppColors.heartColor.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.12),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: AppColors.heartColor.withValues(alpha: 0.4),
                      blurRadius: 6,
                    ),
                  ]
                : [],
          ),
        );
      }),
    );
  }

  Widget _buildSuccess(bool isOutOfRange) {
    return AnimatedBuilder(
      animation: _successController,
      builder: (context, _) {
        final scale = 1.0 + _successController.value * 0.1;
        final resultColor = isOutOfRange ? AppColors.danger : AppColors.safe;

        return Center(
          child: Transform.scale(
            scale: scale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Success/Warning checkmark
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        resultColor.withValues(alpha: 0.3),
                        resultColor.withValues(alpha: 0.05),
                      ],
                    ),
                    border: Border.all(
                      color: resultColor.withValues(alpha: 0.5),
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: resultColor.withValues(alpha: 0.3),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Icon(
                    isOutOfRange ? Icons.warning_rounded : Icons.check_rounded,
                    color: resultColor,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  _measuredBpm != null
                      ? '${_measuredBpm!.toStringAsFixed(0)} BPM'
                      : 'Scan Complete',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 36,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isOutOfRange
                      ? '⚠️ HR out of safe range — syringe paused!'
                      : 'Heart rate recorded ✓',
                  style: GoogleFonts.outfit(
                    color: resultColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                if (isOutOfRange) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Safe range: ${Thresholds.safeHrMin.toStringAsFixed(0)}-${Thresholds.safeHrMax.toStringAsFixed(0)} BPM',
                    style: GoogleFonts.outfit(
                      color: Colors.white38,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          // Progress indicator during scan
          if (!_scanComplete && _fingerPressed)
            Column(
              children: [
                // Countdown ring
                SizedBox(
                  width: 56,
                  height: 56,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: _scanSeconds / _scanDuration.toDouble(),
                        strokeWidth: 4,
                        color: AppColors.heartColor,
                        backgroundColor:
                            AppColors.heartColor.withValues(alpha: 0.15),
                      ),
                      Text(
                        '${_scanDuration - _scanSeconds}',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'seconds remaining',
                  style: GoogleFonts.outfit(
                    color: Colors.white38,
                    fontSize: 12,
                  ),
                ),
              ],
            ),

          if (!_scanComplete && !_fingerPressed)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(16),
                border:
                    Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.heartColor.withValues(alpha: 0.1),
                    ),
                    child: Icon(
                      Icons.fingerprint,
                      color: AppColors.heartColor.withValues(alpha: 0.7),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Fingerprint Scan',
                          style: GoogleFonts.outfit(
                            color: Colors.white70,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          _scanSeconds > 0
                              ? 'Hold for ${_scanDuration - _scanSeconds} more seconds to complete'
                              : 'Press and hold the fingerprint sensor below for ${_scanDuration}s',
                          style: GoogleFonts.outfit(
                            color: Colors.white30,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Ripple Effect Painter ────────────────────────────────────────────────────

class _RipplePainter extends CustomPainter {
  final double progress;
  final Color color;

  _RipplePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    for (int i = 0; i < 3; i++) {
      final rippleProgress = (progress + i * 0.33) % 1.0;
      final radius = maxRadius * 0.5 + maxRadius * 0.5 * rippleProgress;
      final opacity = (1.0 - rippleProgress) * 0.3;

      final paint = Paint()
        ..color = color.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RipplePainter old) => true;
}
