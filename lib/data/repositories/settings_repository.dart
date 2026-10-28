import 'package:sqflite/sqflite.dart';

import '../../core/database/app_database.dart';
import '../../core/database/seed.dart';
import '../models/user.dart';

/// إعدادات العيادة + عمليات قاعدة البيانات (نسخ احتياطي / تجريبي).
class SettingsRepository {
  Future<Database> get _db => AppDatabase.instance.database;

  Future<ClinicSettings> load() async {
    final db = await _db;
    final rows = await db.query('clinic_settings', where: 'id = 1', limit: 1);
    return ClinicSettings.fromMap(rows.isEmpty ? null : rows.first);
  }

  Future<int> save(ClinicSettings s) async {
    final db = await _db;
    return db.update('clinic_settings', s.toMap(), where: 'id = 1');
  }

  Future<void> insertDemoData() async {
    final db = await _db;
    await seedDemoData(db);
  }

  /// حذف كل بيانات المرضى مع الإبقاء على المستخدمين والإعدادات.
  Future<void> clearClinicalData() async {
    final db = await _db;
    for (final table in [
      'payments',
      'treatment_sessions',
      'referrals',
      'treatment_orders',
      'investigation_attachments',
      'prescriptions',
      'neuro_scales',
      'neuro_exam',
      'investigations',
      'payments',
      'appointments',
      'visits',
      'medications',
      'medical_history',
      'patients',
    ]) {
      await db.delete(table);
    }
  }

  /// إحصاءات سريعة عن حجم قاعدة البيانات (تعرض في شاشة الإعدادات).
  Future<Map<String, int>> tableCounts() async {
    final db = await _db;
    const tables = [
      'patients',
      'visits',
      'appointments',
      'investigations',
      'medications',
      'payments',
      'users',
    ];
    final result = <String, int>{};
    for (final t in tables) {
      final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM $t');
      result[t] = (rows.first['c'] as int?) ?? 0;
    }
    return result;
  }
}

