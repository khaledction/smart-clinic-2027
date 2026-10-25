import 'package:sqflite/sqflite.dart';

import '../../core/database/app_database.dart';

class TreatmentRepository {
  Future<Database> get _db => AppDatabase.instance.database;
  Future<List<Map<String, Object?>>> services() async => (await _db).query(
    'treatment_services',
    where: 'active = 1',
    orderBy: 'id',
  );
  Future<void> saveService(String name, double price, {int? id}) async {
    if (name.trim().isEmpty || !price.isFinite || price < 0) {
      throw ArgumentError('اسم وسعر صحيحان مطلوبان');
    }
    final db = await _db;
    if (id == null) {
      await db.insert('treatment_services', {
        'name': name.trim(),
        'price': price,
      });
    } else {
      await db.update(
        'treatment_services',
        {'name': name.trim(), 'price': price},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  Future<int> request({
    required int patientId,
    required int sourceVisitId,
    required String name,
    required int count,
    required double price,
    String? indication,
    int? serviceId,
  }) async {
    if (count < 1 ||
        count > 100 ||
        !price.isFinite ||
        price < 0 ||
        name.trim().isEmpty) {
      throw ArgumentError('تحقق من الخدمة والعدد والسعر');
    }
    final db = await _db;
    return db.transaction((tx) async {
      final source = await tx.query(
        'visits',
        where: 'id = ? AND patient_id = ?',
        whereArgs: [sourceVisitId, patientId],
      );
      if (source.isEmpty) throw StateError('الزيارة لا تتبع لهذا المريض');
      final id = await tx.insert('treatment_orders', {
        'patient_id': patientId,
        'source_visit_id': sourceVisitId,
        'service_id': serviceId,
        'service_name': name.trim(),
        'indication': indication,
        'planned_count': count,
        'created_at': DateTime.now().toIso8601String(),
      });
      for (var i = 1; i <= count; i++) {
        await tx.insert('treatment_sessions', {
          'order_id': id,
          'sequence_no': i,
          'price': price,
        });
      }
      return id;
    });
  }

  Future<List<Map<String, Object?>>> sessions({
    int? patientId,
    int? visitId,
  }) async {
    final db = await _db;
    return db.rawQuery(
      '''SELECT s.*, o.patient_id, o.source_visit_id, o.service_name,
      o.indication, o.planned_count, o.created_at AS ordered_at, p.full_name,
      pay.id AS payment_id,
      (SELECT COUNT(*) FROM treatment_sessions x WHERE x.order_id = o.id AND x.status = 'completed') AS completed_count
      FROM treatment_sessions s JOIN treatment_orders o ON o.id=s.order_id
      JOIN patients p ON p.id=o.patient_id LEFT JOIN payments pay ON pay.session_id=s.id
      WHERE (? IS NULL OR o.patient_id=?) AND (? IS NULL OR o.source_visit_id=?)
      ORDER BY COALESCE(s.performed_on,s.scheduled_on,o.created_at) DESC, s.id''',
      [patientId, patientId, visitId, visitId],
    );
  }

  Future<void> saveSession(
    int id, {
    required String status,
    required double price,
    String? scheduledOn,
    String? performedOn,
    String? diagnosis,
    String? result,
    String? notes,
  }) async {
    if (![
          'requested',
          'scheduled',
          'in_progress',
          'completed',
          'cancelled',
        ].contains(status) ||
        !price.isFinite ||
        price < 0) {
      throw ArgumentError('قيم غير صالحة');
    }
    if (status == 'completed' &&
        (performedOn == null || DateTime.tryParse(performedOn) == null)) {
      throw ArgumentError('تاريخ التنفيذ مطلوب');
    }
    if (status == 'scheduled' &&
        (scheduledOn == null || DateTime.tryParse(scheduledOn) == null)) {
      throw ArgumentError('تاريخ الموعد مطلوب للجلسة المجدولة');
    }
    final db = await _db;
    await db.transaction((tx) async {
      final before = (await tx.query(
        'treatment_sessions',
        where: 'id=?',
        whereArgs: [id],
      )).single;
      final paid = await tx.query(
        'payments',
        where: 'session_id=?',
        whereArgs: [id],
      );
      if (paid.isNotEmpty &&
          ((before['price'] as num).toDouble() != price ||
              status == 'cancelled')) {
        throw StateError(
          'لا يمكن تغيير سعر جلسة مدفوعة أو إلغاؤها دون معالجة مالية مستقلة',
        );
      }
      await tx.update(
        'treatment_sessions',
        {
          'status': status,
          'price': price,
          'scheduled_on': scheduledOn,
          'performed_on': performedOn,
          'diagnosis': diagnosis,
          'result': result,
          'notes': notes,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id=?',
        whereArgs: [id],
      );
      // موعد الجلسة المرتبط يتبع حالة الجلسة (ينتقل إلى المنجزة عند التنفيذ).
      if (status == 'completed') {
        await tx.rawUpdate(
          "UPDATE appointments SET status = 'done' "
          "WHERE session_id = ? AND status IN ('scheduled','arrived')",
          [id],
        );
      } else if (status == 'cancelled') {
        await tx.rawUpdate(
          "UPDATE appointments SET status = 'cancelled' "
          "WHERE session_id = ? AND status IN ('scheduled','arrived')",
          [id],
        );
      }
      await tx.insert('audit_log', {
        'action': 'session_edit',
        'entity': 'treatment_sessions',
        'entity_id': id,
        'detail': 'before=$before',
        'at': DateTime.now().toIso8601String(),
      });
    });
  }

  Future<void> paySession(int id) async {
    final db = await _db;
    await db.transaction((tx) async {
      if ((await tx.query(
        'payments',
        where: 'session_id=?',
        whereArgs: [id],
      )).isNotEmpty) {
        return;
      }
      final row = (await tx.rawQuery(
        'SELECT s.*, o.patient_id, o.service_name FROM treatment_sessions s JOIN treatment_orders o ON o.id=s.order_id WHERE s.id=?',
        [id],
      )).single;
      // السعر المعتمد من الإعدادات لنوع الجلسة؛ وإلا السعر المحفوظ بالجلسة.
      final service = await tx.query(
        'treatment_services',
        where: 'name = ?',
        whereArgs: [row['service_name']],
        limit: 1,
      );
      final servicePrice = service.isEmpty
          ? 0.0
          : (service.single['price'] as num).toDouble();
      final price = servicePrice > 0
          ? servicePrice
          : (row['price'] as num).toDouble();
      if (price <= 0 || row['status'] == 'cancelled') {
        throw StateError(
          'حدّد سعر الجلسة في الإعدادات أولاً، ولا تسجل دفعاً لجلسة ملغاة',
        );
      }
      if (price != (row['price'] as num).toDouble()) {
        await tx.update(
          'treatment_sessions',
          {'price': price},
          where: 'id=?',
          whereArgs: [id],
        );
      }
      await tx.insert('payments', {
        'patient_id': row['patient_id'],
        'session_id': id,
        'category': 'session',
        'service_label': row['service_name'],
        'amount': price,
        'paid_at': DateTime.now().toIso8601String(),
        'method': 'cash',
      });
    });
  }

  Future<void> payVisit(int id) async {
    final db = await _db;
    await db.transaction((tx) async {
      if ((await tx.query(
        'payments',
        where: "visit_id=? AND category='consultation'",
        whereArgs: [id],
      )).isNotEmpty) {
        return;
      }
      // Existing manual payments need review, not an automatic second payment.
      if ((await tx.query(
        'payments',
        where: 'visit_id=?',
        whereArgs: [id],
      )).isNotEmpty) {
        throw StateError(
          'توجد دفعات قديمة مرتبطة بالزيارة. راجعها في المالية لتجنب التكرار',
        );
      }
      final visit = (await tx.query(
        'visits',
        where: 'id=?',
        whereArgs: [id],
      )).single;
      final settings = (await tx.query(
        'clinic_settings',
        where: 'id=1',
      )).single;
      final price = (settings['default_fee'] as num).toDouble();
      if (price <= 0) {
        throw StateError('حدّد سعر المعاينة في الإعدادات أولاً');
      }
      await tx.insert('payments', {
        'patient_id': visit['patient_id'],
        'visit_id': id,
        'category': 'consultation',
        'service_label': 'كشف / مراجعة',
        'amount': price,
        'paid_at': DateTime.now().toIso8601String(),
        'method': 'cash',
      });
    });
  }

  Future<bool> visitPaid(int id) async => (await (await _db).query(
    'payments',
    where: "visit_id=? AND category='consultation'",
    whereArgs: [id],
  )).isNotEmpty;

  /// إنهاء الزيارة. موعد المعاينة المعلّق للمريض في يوم الزيارة
  /// ينتقل معها إلى «المعاينات المنجزة» (دون تغيير المواعيد القديمة غير المحددة).
  Future<void> completeVisit(int id) async {
    final db = await _db;
    await db.transaction((tx) async {
      await tx.update(
        'visits',
        {'completed_at': DateTime.now().toIso8601String()},
        where: 'id=?',
        whereArgs: [id],
      );
      final v = await tx.query('visits', where: 'id=?', whereArgs: [id]);
      if (v.isEmpty || v.single['visit_category'] == 'session') return;
      final linked = await tx.query(
        'appointments',
        where: 'visit_id=?',
        whereArgs: [id],
        limit: 1,
      );
      if (linked.isNotEmpty) return;
      final appt = await tx.rawQuery(
        '''SELECT id FROM appointments
           WHERE patient_id = ? AND kind = 'checkup' AND visit_id IS NULL
             AND status IN ('scheduled','arrived') AND date(start_at) = ?
           ORDER BY start_at LIMIT 1''',
        [v.single['patient_id'], v.single['visit_date']],
      );
      if (appt.isEmpty) return;
      await tx.update(
        'appointments',
        {'status': 'done', 'visit_id': id},
        where: 'id=?',
        whereArgs: [appt.single['id']],
      );
    });
  }
}
