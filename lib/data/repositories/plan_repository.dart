import 'package:sqflite/sqflite.dart';

import '../../core/database/app_database.dart';
import '../../core/utils/date_fmt.dart';
import 'treatment_repository.dart';

/// Plan actions chosen inside the visit form (session / imaging / consultation /
/// referral). Created only when the user selects them; nothing is inferred.
class PlanRepository {
  Future<Database> get _db => AppDatabase.instance.database;

  Future<Map<String, int>> save({
    required int patientId,
    required int visitId,
    String? sessionName,
    String? imagingKind,
    String? consultationDoctor,
    String? consultationReason,
    String? transferTarget,
    String? transferDestination,
    String? transferReason,
  }) async {
    final db = await _db;
    final visits = await db.query(
      'visits',
      where: 'id = ? AND patient_id = ?',
      whereArgs: [visitId, patientId],
    );
    if (visits.isEmpty) {
      throw StateError('الزيارة لا تتبع لهذا المريض');
    }
    final visitDate =
        (visits.single['visit_date'] as String?) ??
        DateFmt.isoDate(DateTime.now());
    final created = {'sessions': 0, 'investigations': 0, 'referrals': 0};

    final session = sessionName?.trim() ?? '';
    if (session.isNotEmpty) {
      final services = await TreatmentRepository().services();
      final match = services
          .where((s) => (s['name'] as String).trim() == session)
          .toList();
      await TreatmentRepository().request(
        patientId: patientId,
        sourceVisitId: visitId,
        name: session,
        count: 1,
        price: match.isEmpty ? 0 : ((match.single['price'] as num).toDouble()),
        serviceId: match.isEmpty ? null : match.single['id'] as int?,
      );
      created['sessions'] = 1;
    }

    final imaging = imagingKind?.trim() ?? '';
    if (imaging.isNotEmpty) {
      await db.insert('investigations', {
        'patient_id': patientId,
        'visit_id': visitId,
        'kind': imaging,
        'performed_on': visitDate,
        'workflow_status': 'requested',
        'created_at': DateTime.now().toIso8601String(),
      });
      created['investigations'] = 1;
    }

    Future<void> referral({
      required String category,
      required String target,
      String? destination,
      String? reason,
    }) async {
      await db.insert('referrals', {
        'patient_id': patientId,
        'visit_id': visitId,
        'category': category,
        'target_type': target,
        'destination': destination,
        'reason': reason,
        'created_at': DateTime.now().toIso8601String(),
      });
      created['referrals'] = created['referrals']! + 1;
    }

    if ((consultationDoctor?.trim().isNotEmpty ?? false)) {
      await referral(
        category: 'consultation',
        target: 'استشارة',
        destination: consultationDoctor!.trim(),
        reason: consultationReason?.trim().isEmpty ?? true
            ? null
            : consultationReason!.trim(),
      );
    }
    if ((transferTarget?.trim().isNotEmpty ?? false)) {
      await referral(
        category: 'transfer',
        target: transferTarget!.trim(),
        destination: transferDestination?.trim().isEmpty ?? true
            ? null
            : transferDestination!.trim(),
        reason: transferReason?.trim().isEmpty ?? true
            ? null
            : transferReason!.trim(),
      );
    }
    return created;
  }

  /// Everything the plan created for one visit, for the detail screen.
  Future<Map<String, List<Map<String, Object?>>>> forVisit(int visitId) async {
    final db = await _db;
    return {
      'sessions': await TreatmentRepository().sessions(visitId: visitId),
      'investigations': await db.query(
        'investigations',
        where: 'visit_id = ?',
        whereArgs: [visitId],
        orderBy: 'id ASC',
      ),
      'referrals': await db.query(
        'referrals',
        where: 'visit_id = ?',
        whereArgs: [visitId],
        orderBy: 'id ASC',
      ),
    };
  }
}
