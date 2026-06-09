// lib/providers/pump_provider.dart
import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';


import '../core/constants/thresholds.dart';
import '../core/models/alarm_event.dart';
import '../core/models/drug.dart';
import '../core/models/hr_reading.dart';
import '../core/models/infusion_session.dart';
import '../core/models/sensor_data.dart';
import '../core/utils/data_parser.dart';
import '../core/utils/flow_calculator.dart';
import '../core/utils/tone_generator.dart';
import '../services/classic_bluetooth_service.dart';
import '../services/database_service.dart';
import '../services/drug_library_service.dart';
import '../services/notification_service.dart';
import '../services/threshold_service.dart';
import '../ui/screens/hr_scan_screen.dart';

enum ConnectionMode { none, classicBluetooth, demo }

class PumpProvider extends ChangeNotifier {
  // --- Services ---
  final ClassicBluetoothService _btService = ClassicBluetoothService();
  final ThresholdService _thresholdService = ThresholdService();
  final DatabaseService _dbService = DatabaseService();
  final NotificationService _notifService = NotificationService();
  final DrugLibraryService _drugLibrary = DrugLibraryService();
  final AudioPlayer _audioPlayer = AudioPlayer();

  // --- Parser ---
  final DataParser _dataParser = DataParser();

  // --- Sensor State ---
  SensorData _latestData = SensorData.empty();
  SensorData get latestData => _latestData;

  // --- Flow Rate History (for chart) ---
  final List<double> _flowHistory = [];
  List<double> get flowHistory => List.unmodifiable(_flowHistory);
  static const int _maxFlowHistory = 120; // 2 minutes at 1 sample/sec

  // --- Heart Rate History (for waveform) ---
  final List<double> _hrHistory = List.filled(100, 0.0);
  List<double> get hrHistory => List.unmodifiable(_hrHistory);
  int _hrHead = 0;

  // --- Camera PPG HR Readings (intermittent trend) ---
  final List<HrReading> _hrReadings = [];
  List<HrReading> get hrReadings => List.unmodifiable(_hrReadings);
  static const int _maxHrReadings = 200;

  // --- HR Check Interval (global interruption) ---
  Duration _hrCheckInterval = const Duration(minutes: 10);
  Duration get hrCheckInterval => _hrCheckInterval;
  Timer? _hrCheckTimer;
  bool _hrScanActive = false;
  bool get hrScanActive => _hrScanActive;

  // Global navigator key for pushing HR scan from anywhere
  GlobalKey<NavigatorState>? _navigatorKey;
  set navigatorKey(GlobalKey<NavigatorState> key) => _navigatorKey = key;

  // --- HR Check Interval Options ---
  static const List<Duration> hrIntervalOptions = [
    Duration(seconds: 5),
    Duration(seconds: 10),
    Duration(minutes: 10),
    Duration(minutes: 30),
    Duration(hours: 1),
  ];

  static String formatInterval(Duration d) {
    if (d.inHours >= 1) return '${d.inHours} hour';
    if (d.inMinutes >= 1) return '${d.inMinutes} mins';
    return '${d.inSeconds} seconds';
  }

  // --- Infusion Session ---
  InfusionSession? _session;
  InfusionSession? get session => _session;
  bool get hasActiveSession => _session != null;

  // --- Drug Library ---
  List<Drug> get drugs => _drugLibrary.drugs;
  bool get drugsLoaded => _drugLibrary.isLoaded;

  // --- Alarms ---
  List<AlarmEvent> _alarms = [];
  List<AlarmEvent> get alarms => _alarms;
  bool get hasAlarms => _alarms.isNotEmpty;
  bool get hasCritical => _alarms.any((a) => a.isCritical);

  Set<AlarmParameter> _previousAlarmParams = {};

  // --- Connection ---
  bool _isConnected = false;
  bool get isConnected => _isConnected;
  String _connectedDeviceName = '';
  String get connectedDeviceName => _connectedDeviceName;
  bool _isScanning = false;
  bool get isScanning => _isScanning;
  String _connectionStatus = '';
  String get connectionStatus => _connectionStatus;

  ConnectionMode _connectionMode = ConnectionMode.none;
  ConnectionMode get connectionMode => _connectionMode;

  List<BluetoothDevice> _classicDevices = [];
  List<BluetoothDevice> get classicDevices => _classicDevices;
  StreamSubscription? _discoverySubscription;

  // --- Kids Mode ---
  bool _kidsMode = false;
  bool get kidsMode => _kidsMode;

  // --- Dark Mode ---
  bool _isDarkMode = true;
  bool get isDarkMode => _isDarkMode;

  // --- Sound ---
  bool _soundEnabled = true;
  bool get soundEnabled => _soundEnabled;

  // --- Demo Mode ---
  Timer? _demoTimer;
  bool _demoMode = false;
  bool get demoMode => _demoMode;

  // --- Volume Accumulation Timer ---
  Timer? _volumeTimer;
  DateTime? _lastVolumeUpdate;

  // --- UI Throttle ---
  Timer? _uiThrottleTimer;
  bool _uiDirty = false;

  // --- Internal ---
  StreamSubscription<String>? _dataSubscription;
  final _random = Random();
  bool _alarmSoundPlaying = false;
  Timer? _notifCheckTimer;
  Timer? _dbThrottleTimer;
  int _dbInsertCount = 0;

  // Debug
  List<String> get debugSerialLog => _dataParser.rawLog;
  List<String> get debugParsedLog => _dataParser.parsedLog;
  Stream<String> get rawBytesStream => _btService.rawBytesStream;

  PumpProvider() {
    _notifService.init();
    _notifService.onNotificationTapped = _onNotificationTapped;
    _loadPrefs();
    _initAlarmFiles();
    _setupBtCallbacks();
    _loadDrugs();
    _loadThresholds();
    _notifCheckTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _checkNotificationsDismissed();
    });
  }

  Future<void> _loadThresholds() async {
    await Thresholds.loadFromPrefs();
    notifyListeners();
  }

  void resetThresholds() {
    Thresholds.resetToDefaults();
    Thresholds.saveToPrefs();
    notifyListeners();
  }

  Future<void> _loadDrugs() async {
    await _drugLibrary.load();
    notifyListeners();
  }

  Future<void> _checkNotificationsDismissed() async {
    if (!_alarmSoundPlaying || _alarms.isEmpty) return;
    try {
      final pending = await _notifService.getActiveNotifications();
      if (pending.isEmpty && _alarmSoundPlaying) {
        _stopAlarmSound();
      }
    } catch (_) {}
  }

  void _onNotificationTapped(int id) {
    _stopAlarmSound();
  }

  void acknowledgeAlarms() {
    _stopAlarmSound();
    _notifService.cancelAll();
    notifyListeners();
  }

  void _stopAlarmSound() {
    _alarmSoundPlaying = false;
    try {
      FlutterRingtonePlayer().stop();
    } catch (_) {}
    try {
      _audioPlayer.stop();
    } catch (_) {}
  }

  void _setupBtCallbacks() {
    _btService.onConnectionStateChanged = (connected, reason) {
      _connectionStatus = reason;
      if (!connected && _connectionMode == ConnectionMode.classicBluetooth) {
        _isConnected = false;
        _connectedDeviceName = 'Reconnecting...';
      } else if (connected) {
        _isConnected = true;
        _connectedDeviceName = _btService.connectedDeviceName;
        _dataSubscription?.cancel();
        _dataParser.reset();
        _latestData = SensorData.empty();
        _dataSubscription = _btService.dataStream.listen(_onRawLine);
      }
      notifyListeners();
    };
  }

  final _audioReady = Completer<void>();

  Future<void> _initAlarmFiles() async {
    try {
      final dir = await getTemporaryDirectory();
      final cp = '${dir.path}/alarm_critical.wav';
      final wp = '${dir.path}/alarm_warning.wav';
      await File(cp).writeAsBytes(ToneGenerator.criticalAlarm());
      await File(wp).writeAsBytes(ToneGenerator.warningAlarm());
    } catch (_) {}
    if (!_audioReady.isCompleted) _audioReady.complete();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('dark_mode') ?? true;
    _soundEnabled = prefs.getBool('sound_enabled') ?? true;
    // Load HR check interval
    final intervalMs = prefs.getInt('hr_check_interval_ms');
    if (intervalMs != null) {
      _hrCheckInterval = Duration(milliseconds: intervalMs);
    }
    notifyListeners();
  }

  Future<void> savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', _isDarkMode);
    await prefs.setBool('sound_enabled', _soundEnabled);
    await prefs.setInt('hr_check_interval_ms', _hrCheckInterval.inMilliseconds);
  }

  // ─── HR Check Interval & Global Interruption ─────────────────────────────

  void setHrCheckInterval(Duration interval) {
    _hrCheckInterval = interval;
    savePrefs();
    _restartHrCheckTimer();
    notifyListeners();
  }

  void setHrScanActive(bool value) {
    _hrScanActive = value;
    notifyListeners();
  }

  void _restartHrCheckTimer() {
    _hrCheckTimer?.cancel();
    _hrCheckTimer = Timer.periodic(_hrCheckInterval, (_) {
      triggerHrScan();
    });
  }

  void startHrCheckTimer() {
    _restartHrCheckTimer();
  }

  void stopHrCheckTimer() {
    _hrCheckTimer?.cancel();
  }

  /// Trigger the HR scan screen globally, interrupting whatever the user is doing.
  void triggerHrScan() {
    if (_hrScanActive) return; // Already showing a scan
    if (_navigatorKey?.currentState == null) return;

    _hrScanActive = true;
    notifyListeners();

    _navigatorKey!.currentState!.push(
      PageRouteBuilder(
        opaque: true,
        pageBuilder: (context, animation, secondaryAnimation) =>
            const HrScanScreen(isInterruption: true),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.1),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  /// Record a heart rate reading from camera PPG or fingerprint scan.
  void recordHrReading(double bpm, HrSource source) {
    final reading = HrReading(
      bpm: bpm,
      timestamp: DateTime.now(),
      source: source,
    );

    _hrReadings.add(reading);
    if (_hrReadings.length > _maxHrReadings) {
      _hrReadings.removeAt(0);
    }

    // Also update the latest sensor data with the BPM
    _latestData = SensorData(
      flowRate: _latestData.flowRate,
      fsrPressure: _latestData.fsrPressure,
      irBlocked: _latestData.irBlocked,
      heartRate: bpm,
      irRawValue: _latestData.irRawValue,
    );

    // ── HR Out-of-Range Alarm: pause syringe if outside safe range ──
    if (bpm > 0 && (bpm < Thresholds.safeHrMin || bpm > Thresholds.safeHrMax)) {
      final isLow = bpm < Thresholds.safeHrMin;
      _alarms.add(AlarmEvent(
        parameter: isLow ? AlarmParameter.heartRateLow : AlarmParameter.heartRateHigh,
        severity: AlarmSeverity.critical,
        message: isLow
            ? '🚨 HR TOO LOW: ${bpm.toStringAsFixed(0)} BPM (safe range: ${Thresholds.safeHrMin.toStringAsFixed(0)}-${Thresholds.safeHrMax.toStringAsFixed(0)})'
            : '🚨 HR TOO HIGH: ${bpm.toStringAsFixed(0)} BPM (safe range: ${Thresholds.safeHrMin.toStringAsFixed(0)}-${Thresholds.safeHrMax.toStringAsFixed(0)})',
      ));
      if (_soundEnabled) _playAlarmSound(critical: true);
      _notifService.showAlarm(
        id: isLow ? 103 : 102,
        title: '🚨 HR OUT OF RANGE',
        body: 'Heart rate ${bpm.toStringAsFixed(0)} BPM is outside safe range. Syringe paused.',
        isCritical: true,
      );
      // Auto-stop the syringe pump
      sendStopCommand();
    }

    notifyListeners();
  }

  // ─── Classic Bluetooth ────────────────────────────────────────────────────

  Future<void> startClassicScan() async {
    _isScanning = true;
    _classicDevices = [];
    notifyListeners();

    try {
      final bonded = await _btService.getBondedDevices();
      _classicDevices = List.from(bonded);
      notifyListeners();
    } catch (_) {}

    _discoverySubscription = _btService.startDiscovery().listen((result) {
      final exists =
          _classicDevices.any((d) => d.address == result.device.address);
      if (!exists) {
        _classicDevices.add(result.device);
        notifyListeners();
      }
    }, onDone: () {
      _isScanning = false;
      notifyListeners();
    }, onError: (_) {
      _isScanning = false;
      notifyListeners();
    });
  }

  Future<void> stopClassicScan() async {
    await _discoverySubscription?.cancel();
    await _btService.cancelDiscovery();
    _isScanning = false;
    notifyListeners();
  }

  Future<bool> connectClassicBt(BluetoothDevice device) async {
    _connectionStatus = 'Connecting to ${device.name ?? device.address}...';
    notifyListeners();

    final success = await _btService.connectToDevice(device);
    if (success) {
      _isConnected = true;
      _connectedDeviceName = device.name ?? 'HC-05';
      _demoMode = false;
      _connectionMode = ConnectionMode.classicBluetooth;
      _demoTimer?.cancel();
      _dataParser.reset();
      _latestData = SensorData.empty();
      await _dataSubscription?.cancel();
      _dataSubscription = _btService.dataStream.listen(_onRawLine);
      _connectionStatus = 'Connected';
    } else {
      _connectionStatus = 'Connection failed';
    }
    notifyListeners();
    return success;
  }

  Future<void> disconnect() async {
    await _dataSubscription?.cancel();
    _dataSubscription = null;

    if (_connectionMode == ConnectionMode.classicBluetooth) {
      await _btService.disconnect();
    }

    _isConnected = false;
    _connectedDeviceName = '';
    _connectionMode = ConnectionMode.none;
    _dataParser.reset();
    stopHrCheckTimer();
    notifyListeners();
  }

  // ─── Demo Mode ────────────────────────────────────────────────────────────

  void enableDemoMode() {
    _demoMode = true;
    _isConnected = true;
    _connectedDeviceName = 'Demo Device';
    _connectionMode = ConnectionMode.demo;
    _demoTimer?.cancel();

    double demoFlowBase = 12.0;

    // Auto-start a sample infusion so Kids Mode is immediately available
    if (_session == null) {
      final demoDrug = const Drug(
        name: 'Normal Saline (Demo)',
        concentration: 1.0,
        concentrationUnit: 'mg/mL',
        dosingUnit: 'mL/hr',
        minDose: 1,
        maxDose: 100,
      );
      startInfusion(
        drug: demoDrug,
        patientWeight: 25.0,
        doseRate: demoFlowBase,
        syringeVolumeMl: 3.0,
      );
    }

    _demoTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      final flow = demoFlowBase + _random.nextDouble() * 1.5 - 0.75;
      final fsr = 100.0 + _random.nextDouble() * 80;
      final hr = 72.0 + _random.nextInt(12) - 6;

      final data = SensorData(
        flowRate: flow,
        fsrPressure: fsr,
        irBlocked: false,
        heartRate: hr.toDouble(),
      );
      _processData(data: data);
    });

    // Start HR check timer in demo mode too (uses real camera)
    startHrCheckTimer();

    notifyListeners();
  }

  void disableDemoMode() {
    _demoTimer?.cancel();
    _demoMode = false;
    _isConnected = false;
    _connectedDeviceName = '';
    _connectionMode = ConnectionMode.none;
    _volumeTimer?.cancel();
    stopHrCheckTimer();
    notifyListeners();
  }

  // ─── Infusion Session ─────────────────────────────────────────────────────

  void startInfusion({
    required Drug drug,
    required double patientWeight,
    required double doseRate,
    required double syringeVolumeMl,
  }) {
    final desiredFlow = FlowCalculator.calculateFlowRate(
      drug: drug,
      dose: doseRate,
      patientWeight: patientWeight,
    );

    _session = InfusionSession(
      drug: drug,
      patientWeight: patientWeight,
      doseRate: doseRate,
      desiredFlowRate: desiredFlow,
      syringeVolumeMl: syringeVolumeMl,
    );

    _flowHistory.clear();
    _lastVolumeUpdate = DateTime.now();

    // Start volume accumulation timer
    _volumeTimer?.cancel();
    _volumeTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _accumulateVolume();
    });

    notifyListeners();
  }

  void stopInfusion() {
    _volumeTimer?.cancel();
    if (_session != null) {
      _dbService.logInfusion(
        drugName: _session!.drug.name,
        patientWeight: _session!.patientWeight,
        doseRate: _session!.doseRate,
        desiredFlowRate: _session!.desiredFlowRate,
        syringeVolume: _session!.syringeVolumeMl,
        volumeDelivered: _session!.volumeDelivered,
        startTime: _session!.startTime,
        endTime: DateTime.now(),
        completed: _session!.isComplete,
      );
    }
    _session = null;
    notifyListeners();
  }

  void _accumulateVolume() {
    if (_session == null || _latestData.flowRate <= 0) return;

    final now = DateTime.now();
    if (_lastVolumeUpdate != null) {
      final dt = now.difference(_lastVolumeUpdate!).inMilliseconds / 1000.0;
      final volumeIncrement =
          FlowCalculator.volumeFromFlow(_latestData.flowRate, dt);
      _session!.volumeDelivered += volumeIncrement;

      // Check infusion complete
      if (_session!.isComplete) {
        _alarms.add(AlarmEvent(
          parameter: AlarmParameter.infusionComplete,
          severity: AlarmSeverity.critical,
          message: '🏁 INFUSION COMPLETE! Total: ${_session!.volumeDelivered.toStringAsFixed(1)} mL',
        ));
        if (_soundEnabled) _playAlarmSound(critical: true);
        _notifService.showAlarm(
          id: 105,
          title: '🏁 INFUSION COMPLETE',
          body: '${_session!.drug.name} infusion finished. ${_session!.volumeDelivered.toStringAsFixed(1)} mL delivered.',
          isCritical: true,
        );
        // Auto-stop syringe pump on infusion complete
        sendStopCommand();
      }
    }
    _lastVolumeUpdate = now;
  }

  // ─── Kids Mode ────────────────────────────────────────────────────────────

  void toggleKidsMode() {
    _kidsMode = !_kidsMode;
    notifyListeners();
  }

  void setKidsMode(bool value) {
    _kidsMode = value;
    notifyListeners();
  }

  // ─── Data Pipeline ────────────────────────────────────────────────────────

  // ─── IR Alarm State (string-triggered only) ─────────────────────────────
  bool _fluidEmptyAlarmActive = false;
  bool get fluidEmptyAlarmActive => _fluidEmptyAlarmActive;

  void clearFluidEmptyAlarm() {
    _fluidEmptyAlarmActive = false;
    notifyListeners();
  }

  static final _garbagePattern = RegExp(
    r'^(Failed|Error|nan|inf|---)',
    caseSensitive: false,
  );

  void _onRawLine(String raw) {
    final line = raw.trim();
    if (line.isEmpty || _garbagePattern.hasMatch(line)) return;

    // ── Exact-match Arduino Empty Alarm ─────────────────────────────────
    // The app ONLY fires the Empty Alarm when it receives this exact string.
    // It NEVER sends a stop command ('s') as a result of this alarm.
    if (line == 'ALARM: EMPTY FLUID!') {
      _fluidEmptyAlarmActive = true;
      final alarm = AlarmEvent(
        parameter: AlarmParameter.syringeEmpty,
        severity: AlarmSeverity.critical,
        message: '🚨 FLUID EMPTY! Arduino reported: ALARM: EMPTY FLUID!',
      );
      if (!_alarms.any((a) => a.parameter == AlarmParameter.syringeEmpty)) {
        _alarms = [..._alarms, alarm];
      }
      if (_soundEnabled) _playAlarmSound(critical: true);
      _notifService.showAlarm(
        id: 106,
        title: '🚨 FLUID EMPTY!',
        body: 'The syringe fluid is empty. Please replace the syringe.',
        isCritical: true,
      );
      // ⚠ DO NOT send stop command here. Motor control is manual only.
      notifyListeners();
      return;
    }

    // Accept lines starting with known prefixes
    if (!RegExp(r'^[FPIHR]').hasMatch(line) && !line.contains(',')) {
      _dataParser.parseLine(line);
      return;
    }

    final result = _dataParser.parseLine(line);
    if (result != null) {
      _processData(data: result.data);
    }
  }

  void _processData({required SensorData data}) {
    _latestData = data;

    // Flow history for chart
    _flowHistory.add(data.flowRate);
    if (_flowHistory.length > _maxFlowHistory) {
      _flowHistory.removeAt(0);
    }

    // Heart rate ring buffer
    _hrHistory[_hrHead] = data.heartRate;
    _hrHead = (_hrHead + 1) % _hrHistory.length;

    // Threshold check with desired flow rate context
    final newAlarms = _thresholdService.checkAll(
      data,
      desiredFlowRate: _session?.desiredFlowRate,
    );
    _alarms = newAlarms;

    // ── Auto-Stop: ONLY on confirmed critical occlusion ──
    // Syringe-empty auto-stop is intentionally removed.
    // Empty alarm fires only from the "ALARM: EMPTY FLUID!" string.
    // Motor stop on empty is performed MANUALLY by the nurse/operator.
    final hasCriticalOcclusion = newAlarms.any((a) =>
        a.parameter == AlarmParameter.occlusion && a.isCritical);
    if (hasCriticalOcclusion) {
      sendStopCommand();
    }

    // Spam control
    final currentAlarmParams = newAlarms.map((a) => a.parameter).toSet();

    for (final alarm in newAlarms) {
      if (!_previousAlarmParams.contains(alarm.parameter)) {
        _notifService.showAlarm(
          id: alarm.notificationId,
          title: alarm.isCritical ? '🚨 CRITICAL ALERT' : '⚠️ WARNING',
          body: alarm.message,
          isCritical: alarm.isCritical,
        );
        if (_soundEnabled) _playAlarmSound(critical: alarm.isCritical);
      }
    }

    for (final prevParam in _previousAlarmParams) {
      if (!currentAlarmParams.contains(prevParam)) {
        final dummyAlarm = AlarmEvent(
          parameter: prevParam,
          severity: AlarmSeverity.warning,
          message: '',
        );
        _notifService.cancel(dummyAlarm.notificationId);
      }
    }

    if (currentAlarmParams.isEmpty && _previousAlarmParams.isNotEmpty) {
      _stopAlarmSound();
    }

    _previousAlarmParams = currentAlarmParams;

    // Persist every 5th reading
    _dbInsertCount++;
    if (_dbInsertCount >= 5) {
      _dbInsertCount = 0;
      _dbService.insertReading(data);
    }

    // Throttle UI
    _uiDirty = true;
    _uiThrottleTimer ??= Timer.periodic(
      const Duration(milliseconds: 500),
      (_) {
        if (_uiDirty) {
          _uiDirty = false;
          notifyListeners();
        }
      },
    );
  }

  void _playAlarmSound({bool critical = false}) {
    _alarmSoundPlaying = true;
    try {
      if (critical) {
        FlutterRingtonePlayer().playAlarm(looping: true, volume: 1.0);
      } else {
        FlutterRingtonePlayer().playNotification(looping: true, volume: 0.8);
      }
    } catch (_) {}
  }

  // ─── Bluetooth Commands ───────────────────────────────────────────────────

  /// Stop the motor. Sends exact command 's'.
  /// Only called from: manual Stop button, or confirmed critical HR alarm.
  void sendStopCommand() {
    if (_connectionMode == ConnectionMode.classicBluetooth && _isConnected) {
      _btService.sendCommand('s');
    }
  }

  /// Start motor forward. Sends exact command 'f'.
  void sendMotorForward() {
    if (_connectionMode == ConnectionMode.classicBluetooth && _isConnected) {
      _btService.sendCommand('f');
    }
  }

  /// Start motor backward. Sends exact command 'b'.
  void sendMotorBackward() {
    if (_connectionMode == ConnectionMode.classicBluetooth && _isConnected) {
      _btService.sendCommand('b');
    }
  }

  /// Set flow rate. Sends exact command 'R <value>'.
  void sendSetRate(double value) {
    if (_connectionMode == ConnectionMode.classicBluetooth && _isConnected) {
      _btService.sendCommand('R $value');
    }
  }

  /// Start infusion with volume. Sends exact command 'I <value>'.
  void sendStartInfusionVolume(double value) {
    if (_connectionMode == ConnectionMode.classicBluetooth && _isConnected) {
      _btService.sendCommand('I $value');
    }
  }

  /// Send a raw command string to Arduino via Bluetooth.
  void sendCommand(String command) {
    if (_connectionMode == ConnectionMode.classicBluetooth && _isConnected) {
      _btService.sendCommand(command);
    }
  }

  // ─── Settings ─────────────────────────────────────────────────────────────

  void setDarkMode(bool value) {
    _isDarkMode = value;
    notifyListeners();
    savePrefs();
  }

  void setSoundEnabled(bool value) {
    _soundEnabled = value;
    if (!value) _stopAlarmSound();
    notifyListeners();
    savePrefs();
  }

  // ─── History ──────────────────────────────────────────────────────────────

  Future<List<SensorData>> getHistory(DateTime from, DateTime to) {
    return _dbService.getReadings(from: from, to: to);
  }

  Future<List<Map<String, dynamic>>> getInfusionLogs() {
    return _dbService.getInfusionLogs();
  }

  @override
  void dispose() {
    _demoTimer?.cancel();
    _volumeTimer?.cancel();
    _uiThrottleTimer?.cancel();
    _notifCheckTimer?.cancel();
    _dbThrottleTimer?.cancel();
    _hrCheckTimer?.cancel();
    _dataSubscription?.cancel();
    _discoverySubscription?.cancel();
    _audioPlayer.dispose();
    _btService.dispose();
    super.dispose();
  }
}
