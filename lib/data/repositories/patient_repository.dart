import 'package:sqflite/sqflite.dart';

import '../../core/database/app_database.dart';
import '../../core/utils/date_fmt.dart';
import '../models/appointment.dart';
import '../models/patient.dart';

/// كل عمليات قاعدة البيانات الخاصة بالمرضى.
class PatientRepository {
  Future<Database> get _db => AppDatabase.instance.database;

  static const _columns =
      'p.*, '
      '(SELECT COUNT(*) FROM visits v WHERE v.patient_id = p.id) AS visits_count, '
      '(SELECT MAX(v.visit_date) FROM visits v WHERE v.patient_id = p.id) AS last_visit';

  /// بحث مع ترقيم صفحات.
  Future<List<Patient>> search({
    String query = '',
    bool onlyActive = true,
    int limit = 100,
    int offset = 0,
  }) async {
    final db = await _db;
    final q = query.trim();
    final where = StringBuffer();
    final args = <Object?>[];

    if (onlyActive) where.write('p.is_active = 1');
    if (q.isNotEmpty) {
      if (where.isNotEmpty) where.write(' AND ');
      where.write(
        '(p.full_name LIKE ? OR p.phone LIKE ? OR p.file_no LIKE ? '
        'OR p.national_id LIKE ?)',
      );
      final like = '%$q%';
      args.addAll([like, like, like, like]);
    }

    final rows = await db.rawQuery(
      'SELECT $_columns FROM patients p '
      '${where.isEmpty ? '' : 'WHERE $where'} '
      'ORDER BY p.id DESC LIMIT ? OFFSET ?',
      [...args, limit, offset],
    );
    return rows.map(Patient.fromMap).toList();
  }

  Future<int> count({String query = '', bool onlyActive = true}) async {
    final db = await _db;
    final q = query.trim();
    final where = StringBuffer();
    final args = <Object?>[];

    if (onlyActive) where.write('is_active = 1');
    if (q.isNotEmpty) {
      if (where.isNotEmpty) where.write(' AND ');
      where.write(
        '(full_name LIKE ? OR phone LIKE ? OR file_no LIKE ? OR national_id LIKE ?)',
      );
      final like = '%$q%';
      args.addAll([like, like, like, like]);
    }

    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM patients ${where.isEmpty ? '' : 'WHERE $where'}',
      args,
    );
    return (rows.first['c'] as int?) ?? 0;
  }

  Future<Patient?> byId(int id) async {
    final db = await _db;
    final rows = await db.query(
      'patients',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : Patient.fromMap(rows.first);
  }

  Future<Patient?> byFileNo(String fileNo) async {
    final db = await _db;
    final rows = await db.query(
      'patients',
      where: 'file_no = ?',
      whereArgs: [fileNo],
      limit: 1,
    );
    return rows.isEmpty ? null : Patient.fromMap(rows.first);
  }

  Future<int> insert(Patient p) async {
    final db = await _db;
    final now = DateTime.now();
    return db.insert(
      'patients',
      p.copyWith(createdAt: now, updatedAt: now).toMap(),
    );
  }

  Future<int> update(Patient p) async {
    final db = await _db;
    return db.update(
      'patients',
      p.copyWith(updatedAt: DateTime.now()).toMap(),
      where: 'id = ?',
      whereArgs: [p.id],
    );
  }

  /// تعطيل بدلاً من الحذف — حتى لا نفقد السجل الطبي.
  Future<int> archive(int id) async {
    final db = await _db;
    return db.update(
      'patients',
      {'is_active': 0, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> restore(int id) async {
    final db = await _db;
    return db.update(
      'patients',
      {'is_active': 1, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// حذف نهائي (يحذف كل ما يتعلق به عبر CASCADE).
  Future<int> deletePermanently(int id) async {
    final db = await _db;
    return db.delete('patients', where: 'id = ?', whereArgs: [id]);
  }

  Future<bool> fileNoTaken(String fileNo, {int? exceptId}) async {
    final db = await _db;
    final rows = await db.query(
      'patients',
      where: exceptId == null ? 'file_no = ?' : 'file_no = ? AND id != ?',
      whereArgs: exceptId == null ? [fileNo] : [fileNo, exceptId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// يولّد رقم ملف تالي تلقائياً بالشكل P-1001
  Future<String> nextFileNo() async {
    final db = await _db;
    final rows = await db.rawQuery(
      "SELECT file_no FROM patients WHERE file_no LIKE 'P-%' ORDER BY id DESC LIMIT 200",
    );
    var max = 1000;
    for (final r in rows) {
      final v = int.tryParse(
        (r['file_no'] as String?)?.replaceFirst('P-', '') ?? '',
      );
      if (v != null && v > max) max = v;
    }
    return 'P-${max + 1}';
  }

  // ------------------------------------------------------- التاريخ المرضي العام
  Future<List<MedicalHistoryItem>> history(int patientId) async {
    final db = await _db;
    final rows = await db.query(
      'medical_history',
      where: 'patient_id = ?',
      whereArgs: [patientId],
      orderBy: 'id ASC',
    );
    return rows.map(MedicalHistoryItem.fromMap).toList();
  }

  Future<int> addHistory(MedicalHistoryItem item) async {
    final db = await _db;
    return db.insert('medical_history', item.toMap());
  }

  Future<int> deleteHistory(int id) async {
    final db = await _db;
    return db.delete('medical_history', where: 'id = ?', whereArgs: [id]);
  }

  // ------------------------------------------------------------ الأدوية المزمنة
  Future<List<Medication>> medications(
    int patientId, {
    bool onlyActive = false,
  }) async {
    final db = await _db;
    final rows = await db.query(
      'medications',
      where: onlyActive ? 'patient_id = ? AND is_active = 1' : 'patient_id = ?',
      whereArgs: [patientId],
      orderBy: 'is_active DESC, id DESC',
    );
    return rows.map(Medication.fromMap).toList();
  }

  Future<int> addMedication(Medication m) async {
    final db = await _db;
    final data = m.toMap();
    data['started_on'] ??= DateFmt.isoDate(DateTime.now());
    return db.insert('medications', data);
  }

  Future<int> updateMedication(Medication m) async {
    final db = await _db;
    return db.update(
      'medications',
      m.toMap(),
      where: 'id = ?',
      whereArgs: [m.id],
    );
  }

  Future<int> deleteMedication(int id) async {
    final db = await _db;
    return db.delete('medications', where: 'id = ?', whereArgs: [id]);
  }

  // --------------------------------------------------------------- الاستقصاءات
  Future<List<Investigation>> investigations(int patientId) async {
    final db = await _db;
    final rows = await db.query(
      'investigations',
      where: 'patient_id = ?',
      whereArgs: [patientId],
      orderBy: 'performed_on DESC, id DESC',
    );
    return rows.map(Investigation.fromMap).toList();
  }

  Future<int> addInvestigation(Investigation inv) async {
    final db = await _db;
    final data = inv.toMap();
    data['created_at'] ??= DateTime.now().toIso8601String();
    return db.insert('investigations', data);
  }

  Future<int> deleteInvestigation(int id) async {
    final db = await _db;
    return db.delete('investigations', where: 'id = ?', whereArgs: [id]);
  }
}

