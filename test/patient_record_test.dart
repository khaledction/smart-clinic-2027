import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:neuro_clinic/core/database/app_database.dart';
import 'package:neuro_clinic/core/database/schema.dart';
import 'package:neuro_clinic/core/utils/age_input.dart';
import 'package:neuro_clinic/data/models/patient.dart';
import 'package:neuro_clinic/data/models/visit.dart';
import 'package:neuro_clinic/data/repositories/patient_repository.dart';
import 'package:neuro_clinic/data/repositories/visit_repository.dart';

import 'fixtures/schema_v1.dart' as legacy;

void main() {
  test(
    'Age accepts both numeral scripts, blank, and zero; rejects invalid input',
    () {
      expect(parseAge('٤٥'), 45);
      expect(parseAge('۴۵'), 45);
      expect(parseAge('45'), 45);
      expect(validateAge(''), null);
      expect(validateAge('0'), null);
      expect(validateAge('٣٤'), null);
      for (final value in ['-1', '131', '45.5', 'abc', '+2']) {
        expect(validateAge(value), isNotNull);
      }
    },
  );
  group('Medical record', () {
    late Database db;
    setUp(() async {
      sqfliteFfiInit();
      db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      await enableForeignKeys(db);
      await createSchema(db);
      AppDatabase.instance.useTestDatabase(db);
    });
    tearDown(() => AppDatabase.instance.close());
    test(
      'Numeric age persists without manufacturing a date of birth',
      () async {
        final id = await PatientRepository().insert(
          Patient(
            fullName: 'عمر رقمي',
            ageYears: 45,
            ageRecordedOn: DateTime(2026, 9, 20),
          ),
        );
        final p = await PatientRepository().byId(id);
        expect(p?.birthDate, null);
        expect(p?.age, 45);
        expect(p?.ageRecordedOn, DateTime(2026, 9, 20));
      },
    );
    test('Unknown age stays null and zero remains valid', () async {
      final repo = PatientRepository();
      final id = await repo.insert(const Patient(fullName: 'بدون عمر'));
      expect((await repo.byId(id))?.age, null);
      final zero = await repo.insert(
        const Patient(fullName: 'عمر صفر', ageYears: 0),
      );
      expect((await repo.byId(zero))?.age, 0);
    });
    test(
      'Saving a new visit preserves the old visit and isolates patient records',
      () async {
        final patients = PatientRepository();
        final visits = VisitRepository();
        final a = await patients.insert(
          const Patient(fullName: 'مريض أول', ageYears: 45),
        );
        final b = await patients.insert(
          const Patient(fullName: 'مريض آخر', ageYears: 60),
        );
        final first = await visits.saveFull(
          Visit(
            patientId: a,
            visitDate: DateTime(2026, 1, 1),
            chiefComplaint: 'شكوى أولى',
            diagnosis: 'تشخيص أول',
          ),
          exam: const NeuroExam(gcs: 15),
          prescriptions: const [Prescription(drug: 'TEST ONLY')],
        );
        final original = await visits.full(first);
        await visits.saveFull(
          Visit(
            patientId: b,
            visitDate: DateTime(2026, 2, 1),
            chiefComplaint: 'خاص بالمريض الآخر',
          ),
        );
        await visits.saveFull(
          Visit(
            patientId: a,
            visitDate: DateTime(2026, 3, 1),
            chiefComplaint: 'متابعة',
          ),
        );
        final list = await visits.forPatient(a);
        expect(list.length, 2);
        expect(list.first.chiefComplaint, 'متابعة');
        expect(list.last.id, first);
        expect(list.every((v) => v.patientId == a), true);
        final unchanged = await visits.full(first);
        expect(unchanged?.toMap(), original?.toMap());
        expect(unchanged?.exam?.gcs, 15);
        expect(unchanged?.prescriptions.single.drug, 'TEST ONLY');
      },
    );
    test('Age snapshot survives a later patient edit', () async {
      final patients = PatientRepository();
      final visits = VisitRepository();
      final id = await patients.insert(
        Patient(
          fullName: 'اختبار العمر',
          ageYears: 45,
          ageRecordedOn: DateTime(2026, 1, 1),
        ),
      );
      final vid = await visits.saveFull(
        Visit(patientId: id, visitDate: DateTime(2026, 1, 2)),
      );
      final patient = (await patients.byId(id))!;
      await patients.update(
        patient.copyWith(ageYears: 46, ageRecordedOn: DateTime(2027, 1, 1)),
      );
      expect((await visits.full(vid))?.patientAgeYears, 45);
      expect((await visits.full(vid))?.patientAgeRecordedOn, '2026-01-01');
      expect((await patients.byId(id))?.age, 46);
    });
  });
  test('Real v1 database upgrades on open without dropping patients, visits or payments', () async {
    sqfliteFfiInit();
    final temp = await Directory.systemTemp.createTemp('clinic-upgrade-');
    final path = '${temp.path}/clinic.db';
    Database? db;
    try {
      db = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, version) => legacy.createSchema(db),
        ),
      );
      await db.insert('patients', {
        'id': 1,
        'full_name': 'مريض سابق',
        'birth_date': '1980-02-03',
      });
      await db.insert('visits', {
        'id': 1,
        'patient_id': 1,
        'visit_date': '2025-01-01',
        'chief_complaint': 'سجل لا يتغير',
      });
      await db.insert('payments', {
        'patient_id': 1,
        'visit_id': 1,
        'amount': 75000,
      });
      await db.close();
      db = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: kSchemaVersion,
          onUpgrade: migrate,
          onConfigure: enableForeignKeys,
        ),
      );
      expect(await db.getVersion(), 7);
      final p = (await db.query('patients')).single;
      expect(p['birth_date'], '1980-02-03');
      expect(p['age_years'], null);
      final visit = (await db.query('visits')).single;
      expect(visit['chief_complaint'], 'سجل لا يتغير');
      expect(visit['patient_age_years'], null);
      expect((await db.query('payments')).single['amount'], 75000);
      await db.close();
      db = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: kSchemaVersion,
          onUpgrade: migrate,
        ),
      );
      expect((await db.query('patients')).length, 1);
    } finally {
      await db?.close();
      await temp.delete(recursive: true);
    }
  });
}

