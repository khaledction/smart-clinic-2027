import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:neuro_clinic/core/database/app_database.dart';
import 'package:neuro_clinic/core/database/schema.dart';
import 'package:neuro_clinic/core/database/workflow_schema.dart';
import 'package:neuro_clinic/core/database/seed.dart';
import 'package:neuro_clinic/core/utils/age_input.dart';
import 'package:neuro_clinic/core/printing/clinic_print.dart';
import 'package:neuro_clinic/data/models/patient.dart';
import 'package:neuro_clinic/data/models/visit.dart';
import 'package:neuro_clinic/data/repositories/patient_repository.dart';
import 'package:neuro_clinic/data/repositories/visit_repository.dart';
import 'package:neuro_clinic/data/repositories/treatment_repository.dart';

import 'fixtures/schema_v4.dart' as old;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Database db;
  late int patient, visit;
  final repo = TreatmentRepository();
  setUp(() async {
    sqfliteFfiInit();
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await enableForeignKeys(db);
    await createSchema(db);
    await seedInitialData(db);
    AppDatabase.instance.useTestDatabase(db);
    patient = await PatientRepository().insert(
      const Patient(fullName: 'اختبار سير العمل', weightKg: 72.5),
    );
    visit = await VisitRepository().saveFull(
      Visit(
        patientId: patient,
        visitDate: DateTime(2026, 9, 21),
        diagnosis: 'تشخيص الزيارة الأصلية',
      ),
      prescriptions: [
        const Prescription(
          drug: 'دواء تجريبي — ليس للاستخدام',
          dose: 'جرعة تجريبية',
          durationDays: 3,
        ),
      ],
    );
  });
  tearDown(() => AppDatabase.instance.close());
  test(
    'Numeric weight accepts Arabic decimals and preserves visit snapshot',
    () async {
      expect(parseWeight('٧٢٫٥'), 72.5);
      expect(validateWeight(''), null);
      for (final s in ['0', '-1', 'abc', 'NaN', '701']) {
        expect(validateWeight(s), isNotNull);
      }
      expect((await VisitRepository().full(visit))!.patientWeightKg, 72.5);
      await db.update(
        'patients',
        {'weight_kg': 80},
        where: 'id=?',
        whereArgs: [patient],
      );
      expect((await VisitRepository().full(visit))!.patientWeightKg, 72.5);
    },
  );
  test(
    'Request creates independent sessions and rejects another patient source',
    () async {
      await repo.request(
        patientId: patient,
        sourceVisitId: visit,
        name: 'سحب فقرات',
        count: 3,
        price: 150,
        indication: 'سبب الطلب',
      );
      final rows = await repo.sessions(patientId: patient);
      expect(rows.length, 3);
      expect(rows.first['diagnosis'], null);
      expect(rows.first['result'], null);
      expect(rows.first['source_visit_id'], visit);
      final p2 = await PatientRepository().insert(
        const Patient(fullName: 'مريض آخر'),
      );
      await expectLater(
        repo.request(
          patientId: p2,
          sourceVisitId: visit,
          name: 'جلسة',
          count: 1,
          price: 1,
        ),
        throwsStateError,
      );
      expect(await repo.sessions(patientId: p2), isEmpty);
    },
  );
  test('Service price edits do not rewrite existing session prices', () async {
    final service = (await repo.services()).first;
    await repo.saveService(
      service['name'] as String,
      150,
      id: service['id'] as int,
    );
    await repo.request(
      patientId: patient,
      sourceVisitId: visit,
      name: service['name'] as String,
      count: 1,
      price: 150,
      serviceId: service['id'] as int,
    );
    await repo.saveService(
      service['name'] as String,
      300,
      id: service['id'] as int,
    );
    expect((await repo.sessions()).single['price'], 150);
  });
  test('Finishing visit is independent from sessions and payments; payment idempotent', () async {
    await repo.request(
      patientId: patient,
      sourceVisitId: visit,
      name: 'جلسة',
      count: 2,
      price: 150,
    );
    final rows = await repo.sessions();
    final id = rows.first['id'] as int;
    await repo.completeVisit(visit);
    expect((await repo.sessions()).first['status'], 'requested');
    expect(await db.query('payments'), isEmpty);
    await repo.paySession(id);
    await repo.paySession(id);
    expect((await db.query('payments')).length, 1);
    expect((await db.query('payments')).single['category'], 'session');
    expect((await repo.sessions()).first['status'], 'requested');
    await expectLater(
      repo.saveSession(
        id,
        status: 'completed',
        price: 200,
        performedOn: '2026-09-21',
      ),
      throwsStateError,
    );
    await repo.saveSession(
      id,
      status: 'completed',
      price: 150,
      performedOn: '2026-09-21',
      diagnosis: 'تشخيص مستقل',
      result: 'نتيجة هذه الجلسة',
    );
    final updated = (await repo.sessions()).firstWhere((r) => r['id'] == id);
    expect(updated['diagnosis'], 'تشخيص مستقل');
    expect(updated['completed_count'], 1);
    expect(
      (await VisitRepository().full(visit))!.diagnosis,
      'تشخيص الزيارة الأصلية',
    );
    expect((await db.query('payments')).length, 1);
    expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
  });
  test('Consultation and session finance remain distinct; manual payments block double charge', () async {
    await db.update('clinic_settings', {'default_fee': 250}, where: 'id=1');
    await repo.payVisit(visit);
    await repo.payVisit(visit);
    expect(await repo.visitPaid(visit), true);
    expect((await db.query('payments')).single['category'], 'consultation');
    final other = await VisitRepository().saveFull(
      Visit(patientId: patient, visitDate: DateTime.now()),
    );
    await db.insert('payments', {
      'patient_id': patient,
      'visit_id': other,
      'amount': 100,
    });
    await expectLater(repo.payVisit(other), throwsStateError);
    expect((await db.query('payments')).length, 2);
  });
  test(
    'Re-entrant workflow migration preserves attachments and prices',
    () async {
      final id = await db.insert('investigations', {
        'patient_id': patient,
        'kind': 'تقرير قديم',
      });
      await db.insert('investigation_attachments', {
        'investigation_id': id,
        'name': 'sample.pdf',
        'bytes': Uint8List.fromList([37, 80, 68, 70]),
      });
      final s = (await repo.services()).first;
      await repo.saveService(s['name'] as String, 200, id: s['id'] as int);
      await ensureWorkflowSchema(db);
      await ensureWorkflowSchema(db);
      expect((await repo.services()).first['price'], 200);
      expect(
        (await db.query('investigations')).single['workflow_status'],
        'legacy',
      );
      expect((await db.query('investigation_attachments')).single['bytes'], [
        37,
        80,
        68,
        70,
      ]);
    },
  );
  test(
    'Arabic prescription PDF builds from saved visit without changing its date',
    () async {
      final v = (await VisitRepository().full(visit))!;
      final bytes = await ClinicPrint.prescription(v);
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
      expect(bytes.length, greaterThan(2000));
      final target = Platform.environment['CLINIC_PDF'];
      if (target != null) await File(target).writeAsBytes(bytes);
      expect(
        (await VisitRepository().full(visit))!.visitDate,
        DateTime(2026, 9, 21),
      );
    },
  );
  test(
    'Existing schema 4 upgrades preserving old sessions and payment meaning',
    () async {
      final dir = await Directory.systemTemp.createTemp('v4-to-v5-');
      Database? legacy;
      try {
        final path = '${dir.path}/old.db';
        legacy = await databaseFactoryFfi.openDatabase(
          path,
          options: OpenDatabaseOptions(
            version: 4,
            onCreate: (d, _) => old.createSchema(d),
          ),
        );
        await legacy.insert('patients', {'id': 1, 'full_name': 'قديم'});
        await legacy.insert('visits', {
          'patient_id': 1,
          'visit_date': '2026-09-20',
          'visit_type': 'procedure',
          'visit_category': 'session',
          'session_name': 'اسم قديم',
        });
        await legacy.insert('payments', {'patient_id': 1, 'amount': 50});
        await legacy.close();
        legacy = await databaseFactoryFfi.openDatabase(
          path,
          options: OpenDatabaseOptions(
            version: kSchemaVersion,
            onUpgrade: migrate,
          ),
        );
        expect(await legacy.getVersion(), 7);
        expect(
          (await legacy.query('visits')).single['session_name'],
          'اسم قديم',
        );
        expect((await legacy.query('payments')).single['category'], 'legacy');
        expect(await legacy.query('treatment_sessions'), isEmpty);
        expect(
          (await legacy.rawQuery('PRAGMA integrity_check'))
              .single
              .values
              .single,
          'ok',
        );
      } finally {
        await legacy?.close();
        await dir.delete(recursive: true);
      }
    },
  );
}

