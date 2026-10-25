import 'package:sqflite/sqflite.dart';

import '../../core/database/app_database.dart';
import '../../core/utils/date_fmt.dart';

/// إحصائيات لوحة اليوم والتقارير — كلها استعلامات SQL مباشرة.
class ReportsRepository {
  Future<Database> get _db => AppDatabase.instance.database;

  /// أرقام لوحة اليوم.
  Future<Map<String, num>> dashboardNumbers() async {
    final db = await _db;
    final today = DateFmt.isoDate(DateTime.now());
    final now = DateTime.now();
    final startOfToday = DateTime(
      now.year,
      now.month,
      now.day,
    ).toIso8601String();
    final endOfToday = DateTime(
      now.year,
      now.month,
      now.day + 1,
    ).toIso8601String();
    final startOfMonth = DateTime(now.year, now.month, 1).toIso8601String();

    Future<int> scalar(String sql, [List<Object?> args = const []]) async {
      final rows = await db.rawQuery(sql, args);
      return (rows.first.values.first as num?)?.toInt() ?? 0;
    }

    Future<double> scalarDouble(
      String sql, [
      List<Object?> args = const [],
    ]) async {
      final rows = await db.rawQuery(sql, args);
      return (rows.first.values.first as num?)?.toDouble() ?? 0;
    }

    return {
      'patientsTotal': await scalar(
        'SELECT COUNT(*) FROM patients WHERE is_active = 1',
      ),
      'appointmentsToday': await scalar(
        'SELECT COUNT(*) FROM appointments WHERE date(start_at) = ? AND status != ?',
        [today, 'cancelled'],
      ),
      'visitsToday': await scalar(
        'SELECT COUNT(*) FROM visits WHERE visit_date = ?',
        [today],
      ),
      'newPatientsMonth': await scalar(
        'SELECT COUNT(*) FROM patients WHERE created_at >= ?',
        [startOfMonth],
      ),
      'incomeToday': await scalarDouble(
        'SELECT COALESCE(SUM(amount),0) FROM payments WHERE paid_at >= ? AND paid_at < ?',
        [startOfToday, endOfToday],
      ),
      'incomeMonth': await scalarDouble(
        'SELECT COALESCE(SUM(amount),0) FROM payments WHERE paid_at >= ?',
        [startOfMonth],
      ),
      // الفصل بين المعاينات والجلسات (المواعيد القديمة غير المحددة لا تُحسب هنا).
      'checkupAppointmentsToday': await scalar(
        "SELECT COUNT(*) FROM appointments WHERE date(start_at) = ? AND kind = 'checkup' AND status NOT IN ('cancelled','no_show')",
        [today],
      ),
      'sessionAppointmentsToday': await scalar(
        "SELECT COUNT(*) FROM appointments WHERE date(start_at) = ? AND kind = 'session' AND status NOT IN ('cancelled','no_show')",
        [today],
      ),
      'checkupsDoneToday': await scalar(
        "SELECT COUNT(*) FROM visits WHERE date(completed_at) = ? AND (visit_category IS NULL OR visit_category != 'session')",
        [today],
      ),
      'sessionsDoneToday': await scalar(
        "SELECT COUNT(*) FROM treatment_sessions WHERE status = 'completed' AND date(performed_on) = ?",
        [today],
      ),
      'incomeConsultationToday': await scalarDouble(
        "SELECT COALESCE(SUM(amount),0) FROM payments WHERE category = 'consultation' AND paid_at >= ? AND paid_at < ?",
        [startOfToday, endOfToday],
      ),
      'incomeConsultationMonth': await scalarDouble(
        "SELECT COALESCE(SUM(amount),0) FROM payments WHERE category = 'consultation' AND paid_at >= ?",
        [startOfMonth],
      ),
      'incomeSessionToday': await scalarDouble(
        "SELECT COALESCE(SUM(amount),0) FROM payments WHERE category = 'session' AND paid_at >= ? AND paid_at < ?",
        [startOfToday, endOfToday],
      ),
      'incomeSessionMonth': await scalarDouble(
        "SELECT COALESCE(SUM(amount),0) FROM payments WHERE category = 'session' AND paid_at >= ?",
        [startOfMonth],
      ),
      'pendingFollowUps': await scalar(
        '''SELECT COUNT(*) FROM visits v
           WHERE v.followup_in_days IS NOT NULL
             AND date(v.visit_date, '+' || v.followup_in_days || ' days') <= ?''',
        [today],
      ),
    };
  }

  /// عدد الزيارات في كل يوم من آخر [days] يوماً (للرسم البياني).
  Future<List<Map<String, Object?>>> visitsPerDay({int days = 30}) async {
    final db = await _db;
    final from = DateFmt.isoDate(
      DateTime.now().subtract(Duration(days: days - 1)),
    );
    return db.rawQuery(
      '''SELECT d.day AS day,
                COALESCE((SELECT COUNT(*) FROM visits v WHERE v.visit_date = d.day), 0) AS count
         FROM (SELECT date(?, '+' || value || ' days') AS day
               FROM (WITH RECURSIVE cnt(value) AS (
                       SELECT 0 UNION ALL SELECT value + 1 FROM cnt WHERE value + 1 < ?
                     ) SELECT value FROM cnt)) d
         ORDER BY d.day ASC''',
      [from, days],
    );
  }

  /// توزيع التشخيصات الأكثر شيوعاً (أعلى 10).
  Future<List<Map<String, Object?>>> topDiagnoses({int limit = 10}) async {
    final db = await _db;
    return db.rawQuery(
      '''SELECT COALESCE(icd10, 'غير مصنّف') AS icd10,
                COALESCE(diagnosis, 'بدون تشخيص') AS diagnosis,
                COUNT(*) AS count
         FROM visits
         GROUP BY icd10, diagnosis
         ORDER BY count DESC
         LIMIT ?''',
      [limit],
    );
  }

  /// توزيع الزيارات حسب النوع.
  Future<List<Map<String, Object?>>> visitsByType() async {
    final db = await _db;
    return db.rawQuery(
      'SELECT COALESCE(visit_category, visit_type) AS type, COUNT(*) AS count FROM visits GROUP BY COALESCE(visit_category, visit_type)',
    );
  }

  /// المنجز شهرياً: معاينات (زيارات مكتملة) وجلسات (منفّذة) لآخر [months] شهراً.
  Future<List<Map<String, Object?>>> monthlyDone({int months = 12}) async {
    final db = await _db;
    return db.rawQuery(
      '''SELECT month,
                SUM(CASE WHEN k = 'checkup' THEN 1 ELSE 0 END) AS checkups,
                SUM(CASE WHEN k = 'session' THEN 1 ELSE 0 END) AS sessions
         FROM (
           SELECT strftime('%Y-%m', completed_at) AS month, 'checkup' AS k
             FROM visits
            WHERE completed_at IS NOT NULL
              AND (visit_category IS NULL OR visit_category != 'session')
           UNION ALL
           SELECT strftime('%Y-%m', performed_on) AS month, 'session' AS k
             FROM treatment_sessions
            WHERE status = 'completed' AND performed_on IS NOT NULL
         )
         WHERE month IS NOT NULL
         GROUP BY month
         ORDER BY month DESC
         LIMIT ?''',
      [months],
    );
  }

  /// إيراد شهري لآخر [months] شهراً.
  Future<List<Map<String, Object?>>> monthlyIncome({int months = 12}) async {
    final db = await _db;
    return db.rawQuery(
      '''SELECT strftime('%Y-%m', paid_at) AS month,
                COALESCE(SUM(amount), 0) AS total,
                COALESCE(SUM(CASE WHEN category = 'consultation' THEN amount END), 0) AS consultation,
                COALESCE(SUM(CASE WHEN category = 'session' THEN amount END), 0) AS session,
                COALESCE(SUM(CASE WHEN category NOT IN ('consultation','session') OR category IS NULL THEN amount END), 0) AS legacy,
                COUNT(*) AS count
         FROM payments
         GROUP BY month
         ORDER BY month DESC
         LIMIT ?''',
      [months],
    );
  }

  /// أعمار المرضى (توزيع فئوي) — مفيد إحصائياً للعيادة.
  Future<List<Map<String, Object?>>> ageDistribution() async {
    final db = await _db;
    return db.rawQuery('''
      SELECT CASE
               WHEN age < 18 THEN 'أقل من 18'
               WHEN age BETWEEN 18 AND 34 THEN '18 - 34'
               WHEN age BETWEEN 35 AND 49 THEN '35 - 49'
               WHEN age BETWEEN 50 AND 64 THEN '50 - 64'
               ELSE '65 فأكثر'
             END AS band,
             COUNT(*) AS count
      FROM (
        SELECT COALESCE(age_years,
          CAST(strftime('%Y', 'now') AS INTEGER) - CAST(strftime('%Y', birth_date) AS INTEGER)
          - (strftime('%m-%d', 'now') < strftime('%m-%d', birth_date))) AS age
        FROM patients WHERE (age_years IS NOT NULL OR birth_date IS NOT NULL) AND is_active = 1
      )
      GROUP BY band
    ''');
  }

  /// تصدير كل المرضى إلى CSV.
  Future<List<List<dynamic>>> patientsExportRows() async {
    final db = await _db;
    final rows = await db.rawQuery(
      'SELECT file_no, full_name, gender, birth_date, phone, address, allergies, '
      'is_active, created_at, age_years, age_recorded_on FROM patients ORDER BY id ASC',
    );
    return rows
        .map(
          (r) => [
            r['file_no'] ?? '',
            r['full_name'] ?? '',
            (r['gender'] == 'm'
                ? 'ذكر'
                : r['gender'] == 'f'
                ? 'أنثى'
                : ''),
            r['birth_date'] ?? '',
            r['phone'] ?? '',
            r['address'] ?? '',
            r['allergies'] ?? '',
            (r['is_active'] == 1 ? 'نشط' : 'مؤرشف'),
            (r['created_at'] as String?)?.substring(0, 10) ?? '',
            r['age_years'] ?? '',
            r['age_recorded_on'] ?? '',
          ],
        )
        .toList();
  }

  /// تصدير الزيارات إلى CSV.
  Future<List<List<dynamic>>> visitsExportRows({
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
      'SELECT v.visit_date, p.file_no, p.full_name, COALESCE(v.visit_category, v.visit_type) AS visit_type, v.chief_complaint, '
      'v.icd10, v.diagnosis, v.plan FROM visits v '
      'JOIN patients p ON p.id = v.patient_id '
      '${where.isEmpty ? '' : 'WHERE $where'} ORDER BY v.visit_date DESC',
      args,
    );
    return rows
        .map(
          (r) => [
            r['visit_date'] ?? '',
            r['file_no'] ?? '',
            r['full_name'] ?? '',
            r['visit_type'] ?? '',
            r['chief_complaint'] ?? '',
            r['icd10'] ?? '',
            r['diagnosis'] ?? '',
            r['plan'] ?? '',
          ],
        )
        .toList();
  }
}
