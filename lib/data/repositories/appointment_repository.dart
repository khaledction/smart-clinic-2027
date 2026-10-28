import 'package:sqflite/sqflite.dart';

import '../../core/database/app_database.dart';
import '../../core/utils/date_fmt.dart';
import '../models/appointment.dart';

/// المواعيد والمدفوعات.
class AppointmentRepository {
  Future<Database> get _db => AppDatabase.instance.database;

  static const _join =
      'SELECT a.*, p.full_name, p.phone FROM appointments a '
      'JOIN patients p ON p.id = a.patient_id';

  Future<List<Appointment>> forDay(DateTime day) async {
    final db = await _db;
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    final rows = await db.rawQuery(
      '$_join WHERE a.start_at >= ? AND a.start_at < ? ORDER BY a.start_at ASC',
      [start.toIso8601String(), end.toIso8601String()],
    );
    return rows.map(Appointment.fromMap).toList();
  }

  Future<List<Appointment>> between(DateTime from, DateTime to) async {
    final db = await _db;
    final rows = await db.rawQuery(
      '$_join WHERE a.start_at >= ? AND a.start_at < ? ORDER BY a.start_at ASC',
      [from.toIso8601String(), to.toIso8601String()],
    );
    return rows.map(Appointment.fromMap).toList();
  }

  Future<List<Appointment>> forPatient(int patientId) async {
    final db = await _db;
    final rows = await db.rawQuery(
      '$_join WHERE a.patient_id = ? ORDER BY a.start_at DESC LIMIT 100',
      [patientId],
    );
    return rows.map(Appointment.fromMap).toList();
  }

  Future<int> insert(Appointment a) async {
    final db = await _db;
    final data = a.toMap();
    data['created_at'] ??= DateTime.now().toIso8601String();
    return db.insert('appointments', data);
  }

  Future<int> update(Appointment a) async {
    final db = await _db;
    return db.transaction((tx) async {
      final n = await tx.update(
        'appointments',
        a.toMap(),
        where: 'id = ?',
        whereArgs: [a.id],
      );
      // موعد جلسة مرتبط: تاريخ الجلسة المجدولة يتبع الموعد.
      if (a.sessionId != null) {
        await tx.rawUpdate(
          '''UPDATE treatment_sessions SET scheduled_on = ?, updated_at = ?
             WHERE id = ? AND status IN ('requested','scheduled')''',
          [
            DateFmt.isoDate(a.startAt),
            DateTime.now().toIso8601String(),
            a.sessionId,
          ],
        );
      }
      return n;
    });
  }

  Future<int> setStatus(int id, String status) async {
    final db = await _db;
    return db.update(
      'appointments',
      {'status': status},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> delete(int id) async {
    final db = await _db;
    return db.delete('appointments', where: 'id = ?', whereArgs: [id]);
  }

  /// يتحقق من تعارض موعد جديد مع موعد قائم لنفس الطبيب.
  Future<Appointment?> findConflict(
    DateTime start,
    int durationMin, {
    int? exceptId,
  }) async {
    final db = await _db;
    final end = start.add(Duration(minutes: durationMin));
    final rows = await db.rawQuery(
      '''$_join WHERE a.status NOT IN ('cancelled')
         AND julianday(a.start_at) < julianday(?) AND julianday(a.start_at, '+' || a.duration_min || ' minutes') > julianday(?)
         ${exceptId == null ? '' : 'AND a.id != ?'}
         LIMIT 1''',
      exceptId == null
          ? [end.toIso8601String(), start.toIso8601String()]
          : [end.toIso8601String(), start.toIso8601String(), exceptId],
    );
    return rows.isEmpty ? null : Appointment.fromMap(rows.first);
  }

  // ------------------------------------------------------------------- المالية
  Future<int> addPayment(Payment p) async {
    final db = await _db;
    final data = p.toMap();
    data['paid_at'] ??= DateTime.now().toIso8601String();
    return db.insert('payments', data);
  }

  Future<List<Payment>> paymentsForPatient(int patientId) async {
    final db = await _db;
    final rows = await db.rawQuery(
      'SELECT pay.*, p.full_name FROM payments pay '
      'JOIN patients p ON p.id = pay.patient_id '
      'WHERE pay.patient_id = ? ORDER BY pay.paid_at DESC',
      [patientId],
    );
    return rows.map(Payment.fromMap).toList();
  }

  Future<int> deletePayment(int id) async {
    final db = await _db;
    return db.delete('payments', where: 'id = ?', whereArgs: [id]);
  }

  Future<double> incomeBetween(DateTime from, DateTime to) async {
    final db = await _db;
    final rows = await db.rawQuery(
      'SELECT COALESCE(SUM(amount),0) AS total FROM payments '
      'WHERE paid_at >= ? AND paid_at < ?',
      [from.toIso8601String(), to.toIso8601String()],
    );
    return (rows.first['total'] as num?)?.toDouble() ?? 0;
  }
}

