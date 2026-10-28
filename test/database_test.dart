import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:neuro_clinic/core/database/app_database.dart';
import 'package:neuro_clinic/core/database/schema.dart';
import 'package:neuro_clinic/core/database/seed.dart';
import 'package:neuro_clinic/data/models/patient.dart';
import 'package:neuro_clinic/data/models/visit.dart';
import 'package:neuro_clinic/data/models/appointment.dart';
import 'package:neuro_clinic/data/repositories/patient_repository.dart';
import 'package:neuro_clinic/data/repositories/appointment_repository.dart';
import 'package:neuro_clinic/data/repositories/visit_repository.dart';
import 'package:neuro_clinic/data/repositories/reports_repository.dart';
import 'package:neuro_clinic/data/repositories/auth_repository.dart';

void main() {
  late Database db;
  setUp(() async {
    sqfliteFfiInit();
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await enableForeignKeys(db);
    await createSchema(db);
    await seedInitialData(db);
    AppDatabase.instance.useTestDatabase(db);
  });
  tearDown(() => AppDatabase.instance.close());
  test('Arabic patient CRUD, unique file and archive', () async {
    final repo = PatientRepository();
    final id = await repo.insert(
      const Patient(fullName: 'مريض تجريبي', fileNo: 'P-1001'),
    );
    expect((await repo.search(query: 'تجريبي')).single.id, id);
    expect(await repo.nextFileNo(), 'P-1002');
    expect(await repo.fileNoTaken('P-1001'), true);
    await repo.archive(id);
    expect(await repo.count(), 0);
    await repo.restore(id);
    expect(await repo.count(), 1);
  });
  test('Password hash authenticates and disabled account is refused', () async {
    final repo = AuthRepository();
    expect(await repo.login('admin', 'wrong'), null);
    final user = await repo.login('admin', '1234');
    expect(user?.isAdmin, true);
    await repo.setActive(user!.id!, false);
    expect(await repo.login('admin', '1234'), null);
  });
  test('Appointment overlaps, adjacency and exclusion on edit', () async {
    final id = await PatientRepository().insert(
      const Patient(fullName: 'اختبار'),
    );
    final repo = AppointmentRepository();
    final start = DateTime(2026, 9, 19, 10);
    final appointmentId = await repo.insert(
      Appointment(patientId: id, startAt: start),
    );
    expect(
      await repo.findConflict(start.add(const Duration(minutes: 10)), 20),
      isNotNull,
    );
    expect(
      await repo.findConflict(start.add(const Duration(minutes: 20)), 20),
      null,
    );
    expect(await repo.findConflict(start, 20, exceptId: appointmentId), null);
  });
  test(
    'Visit, exam, scale and prescription transaction with cascade',
    () async {
      final id = await PatientRepository().insert(
        const Patient(fullName: 'اختبار'),
      );
      final repo = VisitRepository();
      final vid = await repo.saveFull(
        Visit(patientId: id, visitDate: DateTime.now()),
        exam: const NeuroExam(gcs: 15),
        scales: const [NeuroScale(visitId: 0, scale: 'MMSE', score: 28)],
        prescriptions: const [Prescription(drug: 'TEST ONLY')],
      );
      final visit = await repo.full(vid);
      expect(visit?.exam?.gcs, 15);
      expect(visit?.scales.single.score, 28);
      expect(visit?.prescriptions.single.drug, 'TEST ONLY');
      await repo.delete(vid);
      expect(await db.query('neuro_exam'), isEmpty);
      expect(await db.query('prescriptions'), isEmpty);
    },
  );
  test('Dashboard and 30-day SQL reports execute', () async {
    final repo = ReportsRepository();
    expect((await repo.dashboardNumbers())['patientsTotal'], 0);
    expect((await repo.visitsPerDay()).length, 30);
    await seedDemoData(db);
    expect((await repo.dashboardNumbers())['patientsTotal'], 24);
    expect(await repo.topDiagnoses(), isNotEmpty);
  });
}

