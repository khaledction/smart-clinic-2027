import 'package:sqflite/sqflite.dart';

import '../../core/database/app_database.dart';
import '../../core/utils/date_fmt.dart';
import '../../core/utils/neuro_constants.dart';
import '../models/appointment.dart';

/// سطر في قائمة «المنجزة»: معاينة أو جلسة، مع حالة الدفع.
class DoneItem {
  const DoneItem({
    required this.kind,
    required this.patientId,
    required this.patientName,
    required this.label,
    this.visitId,
    this.sessionId,
    this.sourceVisitId,
    this.paidAmount,
    this.payable = true,
    this.note,
  });

  /// 'checkup' أو 'session'.
  final String kind;
  final int patientId;
  final String patientName;
  final String label;
  final int? visitId;
  final int? sessionId;
  final int? sourceVisitId;
  final double? paidAmount;

  /// false للسجلات القديمة التي لا يمكن ربط دفعها تلقائياً.
  final bool payable;
  final String? note;

  bool get isPaid => paidAmount != null;
  bool get isSession => kind == 'session';
}

/// المنجزة في يوم واحد، مفصولة: معاينات وجلسات.
class DoneDay {
  const DoneDay({required this.checkups, required this.sessions});
  final List<DoneItem> checkups;
  final List<DoneItem> sessions;
}

/// مسار العمل اليومي: موعد ← تمت الزيارة/الجلسة ← المنجزة ← الدفع.
/// لا يغيّر السجلات القديمة ولا يخمّن قيمها؛ ينشئ فقط ما يلزم للإنجاز.
class ClinicFlowRepository {
  Future<Database> get _db => AppDatabase.instance.database;

  /// سعر نوع الجلسة من الإعدادات (دليل الخدمات). null إن لم يوجد.
  static Future<Map<String, Object?>?> _service(
    DatabaseExecutor tx,
    String name,
  ) async {
    final rows = await tx.query(
      'treatment_services',
      where: 'name = ?',
      whereArgs: [name.trim()],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  static Future<Map<String, Object?>> _patientSnapshot(
    DatabaseExecutor tx,
    int patientId,
    DateTime visitDate,
  ) async {
    final rows = await tx.query(
      'patients',
      where: 'id = ?',
      whereArgs: [patientId],
      limit: 1,
    );
    if (rows.isEmpty) throw StateError('ملف المريض غير موجود');
    final p = rows.first;
    final data = <String, Object?>{'patient_weight_kg': p['weight_kg']};
    if (p['age_years'] != null) {
      data['patient_age_years'] = p['age_years'];
      data['patient_age_recorded_on'] = p['age_recorded_on'];
    } else {
      final birth = DateFmt.parse(p['birth_date'] as String?);
      if (birth != null && !birth.isAfter(visitDate)) {
        var years = visitDate.year - birth.year;
        if (visitDate.month < birth.month ||
            (visitDate.month == birth.month && visitDate.day < birth.day)) {
          years--;
        }
        data['patient_age_years'] = years;
        data['patient_age_recorded_on'] = DateFmt.isoDate(visitDate);
      }
    }
    return data;
  }

  /// «تمت الزيارة» / «تمت الجلسة»: ينقل الموعد إلى المنجزة.
  /// • معاينة: يربط زيارة المريض في يوم الموعد ويضع completed_at،
  ///   وإن لم توجد زيارة يُنشئ زيارة مختصرة دون قيم سريرية.
  /// • جلسة: يُنهي الجلسة المرتبطة أو أقدم جلسة معلقة من النوع نفسه،
  ///   وإن لم توجد يُنشئ سجل جلسة منفّذة بسعر الإعدادات.
  Future<void> markAppointmentDone(int appointmentId) async {
    final db = await _db;
    await db.transaction((tx) async {
      final rows = await tx.query(
        'appointments',
        where: 'id = ?',
        whereArgs: [appointmentId],
      );
      if (rows.isEmpty) throw StateError('الموعد غير موجود');
      final a = Appointment.fromMap(rows.single);
      if (a.kind == null) {
        throw StateError('حدّد نوع الموعد (معاينة أو جلسة) أولاً');
      }
      final now = DateTime.now().toIso8601String();
      final day = DateTime(a.startAt.year, a.startAt.month, a.startAt.day);
      final dayIso = DateFmt.isoDate(day);

      if (a.kind == 'checkup') {
        var visitId = a.visitId;
        if (visitId == null) {
          final found = await tx.rawQuery(
            '''SELECT v.id FROM visits v
               WHERE v.patient_id = ? AND v.visit_date = ?
                 AND (v.visit_category IS NULL OR v.visit_category != 'session')
                 AND NOT EXISTS (SELECT 1 FROM appointments x
                                 WHERE x.visit_id = v.id AND x.id != ?)
               ORDER BY v.id DESC LIMIT 1''',
            [a.patientId, dayIso, a.id],
          );
          if (found.isNotEmpty) visitId = found.single['id'] as int;
        }
        if (visitId == null) {
          visitId = await tx.insert('visits', {
            'patient_id': a.patientId,
            'visit_date': dayIso,
            'visit_type': 'new',
            'chief_complaint': a.reason?.trim().isEmpty ?? true
                ? null
                : a.reason!.trim(),
            'notes': 'سُجّلت من الموعد عند «تمت الزيارة» دون تفاصيل سريرية',
            'created_at': now,
            'completed_at': now,
            ...await _patientSnapshot(tx, a.patientId, day),
          });
        } else {
          await tx.rawUpdate(
            'UPDATE visits SET completed_at = COALESCE(completed_at, ?) WHERE id = ?',
            [now, visitId],
          );
        }
        await tx.update(
          'appointments',
          {'status': 'done', 'visit_id': visitId},
          where: 'id = ?',
          whereArgs: [a.id],
        );
                // V7: فاتورة تلقائية للمعاينة - لا تكرر
        final existingPay = await tx.query(
          'payments',
          where: 'visit_id = ? AND category = ?',
          whereArgs: [visitId, 'consultation'],
          limit: 1,
        );
        if (existingPay.isEmpty) {
          final settings = await tx.query('clinic_settings', where: 'id = 1', limit: 1);
          final fee = (settings.isNotEmpty ? settings.first['default_fee'] as num? : null)?.toDouble() ?? 0;
          if (fee > 0) {
            await tx.insert('payments', {
              'patient_id': a.patientId,
              'visit_id': visitId,
              'amount': fee,
              'category': 'consultation',
              'method': 'cash',
              'paid_at': null,
              'note': 'فاتورة تلقائية - معاينة $dayIso',
              'auto_generated': 1,
              'invoice_no': 'INV-${DateTime.now().millisecondsSinceEpoch}',
            });
          }
        }
      } else {
        final name = a.sessionName?.trim() ?? '';
        if (name.isEmpty) throw StateError('حدّد نوع الجلسة أولاً');
        var sessionId = a.sessionId;
        if (sessionId == null) {
          final pending = await tx.rawQuery(
            '''SELECT s.id FROM treatment_sessions s
               JOIN treatment_orders o ON o.id = s.order_id
               WHERE o.patient_id = ? AND o.service_name = ?
                 AND s.status IN ('requested','scheduled','in_progress')
                 AND NOT EXISTS (SELECT 1 FROM appointments x
                                 WHERE x.session_id = s.id AND x.id != ?)
               ORDER BY CASE WHEN date(s.scheduled_on) = ? THEN 0 ELSE 1 END,
                        s.scheduled_on IS NULL, s.scheduled_on, s.id
               LIMIT 1''',
            [a.patientId, name, a.id, dayIso],
          );
          if (pending.isNotEmpty) sessionId = pending.single['id'] as int;
        }
        if (sessionId == null) {
          final service = await _service(tx, name);
          final price = (service?['price'] as num?)?.toDouble() ?? 0;
          final sourceVisit = await tx.insert('visits', {
            'patient_id': a.patientId,
            'visit_date': dayIso,
            'visit_type': 'procedure',
            'visit_category': 'session',
            'session_name': name,
            'notes': 'سُجّلت من موعد جلسة عند «تمت الجلسة»',
            'created_at': now,
            'completed_at': now,
            ...await _patientSnapshot(tx, a.patientId, day),
          });
          final orderId = await tx.insert('treatment_orders', {
            'patient_id': a.patientId,
            'source_visit_id': sourceVisit,
            'service_id': service?['id'],
            'service_name': name,
            'planned_count': 1,
            'created_at': now,
          });
          sessionId = await tx.insert('treatment_sessions', {
            'order_id': orderId,
            'sequence_no': 1,
            'status': 'completed',
            'scheduled_on': dayIso,
            'performed_on': dayIso,
            'price': price,
            'updated_at': now,
          });
        } else {
          final s = await tx.query(
            'treatment_sessions',
            where: 'id = ?',
            whereArgs: [sessionId],
          );
          if (s.isEmpty) throw StateError('الجلسة المرتبطة غير موجودة');
          final status = s.single['status'] as String;
          if (status == 'cancelled') {
            throw StateError('الجلسة المرتبطة ملغاة؛ عدّل حالتها أولاً');
          }
          if (status != 'completed') {
            await tx.update(
              'treatment_sessions',
              {
                'status': 'completed',
                'performed_on': dayIso,
                'updated_at': now,
              },
              where: 'id = ?',
              whereArgs: [sessionId],
            );
          }
        }
        await tx.update(
          'appointments',
          {'status': 'done', 'session_id': sessionId},
          where: 'id = ?',
          whereArgs: [a.id],
        );
      }
      await tx.insert('audit_log', {
        'action': 'appointment_done',
        'entity': 'appointments',
        'entity_id': a.id,
        'detail': 'kind=${a.kind}',
        'at': now,
      });
    });
  }

  /// زيارة من نوع «جلسة» حُفظت من نموذج الزيارة: تُسجَّل الجلسة منفّذة
  /// لتظهر في «الجلسات المنجزة» ويمكن دفع أجرها. تُستخدم الجلسة المعلقة
  /// من النوع نفسه إن وُجدت (مثلاً من موعد جلسة اليوم) بدل إنشاء جلسة مكررة.
  Future<int> recordSessionVisit({
    required int patientId,
    required int visitId,
    required String sessionName,
    required DateTime day,
  }) async {
    final name = sessionName.trim();
    if (name.isEmpty) throw ArgumentError('نوع الجلسة مطلوب');
    final db = await _db;
    return db.transaction((tx) async {
      final now = DateTime.now().toIso8601String();
      final dayIso = DateFmt.isoDate(day);
      final start = DateTime(day.year, day.month, day.day);
      final end = start.add(const Duration(days: 1));
      final appts = await tx.query(
        'appointments',
        where:
            "patient_id = ? AND kind = 'session' AND session_name = ? "
            "AND status IN ('scheduled','arrived') "
            'AND start_at >= ? AND start_at < ?',
        whereArgs: [
          patientId,
          name,
          start.toIso8601String(),
          end.toIso8601String(),
        ],
        orderBy: 'start_at',
        limit: 1,
      );
      int? sessionId;
      if (appts.isNotEmpty && appts.single['session_id'] != null) {
        final linked = await tx.query(
          'treatment_sessions',
          where: "id = ? AND status IN ('requested','scheduled','in_progress')",
          whereArgs: [appts.single['session_id']],
        );
        if (linked.isNotEmpty) sessionId = linked.single['id'] as int;
      }
      if (sessionId == null) {
        final pending = await tx.rawQuery(
          '''SELECT s.id FROM treatment_sessions s
             JOIN treatment_orders o ON o.id = s.order_id
             WHERE o.patient_id = ? AND o.service_name = ?
               AND s.status IN ('requested','scheduled','in_progress')
               AND date(s.scheduled_on) = ?
             ORDER BY s.id LIMIT 1''',
          [patientId, name, dayIso],
        );
        if (pending.isNotEmpty) sessionId = pending.single['id'] as int;
      }
      if (sessionId != null) {
        await tx.update(
          'treatment_sessions',
          {'status': 'completed', 'performed_on': dayIso, 'updated_at': now},
          where: 'id = ?',
          whereArgs: [sessionId],
        );
      } else {
        final service = await _service(tx, name);
        final orderId = await tx.insert('treatment_orders', {
          'patient_id': patientId,
          'source_visit_id': visitId,
          'service_id': service?['id'],
          'service_name': name,
          'planned_count': 1,
          'created_at': now,
        });
        sessionId = await tx.insert('treatment_sessions', {
          'order_id': orderId,
          'sequence_no': 1,
          'status': 'completed',
          'scheduled_on': dayIso,
          'performed_on': dayIso,
          'price': (service?['price'] as num?)?.toDouble() ?? 0,
          'updated_at': now,
        });
      }
      if (appts.isNotEmpty) {
        await tx.update(
          'appointments',
          {'status': 'done', 'session_id': sessionId},
          where: 'id = ?',
          whereArgs: [appts.single['id']],
        );
      }
      return sessionId;
    });
  }

  /// تبويب «جلسة» في الزيارة: ينشئ جلسة مجدولة مرتبطة بالزيارة
  /// وموعد جلسة في اليوم والوقت المحددين. يعيد رقم الموعد.
  Future<int> scheduleSessionFromVisit({
    required int patientId,
    required int visitId,
    required String sessionName,
    required DateTime startAt,
    int durationMin = 20,
  }) async {
    final name = sessionName.trim();
    if (!NeuroConstants.sessionOptions.contains(name)) {
      throw ArgumentError('نوع الجلسة غير معتمد');
    }
    final db = await _db;
    return db.transaction((tx) async {
      final source = await tx.query(
        'visits',
        where: 'id = ? AND patient_id = ?',
        whereArgs: [visitId, patientId],
      );
      if (source.isEmpty) throw StateError('الزيارة لا تتبع لهذا المريض');
      final now = DateTime.now().toIso8601String();
      final service = await _service(tx, name);
      final orderId = await tx.insert('treatment_orders', {
        'patient_id': patientId,
        'source_visit_id': visitId,
        'service_id': service?['id'],
        'service_name': name,
        'planned_count': 1,
        'created_at': now,
      });
      final sessionId = await tx.insert('treatment_sessions', {
        'order_id': orderId,
        'sequence_no': 1,
        'status': 'scheduled',
        'scheduled_on': DateFmt.isoDate(startAt),
        'price': (service?['price'] as num?)?.toDouble() ?? 0,
        'updated_at': now,
      });
      return tx.insert('appointments', {
        'patient_id': patientId,
        'start_at': startAt.toIso8601String(),
        'duration_min': durationMin,
        'status': 'scheduled',
        'kind': 'session',
        'session_name': name,
        'session_id': sessionId,
        'created_at': now,
      });
    });
  }

  /// المنجزة في يوم: معاينات (زيارات مكتملة) وجلسات (منفّذة) مع الدفع.
  Future<DoneDay> doneOn(DateTime day) async {
    final db = await _db;
    final iso = DateFmt.isoDate(day);
    final checkups = await db.rawQuery(
      '''SELECT v.id AS visit_id, v.patient_id, p.full_name, v.chief_complaint,
                (SELECT pay.amount FROM payments pay WHERE pay.visit_id = v.id AND pay.category = 'consultation' AND pay.paid_at IS NOT NULL LIMIT 1) AS paid_amount
         FROM visits v JOIN patients p ON p.id = v.patient_id
         WHERE date(v.completed_at) = ?
           AND (v.visit_category IS NULL OR v.visit_category != 'session')
         ORDER BY v.completed_at DESC, v.id DESC''',
      [iso],
    );
    final sessions = await db.rawQuery(
      '''SELECT s.id AS session_id, o.patient_id, p.full_name, o.service_name,
                o.source_visit_id, pay.amount AS paid_amount
         FROM treatment_sessions s
         JOIN treatment_orders o ON o.id = s.order_id
         JOIN patients p ON p.id = o.patient_id
         LEFT JOIN payments pay ON pay.session_id = s.id
         WHERE s.status = 'completed' AND date(s.performed_on) = ?
         ORDER BY s.updated_at DESC, s.id DESC''',
      [iso],
    );
    // زيارات جلسات قديمة (قبل دليل الجلسات) — تُعرض دون زر دفع تلقائي.
    final legacy = await db.rawQuery(
      '''SELECT v.id AS visit_id, v.patient_id, p.full_name, v.session_name
         FROM visits v JOIN patients p ON p.id = v.patient_id
         WHERE date(v.completed_at) = ? AND v.visit_category = 'session'
           AND NOT EXISTS (SELECT 1 FROM treatment_orders o
                           WHERE o.source_visit_id = v.id)
           AND NOT EXISTS (SELECT 1 FROM treatment_sessions s
                           JOIN treatment_orders o ON o.id = s.order_id
                           WHERE o.patient_id = v.patient_id
                             AND o.service_name = v.session_name
                             AND s.status = 'completed'
                             AND date(s.performed_on) = v.visit_date)
         ORDER BY v.completed_at DESC, v.id DESC''',
      [iso],
    );
    return DoneDay(
      checkups: [
        for (final r in checkups)
          DoneItem(
            kind: 'checkup',
            patientId: r['patient_id'] as int,
            patientName: (r['full_name'] as String?) ?? '—',
            label: 'معاينة',
            visitId: r['visit_id'] as int,
            paidAmount: (r['paid_amount'] as num?)?.toDouble(),
            note: r['chief_complaint'] as String?,
          ),
      ],
      sessions: [
        for (final r in sessions)
          DoneItem(
            kind: 'session',
            patientId: r['patient_id'] as int,
            patientName: (r['full_name'] as String?) ?? '—',
            label: (r['service_name'] as String?) ?? 'جلسة',
            sessionId: r['session_id'] as int,
            sourceVisitId: r['source_visit_id'] as int?,
            paidAmount: (r['paid_amount'] as num?)?.toDouble(),
          ),
        for (final r in legacy)
          DoneItem(
            kind: 'session',
            patientId: r['patient_id'] as int,
            patientName: (r['full_name'] as String?) ?? '—',
            label: (r['session_name'] as String?)?.trim().isNotEmpty == true
                ? r['session_name'] as String
                : 'جلسة',
            visitId: r['visit_id'] as int,
            payable: false,
            note: 'سجل جلسة قديم — الدفع من المالية',
          ),
      ],
    );
  }

  /// أسعار المعاينة والجلسات من الإعدادات.
  Future<Map<String, double>> prices() async {
    final db = await _db;
    final settings = await db.query('clinic_settings', where: 'id = 1');
    final result = <String, double>{
      'checkup': settings.isEmpty
          ? 0
          : (settings.single['default_fee'] as num?)?.toDouble() ?? 0,
    };
    for (final name in NeuroConstants.sessionOptions) {
      final s = await _service(db, name);
      result[name] = (s?['price'] as num?)?.toDouble() ?? 0;
    }
    return result;
  }

  /// يحفظ أسعار المعاينة ونوعي الجلسات. لا يغيّر أسعار جلسات مدفوعة.
  Future<void> savePrices({
    required double checkup,
    required Map<String, double> sessions,
  }) async {
    final all = [checkup, ...sessions.values];
    if (all.any((v) => !v.isFinite || v < 0)) {
      throw ArgumentError('الأسعار يجب أن تكون أرقاماً غير سالبة');
    }
    final db = await _db;
    await db.transaction((tx) async {
      await tx.update('clinic_settings', {
        'default_fee': checkup,
      }, where: 'id = 1');
      for (final e in sessions.entries) {
        if (!NeuroConstants.sessionOptions.contains(e.key)) continue;
        final existing = await _service(tx, e.key);
        if (existing == null) {
          await tx.insert('treatment_services', {
            'name': e.key,
            'price': e.value,
          });
        } else {
          await tx.update(
            'treatment_services',
            {'price': e.value, 'active': 1},
            where: 'id = ?',
            whereArgs: [existing['id']],
          );
        }
      }
    });
  }
}
