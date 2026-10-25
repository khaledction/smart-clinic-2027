import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:neuro_clinic/core/database/app_database.dart';
import 'package:neuro_clinic/core/database/schema.dart';
import 'package:neuro_clinic/core/database/seed.dart';
import 'package:neuro_clinic/data/models/patient.dart';
import 'package:neuro_clinic/data/models/visit.dart';
import 'package:neuro_clinic/data/repositories/patient_repository.dart';
import 'package:neuro_clinic/data/repositories/plan_repository.dart';
import 'package:neuro_clinic/data/repositories/treatment_repository.dart';
import 'package:neuro_clinic/data/repositories/visit_repository.dart';

import 'fixtures/schema_v5.dart' as old;

void main() {
  late Database db;
  late int patient;
  late int visit;
  final plans = PlanRepository();

  setUp(() async {
    sqfliteFfiInit();
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await enableForeignKeys(db);
    await createSchema(db);
    await seedInitialData(db);
    AppDatabase.instance.useTestDatabase(db);
    patient = await PatientRepository().insert(
      const Patient(fullName: 'اختبار الخطة'),
    );
    visit = await VisitRepository().saveFull(
      Visit(patientId: patient, visitDate: DateTime(2026, 9, 21)),
    );
  });
  tearDown(() => AppDatabase.instance.close());

  test(
    'Plan creates one session at catalog price plus imaging and referrals',
    () async {
      await TreatmentRepository().saveService(
        'جلسة EMS',
        200,
        id:
            (await TreatmentRepository().services()).firstWhere(
                  (s) => s['name'] == 'جلسة EMS',
                )['id']
                as int,
      );
      final created = await plans.save(
        patientId: patient,
        visitId: visit,
        sessionName: 'جلسة EMS',
        imagingKind: 'طبقي محوري',
        consultationDoctor: 'د. استشاري تجريبي',
        consultationReason: 'رأي ثانٍ',
        transferTarget: 'مشفى',
        transferDestination: 'مشفى تجريبي',
        transferReason: 'متابعة',
      );
      expect(created, {'sessions': 1, 'investigations': 1, 'referrals': 2});

      final sessions = await TreatmentRepository().sessions(visitId: visit);
      expect(sessions.length, 1);
      expect(sessions.single['price'], 200);
      expect(sessions.single['status'], 'requested');

      final inv = await db.query('investigations');
      expect(inv.single['kind'], 'طبقي محوري');
      expect(inv.single['workflow_status'], 'requested');
      expect(inv.single['visit_id'], visit);

      final refs = await db.query('referrals', orderBy: 'id ASC');
      expect(refs.length, 2);
      expect(refs[0]['category'], 'consultation');
      expect(refs[0]['destination'], 'د. استشاري تجريبي');
      expect(refs[1]['category'], 'transfer');
      expect(refs[1]['target_type'], 'مشفى');
      expect(refs[1]['visit_id'], visit);
      expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    },
  );

  test(
    'Empty plan creates nothing; custom session waits for pricing',
    () async {
      final created = await plans.save(
        patientId: patient,
        visitId: visit,
        sessionName: '  ',
      );
      expect(created, {'sessions': 0, 'investigations': 0, 'referrals': 0});
      expect(await db.query('treatment_orders'), isEmpty);

      await plans.save(
        patientId: patient,
        visitId: visit,
        sessionName: 'جلسة مخصصة غير مسعرة',
      );
      final sessions = await TreatmentRepository().sessions(visitId: visit);
      expect(sessions.single['price'], 0);
      // Unpriced sessions cannot be charged until priced in the module.
      await expectLater(
        TreatmentRepository().paySession(sessions.single['id'] as int),
        throwsStateError,
      );
    },
  );

  test('Plan rejects a visit belonging to another patient', () async {
    final other = await PatientRepository().insert(
      const Patient(fullName: 'مريض آخر'),
    );
    await expectLater(
      plans.save(patientId: other, visitId: visit, imagingKind: 'شعاعي'),
      throwsStateError,
    );
    expect(await db.query('investigations'), isEmpty);
    expect(await db.query('referrals'), isEmpty);
  });

  test('forVisit groups linked requests for the detail screen', () async {
    await plans.save(
      patientId: patient,
      visitId: visit,
      sessionName: 'جلسة سحب فقرات',
      transferTarget: 'عيادة',
      transferDestination: 'عيادة تجريبية',
    );
    final grouped = await plans.forVisit(visit);
    expect(grouped['sessions']!.length, 1);
    expect(grouped['investigations'], isEmpty);
    expect(grouped['referrals']!.single['target_type'], 'عيادة');
  });

  test(
    'Existing schema 5 upgrades to 6 preserving visits and orders',
    () async {
      final dir = await Directory.systemTemp.createTemp('v5-to-v6-');
      Database? legacy;
      try {
        final path = '${dir.path}/old.db';
        legacy = await databaseFactoryFfi.openDatabase(
          path,
          options: OpenDatabaseOptions(
            version: 5,
            onCreate: (d, _) => old.createSchema(d),
          ),
        );
        await legacy.insert('patients', {'id': 1, 'full_name': 'قديم'});
        await legacy.insert('visits', {
          'patient_id': 1,
          'visit_date': '2026-09-20',
          'visit_type': 'new',
        });
        final serviceId = await legacy.insert('treatment_services', {
          'name': 'خدمة قديمة',
          'price': 100,
        });
        final orderId = await legacy.insert('treatment_orders', {
          'patient_id': 1,
          'source_visit_id': 1,
          'service_id': serviceId,
          'service_name': 'خدمة قديمة',
          'planned_count': 2,
          'created_at': '2026-09-20',
        });
        await legacy.insert('treatment_sessions', {
          'order_id': orderId,
          'sequence_no': 1,
          'status': 'completed',
          'price': 100,
        });
        await legacy.close();
        legacy = await databaseFactoryFfi.openDatabase(
          path,
          options: OpenDatabaseOptions(
            version: kSchemaVersion,
            onUpgrade: migrate,
          ),
        );
        expect(await legacy.getVersion(), 7);
        expect((await legacy.query('visits')).length, 1);
        expect(
          (await legacy.query('treatment_sessions')).single['status'],
          'completed',
        );
        expect(
          (await legacy.query(
            'treatment_services',
            where: 'name = ?',
            whereArgs: ['خدمة قديمة'],
          )).single['price'],
          100,
        );
        expect(await legacy.query('referrals'), isEmpty);
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
