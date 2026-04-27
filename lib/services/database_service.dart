// lib/services/database_service.dart
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../core/models/sensor_data.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final path = join(await getDatabasesPath(), 'syringe_pump.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE readings (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            flow_rate REAL,
            fsr_pressure REAL,
            ir_blocked INTEGER,
            heart_rate REAL,
            timestamp INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE infusion_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            drug_name TEXT,
            patient_weight REAL,
            dose_rate REAL,
            desired_flow_rate REAL,
            syringe_volume REAL,
            volume_delivered REAL,
            start_time INTEGER,
            end_time INTEGER,
            completed INTEGER DEFAULT 0
          )
        ''');
      },
    );
  }

  Future<void> insertReading(SensorData data) async {
    final db = await database;
    await db.insert('readings', data.toMap());
  }

  Future<List<SensorData>> getReadings({
    required DateTime from,
    required DateTime to,
  }) async {
    final db = await database;
    final results = await db.query(
      'readings',
      where: 'timestamp >= ? AND timestamp <= ?',
      whereArgs: [from.millisecondsSinceEpoch, to.millisecondsSinceEpoch],
      orderBy: 'timestamp ASC',
    );
    return results.map((m) => SensorData.fromMap(m)).toList();
  }

  Future<void> logInfusion({
    required String drugName,
    required double patientWeight,
    required double doseRate,
    required double desiredFlowRate,
    required double syringeVolume,
    required double volumeDelivered,
    required DateTime startTime,
    required DateTime endTime,
    required bool completed,
  }) async {
    final db = await database;
    await db.insert('infusion_logs', {
      'drug_name': drugName,
      'patient_weight': patientWeight,
      'dose_rate': doseRate,
      'desired_flow_rate': desiredFlowRate,
      'syringe_volume': syringeVolume,
      'volume_delivered': volumeDelivered,
      'start_time': startTime.millisecondsSinceEpoch,
      'end_time': endTime.millisecondsSinceEpoch,
      'completed': completed ? 1 : 0,
    });
  }

  Future<List<Map<String, dynamic>>> getInfusionLogs() async {
    final db = await database;
    return db.query('infusion_logs', orderBy: 'start_time DESC');
  }
}
