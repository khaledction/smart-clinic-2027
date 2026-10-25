import 'package:sqflite/sqflite.dart';

import '../../core/database/app_database.dart';
import '../../core/utils/date_fmt.dart';
import '../models/visit.dart';

/// كل ما يتعلق بالزيارات: الفحص العصبي، المقاييس، الوصفات.
class VisitRepository {
  Future<Database> get _db => AppDatabase.instance.database;

  /// زيارات مريض محدد، من الأحدث للأقدم.
  /// Visits finished on a given day (completion stamp, not visit date).
  Future<List<Visit>> completedOn(DateTime day) async {
    final db = await _db;
    final rows = await db.rawQuery(
      'SELECT v.*, p.full_name AS full_name FROM visits v '
      'JOIN patients p ON p.id = v.patient_id '
      'WHERE date(v.completed_at) = ? '
      'ORDER BY v.completed_at DESC, v.id DESC',
      [DateFmt.isoDate(day)],
    );
    return rows.map(Visit.fromMap).toList();
  }

  Future<List<Visit>> forPatient(int patientId) async {
    final db = await _db;
    final rows = await db.query(
      'visits',
      where: 'patient_id = ?',
      whereArgs: [patientId],
      orderBy: 'visit_date DESC, id DESC',
    );
    return rows.map(Visit.fromMap).toList();
  }

  /// آخر الزيارات في العيادة كلها (للوحة اليوم والتقارير).
  Future<List<Visit>> recent({
    int limit = 50,
    DateTime? from,
    DateTime? to,
  }) async {
    final db = await _db;
    final where = StringBuffer();
    final args = <Object?>[];

    if (from != null) {
      where.write('v.visit_date >= ?');
      args.add(DateFmt.isoDate(from));
    }
    if (to != null) {
      if (where.isNotEmpty) where.write(' AND ');
      where.write('v.visit_date <= ?');
      args.add(DateFmt.isoDate(to));
    }

    final rows = await db.rawQuery(
      'SELECT v.*, p.full_name FROM visits v '
      'JOIN patients p ON p.id = v.patient_id '
      '${where.isEmpty ? '' : 'WHERE $where'} '
      'ORDER BY v.visit_date DESC, v.id DESC LIMIT ?',
      [...args, limit],
    );
    return rows.map(Visit.fromMap).toList();
  }

  /// يحمّل زيارة كاملة بكل ملحقاتها (فحص + مقاييس + وصفة).
  Future<Visit?> full(int visitId) async {
    final db = await _db;
    final rows = await db.rawQuery(
      'SELECT v.*, p.full_name FROM visits v '
      'JOIN patients p ON p.id = v.patient_id WHERE v.id = ? LIMIT 1',
      [visitId],
    );
    if (rows.isEmpty) return null;

    final examRows = await db.query(
      'neuro_exam',
      where: 'visit_id = ?',
      whereArgs: [visitId],
      limit: 1,
    );
    final scaleRows = await db.query(
      'neuro_scales',
      where: 'visit_id = ?',
      whereArgs: [visitId],
      orderBy: 'id ASC',
    );
    final prescRows = await db.query(
      'prescriptions',
      where: 'visit_id = ?',
      whereArgs: [visitId],
      orderBy: 'id ASC',
    );

    return Visit.fromMap(rows.first).copyWith(
      exam: examRows.isEmpty ? null : NeuroExam.fromMap(examRows.first),
      scales: scaleRows.map(NeuroScale.fromMap).toList(),
      prescriptions: prescRows.map(Prescription.fromMap).toList(),
    );
  }

  /// يحفظ زيارة جديدة مع كل ملحقاتها في معاملة واحدة (transaction).
  Future<int> saveFull(
    Visit visit, {
    NeuroExam? exam,
    List<NeuroScale> scales = const [],
    List<Prescription> prescriptions = const [],
  }) async {
    final db = await _db;
    return db.transaction((txn) async {
      final data = visit.toMap();
      data['created_at'] ??= DateTime.now().toIso8601String();
      final patients = await txn.query(
        'patients',
        where: 'id = ?',
        whereArgs: [visit.patientId],
        limit: 1,
      );
      if (patients.isEmpty) throw StateError('ملف المريض غير موجود');
      final patient = patients.first;
      data['patient_weight_kg'] = patient['weight_kg'];
      if (patient['age_years'] != null) {
        data['patient_age_years'] = patient['age_years'];
        data['patient_age_recorded_on'] = patient['age_recorded_on'];
      } else {
        final birth = DateFmt.parse(patient['birth_date'] as String?);
        if (birth != null && !birth.isAfter(visit.visitDate)) {
          var years = visit.visitDate.year - birth.year;
          if (visit.visitDate.month < birth.month ||
              (visit.visitDate.month == birth.month &&
                  visit.visitDate.day < birth.day)) {
            years--;
          }
          data['patient_age_years'] = years;
          data['patient_age_recorded_on'] = DateFmt.isoDate(visit.visitDate);
        }
      }
      final visitId = await txn.insert('visits', data);

      if (exam != null && !exam.isEmpty) {
        await txn.insert('neuro_exam', exam.copyWith(visitId: visitId).toMap());
      }
      for (final s in scales) {
        await txn.insert('neuro_scales', s.copyWith(visitId: visitId).toMap());
      }
      for (final p in prescriptions.where((e) => e.drug.trim().isNotEmpty)) {
        await txn.insert('prescriptions', p.copyWith(visitId: visitId).toMap());
      }
      return visitId;
    });
  }

  Future<int> update(Visit visit) async {
    final db = await _db;
    return db.update(
      'visits',
      visit.toMap(),
      where: 'id = ?',
      whereArgs: [visit.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await _db;
    return db.delete('visits', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> upsertExam(NeuroExam exam) async {
    final db = await _db;
    final data = exam.toMap();
    data.remove('id');
    return db.insert(
      'neuro_exam',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// مرضى موعد متابعتهم مستحق (followup_in_days انتهت).
  Future<List<Map<String, Object?>>> dueFollowUps({int withinDays = 7}) async {
    final db = await _db;
    final today = DateFmt.isoDate(DateTime.now());
    final until = DateFmt.isoDate(
      DateTime.now().add(Duration(days: withinDays)),
    );
    return db.rawQuery(
      '''SELECT v.id, v.visit_date, v.followup_in_days, v.diagnosis,
                date(v.visit_date, '+' || v.followup_in_days || ' days') AS due_date,
                p.id AS patient_id, p.full_name, p.phone
         FROM visits v JOIN patients p ON p.id = v.patient_id
         WHERE v.followup_in_days IS NOT NULL
           AND date(v.visit_date, '+' || v.followup_in_days || ' days') <= ?
           AND date(v.visit_date, '+' || v.followup_in_days || ' days') >= ?
         ORDER BY due_date ASC LIMIT 50''',
      [until, today],
    );
  }

  /// كل وصفات مريض (مجمّعة من كل زياراته) — لعرضها في الملف.
  Future<List<Prescription>> prescriptionsForPatient(int patientId) async {
    final db = await _db;
    final rows = await db.rawQuery(
      '''SELECT pr.* FROM prescriptions pr
         JOIN visits v ON v.id = pr.visit_id
         WHERE v.patient_id = ?
         ORDER BY v.visit_date DESC, pr.id ASC''',
      [patientId],
    );
    return rows.map(Prescription.fromMap).toList();
  }

  /// تاريخ نتائج مقياس معيّن لمريض — مفيد لرسم منحنى التدهور/التحسن.
  Future<List<NeuroScale>> scaleHistory(int patientId, String scale) async {
    final db = await _db;
    final rows = await db.rawQuery(
      '''SELECT s.* FROM neuro_scales s
         JOIN visits v ON v.id = s.visit_id
         WHERE v.patient_id = ? AND s.scale = ?
         ORDER BY v.visit_date ASC''',
      [patientId, scale],
    );
    return rows.map(NeuroScale.fromMap).toList();
  }
}
