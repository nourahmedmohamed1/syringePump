// lib/services/classic_bluetooth_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

typedef ConnectionStateCallback = void Function(bool connected, String reason);

/// Service for Classic Bluetooth Serial (SPP) communication with HC-05/HC-06.
/// Reused from the Smart Incubator project with no changes.
class ClassicBluetoothService {
  BluetoothConnection? _connection;
  BluetoothDevice? _device;

  final _dataStreamController = StreamController<String>.broadcast();
  Stream<String> get dataStream => _dataStreamController.stream;

  final _rawBytesController = StreamController<String>.broadcast();
  Stream<String> get rawBytesStream => _rawBytesController.stream;

  StreamSubscription? _inputSubscription;
  String _buffer = '';

  bool get isConnected => _connection?.isConnected ?? false;
  String get connectedDeviceName => _device?.name ?? 'Unknown';
  BluetoothDevice? get connectedDevice => _device;

  bool _autoReconnect = true;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  Timer? _reconnectTimer;
  Timer? _healthCheckTimer;
  DateTime? _lastDataReceived;
  ConnectionStateCallback? onConnectionStateChanged;

  bool _isConnecting = false;
  bool get isConnecting => _isConnecting;

  void setAutoReconnect(bool enabled) {
    _autoReconnect = enabled;
  }

  Future<List<BluetoothDevice>> getBondedDevices() async {
    try {
      return await FlutterBluetoothSerial.instance.getBondedDevices();
    } catch (e) {
      return [];
    }
  }

  Stream<BluetoothDiscoveryResult> startDiscovery() {
    return FlutterBluetoothSerial.instance.startDiscovery();
  }

  Future<void> cancelDiscovery() async {
    try {
      await FlutterBluetoothSerial.instance.cancelDiscovery();
    } catch (_) {}
  }

  Future<bool?> get isBluetoothEnabled =>
      FlutterBluetoothSerial.instance.isEnabled;

  Future<bool?> requestEnable() =>
      FlutterBluetoothSerial.instance.requestEnable();

  Future<bool> connectToDevice(BluetoothDevice device) async {
    if (_isConnecting) return false;
    _isConnecting = true;

    try {
      await _cleanupConnection();
      _device = device;
      _buffer = '';
      _reconnectAttempts = 0;

      try {
        await FlutterBluetoothSerial.instance.cancelDiscovery();
      } catch (_) {}

      await Future.delayed(const Duration(milliseconds: 300));

      _connection = await BluetoothConnection.toAddress(device.address)
          .timeout(const Duration(seconds: 20));

      if (_connection == null || !_connection!.isConnected) {
        _isConnecting = false;
        return false;
      }

      _inputSubscription = _connection!.input?.listen(
        _onData,
        onDone: () {
          _handleConnectionLost('Connection closed by device');
        },
        onError: (error) {
          _handleConnectionLost('Connection error: $error');
        },
        cancelOnError: false,
      );

      _lastDataReceived = DateTime.now();
      _startHealthCheck();
      _isConnecting = false;
      onConnectionStateChanged?.call(true, 'Connected');

      return true;
    } catch (e) {
      _isConnecting = false;
      await _cleanupConnection();
      return false;
    }
  }

  void _onData(Uint8List bytes) {
    _lastDataReceived = DateTime.now();

    try {
      final hexStr =
          bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
      final asciiStr = utf8.decode(bytes, allowMalformed: true);
      _rawBytesController.add('[$hexStr] $asciiStr');
    } catch (_) {}

    try {
      _buffer += utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      _buffer += String.fromCharCodes(bytes);
    }

    while (_buffer.contains('\n')) {
      final newlineIdx = _buffer.indexOf('\n');
      final line = _buffer.substring(0, newlineIdx).trim();
      _buffer = _buffer.substring(newlineIdx + 1);

      if (line.isNotEmpty) {
        _dataStreamController.add(line);
      }
    }

    if (_buffer.length > 512) {
      final leftover = _buffer.trim();
      _buffer = '';
      if (leftover.isNotEmpty) {
        _dataStreamController.add(leftover);
      }
    }
  }

  Future<void> sendCommand(String command) async {
    if (_connection == null || !_connection!.isConnected) return;
    try {
      final bytes = utf8.encode('$command\n');
      _connection!.output.add(Uint8List.fromList(bytes));
      await _connection!.output.allSent;
    } catch (e) {
      _handleConnectionLost('Failed to send command: $e');
    }
  }

  void _startHealthCheck() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_lastDataReceived != null) {
        final elapsed = DateTime.now().difference(_lastDataReceived!);
        if (elapsed.inSeconds > 30) {
          _handleConnectionLost('No data received for ${elapsed.inSeconds}s');
        }
      }
    });
  }

  void _handleConnectionLost(String reason) {
    _cleanupConnection();
    onConnectionStateChanged?.call(false, reason);

    if (_autoReconnect &&
        _device != null &&
        _reconnectAttempts < _maxReconnectAttempts) {
      _reconnectAttempts++;
      final delay = Duration(seconds: _reconnectAttempts * 3);
      onConnectionStateChanged?.call(false,
          'Reconnecting in ${delay.inSeconds}s (attempt $_reconnectAttempts/$_maxReconnectAttempts)...');

      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(delay, () async {
        if (_device != null) {
          final success = await connectToDevice(_device!);
          if (!success && _reconnectAttempts < _maxReconnectAttempts) {
            _handleConnectionLost('Reconnect failed');
          } else if (!success) {
            onConnectionStateChanged?.call(false,
                'All reconnect attempts failed. Please reconnect manually.');
          }
        }
      });
    }
  }

  Future<void> disconnect() async {
    _autoReconnect = false;
    _reconnectTimer?.cancel();
    _healthCheckTimer?.cancel();
    await _cleanupConnection();
    _device = null;
    _buffer = '';
    _autoReconnect = true;
  }

  Future<void> _cleanupConnection() async {
    await _inputSubscription?.cancel();
    _inputSubscription = null;
    _healthCheckTimer?.cancel();

    try {
      await _connection?.finish().timeout(
        const Duration(seconds: 3),
        onTimeout: () {},
      );
    } catch (_) {}
    _connection = null;
    _buffer = '';
  }

  void dispose() {
    _reconnectTimer?.cancel();
    _healthCheckTimer?.cancel();
    _isConnecting = false;
    disconnect();
    _dataStreamController.close();
    _rawBytesController.close();
  }
}
