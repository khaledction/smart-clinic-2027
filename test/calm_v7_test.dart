import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:neuro_clinic/core/database/app_database.dart';
import 'package:neuro_clinic/core/database/schema.dart';
import 'package:neuro_clinic/core/database/seed.dart';
import 'package:neuro_clinic/core/utils/date_fmt.dart';
import 'package:neuro_clinic/core/widgets/date_input.dart';
import 'package:neuro_clinic/data/models/appointment.dart';
import 'package:neuro_clinic/data/models/patient.dart';
import 'package:neuro_clinic/data/models/visit.dart';
import 'package:neuro_clinic/data/repositories/appointment_repository.dart';
import 'package:neuro_clinic/data/repositories/clinic_flow_repository.dart';
import 'package:neuro_clinic/data/repositories/patient_repository.dart';
import 'package:neuro_clinic/data/repositories/treatment_repository.dart';
import 'package:neuro_clinic/data/repositories/visit_repository.dart';

import 'fixtures/schema_v5.dart' as old;

void main() {
  group('Date input (day/month/year)', () {
    test('parseInput accepts 1–2 digit day/month and Arabic digits', () {
      expect(DateFmt.parseInput('2/5/2023'), DateTime(2023, 5, 2));
      expect(DateFmt.parseInput('02/05/2023'), DateTime(2023, 5, 2));
      expect(DateFmt.parseInput('٢/٥/٢٠٢٣'), DateTime(2023, 5, 2));
      expect(DateFmt.parseInput('2-5-2023'), DateTime(2023, 5, 2));
      expect(DateFmt.parseInput(' 2 . 5 . 2023 '), DateTime(2023, 5, 2));
      expect(DateFmt.parseInput('31/2/2023'), isNull);
      expect(DateFmt.parseInput('2/13/2023'), isNull);
      expect(DateFmt.parseInput('2/5/23'), isNull);
      expect(DateFmt.parseInput(''), isNull);
      expect(DateFmt.date(DateTime(2023, 5, 2)), '2/5/2023');
    });

    test('formatter normalizes digits and inserts slashes', () {
      expect(DateInputFormatter.format('02052023'), '02/05/2023');
      expect(DateInputFormatter.format('٢/٥/٢٠٢٣'), '2/5/2023');
      expect(DateInputFormatter.format('2-5-2023'), '2/5/2023');
      expect(DateInputFormatter.format('020520239'), '02/05/2023');
      expect(DateInputFormatter.format('2/'), '2/');
      expect(DateInputFormatter.format('abc'), '');
    });
  });

  test('v5/v6 → v7 migration keeps records and leaves kind NULL', () async {
    sqfliteFfiInit();
    final dir = await Directory.systemTemp.createTemp('v7-mig-');
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
      await legacy.insert('appointments', {
        'patient_id': 1,
        'start_at': '2026-09-20T09:00:00.000',
        'status': 'scheduled',
        'reason': 'سبب قديم',
      });
      await legacy.insert('visits', {
        'patient_id': 1,
        'visit_date': '2026-09-20',
        'visit_type': 'new',
      });
      await legacy.close();

      // نسخة تلقائية قبل الترقية.
      databaseFactory = databaseFactoryFfi;
      final backup = await AppDatabase.backupBeforeUpgrade(path);
      expect(backup, isNotNull);
      expect(await File(backup!).exists(), true);

      legacy = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: kSchemaVersion,
          onUpgrade: migrate,
        ),
      );
      expect(await legacy.getVersion(), 7);
      final appt = (await legacy.query('appointments')).single;
      expect(appt['reason'], 'سبب قديم');
      expect(appt['kind'], isNull);
      expect(appt['session_name'], isNull);
      expect(appt['session_id'], isNull);
      expect(appt['visit_id'], isNull);
      expect(Appointment.fromMap(appt).kindLabel, 'غير محدد');
      expect((await legacy.query('visits')).length, 1);
      await expectLater(
        legacy.insert('appointments', {
          'patient_id': 1,
          'start_at': '2026-09-21T09:00:00.000',
          'kind': 'other',
        }),
        throwsA(isA<DatabaseException>()),
      );
      expect(await legacy.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    } finally {
      await legacy?.close();
      await dir.delete(recursive: true);
    }
  });

  group('Clinic flow', () {
    late Database db;
    late int patient;
    final flow = ClinicFlowRepository();
    final today = DateTime.now();
    final day = DateTime(today.year, today.month, today.day);

    setUp(() async {
      sqfliteFfiInit();
      db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      await enableForeignKeys(db);
      await createSchema(db);
      await seedInitialData(db);
      AppDatabase.instance.useTestDatabase(db);
      patient = await PatientRepository().insert(
        const Patient(fullName: 'مريض المسار'),
      );
      await flow.savePrices(
        checkup: 100,
        sessions: {'جلسة EMS': 120, 'جلسة سحب فقرات': 150},
      );
    });
    tearDown(() => AppDatabase.instance.close());

    Future<int> appt(String? kind, {String? session, int hour = 9}) =>
        AppointmentRepository().insert(
          Appointment(
            patientId: patient,
            startAt: DateTime(day.year, day.month, day.day, hour),
            kind: kind,
            sessionName: session,
          ),
        );

    test('prices are stored in settings and services', () async {
      final prices = await flow.prices();
      expect(prices['checkup'], 100);
      expect(prices['جلسة EMS'], 120);
      expect(prices['جلسة سحب فقرات'], 150);
    });

    test('checkup done links the same-day visit without duplicates', () async {
      final visit = await VisitRepository().saveFull(
        Visit(patientId: patient, visitDate: day, chiefComplaint: 'صداع'),
      );
      final id = await appt('checkup');
      await flow.markAppointmentDone(id);
      final a = (await db.query('appointments')).single;
      expect(a['status'], 'done');
      expect(a['visit_id'], visit);
      expect((await db.query('visits')).length, 1);
      final done = await flow.doneOn(day);
      expect(done.checkups.single.visitId, visit);
      expect(done.checkups.single.isPaid, false);
      expect(done.sessions, isEmpty);

      await TreatmentRepository().payVisit(visit);
      final paid = await flow.doneOn(day);
      expect(paid.checkups.single.paidAmount, 100);
      final pay = (await db.query('payments')).single;
      expect(pay['category'], 'consultation');
    });

    test('checkup done without a visit creates a minimal visit', () async {
      final id = await appt('checkup');
      await flow.markAppointmentDone(id);
      final v = (await db.query('visits')).single;
      expect(v['completed_at'], isNotNull);
      expect(v['visit_category'], isNull);
      expect((await flow.doneOn(day)).checkups.length, 1);
    });

    test('untyped legacy appointment must be typed first', () async {
      final id = await appt(null);
      await expectLater(flow.markAppointmentDone(id), throwsStateError);
      expect((await db.query('appointments')).single['status'], 'scheduled');
    });

    test(
      'session done creates a completed session paid at the price',
      () async {
        final id = await appt('session', session: 'جلسة سحب فقرات');
        await flow.markAppointmentDone(id);
        final a = (await db.query('appointments')).single;
        expect(a['status'], 'done');
        expect(a['session_id'], isNotNull);
        final s = (await db.query('treatment_sessions')).single;
        expect(s['status'], 'completed');
        expect(s['performed_on'], DateFmt.isoDate(day));
        expect(s['price'], 150);
        final done = await flow.doneOn(day);
        expect(done.checkups, isEmpty);
        expect(done.sessions.single.label, 'جلسة سحب فقرات');
        expect(done.sessions.single.payable, true);

        await TreatmentRepository().paySession(s['id'] as int);
        final pay = (await db.query('payments')).single;
        expect(pay['category'], 'session');
        expect(pay['amount'], 150);
        expect((await flow.doneOn(day)).sessions.single.paidAmount, 150);
      },
    );

    test('paySession uses the current settings price', () async {
      final id = await appt('session', session: 'جلسة EMS');
      await flow.markAppointmentDone(id);
      final s = (await db.query('treatment_sessions')).single;
      expect(s['price'], 120);
      await flow.savePrices(
        checkup: 100,
        sessions: {'جلسة EMS': 130, 'جلسة سحب فقرات': 150},
      );
      await TreatmentRepository().paySession(s['id'] as int);
      expect((await db.query('payments')).single['amount'], 130);
      expect((await db.query('treatment_sessions')).single['price'], 130);
    });

    test('visit «جلسة» tab schedules a session appointment', () async {
      final visit = await VisitRepository().saveFull(
        Visit(patientId: patient, visitDate: day),
      );
      final tomorrow = day.add(const Duration(days: 1));
      final apptId = await flow.scheduleSessionFromVisit(
        patientId: patient,
        visitId: visit,
        sessionName: 'جلسة EMS',
        startAt: DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 9),
        durationMin: 20,
      );
      final a = (await db.query(
        'appointments',
        where: 'id = ?',
        whereArgs: [apptId],
      )).single;
      expect(a['kind'], 'session');
      expect(a['session_name'], 'جلسة EMS');
      final s = (await db.query('treatment_sessions')).single;
      expect(s['id'], a['session_id']);
      expect(s['status'], 'scheduled');
      expect(s['scheduled_on'], DateFmt.isoDate(tomorrow));
      expect(s['price'], 120);

      // الموعد يتبع الجلسة عند النقل، ويُنهيها عند «تمت الجلسة».
      await AppointmentRepository().update(
        Appointment.fromMap(a)
            .copyWith(startAt: DateTime(day.year, day.month, day.day, 11)),
      );
      expect(
        (await db.query('treatment_sessions')).single['scheduled_on'],
        DateFmt.isoDate(day),
      );
      await flow.markAppointmentDone(apptId);
      final after = (await db.query('treatment_sessions')).single;
      expect(after['status'], 'completed');
      expect((await db.query('treatment_sessions')).length, 1);
      expect((await flow.doneOn(day)).sessions.single.sessionId, s['id']);

      await expectLater(
        flow.scheduleSessionFromVisit(
          patientId: patient,
          visitId: visit,
          sessionName: 'جلسة غير معتمدة',
          startAt: tomorrow,
        ),
        throwsArgumentError,
      );
    });

    test('session visit from the form records one completed session', () async {
      final id = await appt('session', session: 'جلسة EMS');
      final visit = await VisitRepository().saveFull(
        Visit(
          patientId: patient,
          visitDate: day,
          visitType: 'session',
          sessionName: 'جلسة EMS',
        ),
      );
      await flow.recordSessionVisit(
        patientId: patient,
        visitId: visit,
        sessionName: 'جلسة EMS',
        day: day,
      );
      final a = (await db.query(
        'appointments',
        where: 'id = ?',
        whereArgs: [id],
      )).single;
      expect(a['status'], 'done');
      expect((await db.query('treatment_sessions')).length, 1);
      await TreatmentRepository().completeVisit(visit);
      final done = await flow.doneOn(day);
      // لا تكرار: الجلسة المنفّذة فقط، دون سطر «قديم» للزيارة نفسها.
      expect(done.sessions.length, 1);
      expect(done.sessions.single.payable, true);
      expect(done.checkups, isEmpty);
    });

    test('completing a visit moves the same-day checkup appointment', () async {
      final id = await appt('checkup');
      final visit = await VisitRepository().saveFull(
        Visit(patientId: patient, visitDate: day),
      );
      await TreatmentRepository().completeVisit(visit);
      final a = (await db.query(
        'appointments',
        where: 'id = ?',
        whereArgs: [id],
      )).single;
      expect(a['status'], 'done');
      expect(a['visit_id'], visit);
    });

    test(
      'legacy session visit without orders is listed but not payable',
      () async {
        await db.insert('visits', {
          'patient_id': patient,
          'visit_date': DateFmt.isoDate(day),
          'visit_type': 'procedure',
          'visit_category': 'session',
          'session_name': 'أخرى: جلسة قديمة',
          'completed_at': DateTime.now().toIso8601String(),
        });
        final done = await flow.doneOn(day);
        expect(done.sessions.single.payable, false);
        expect(done.sessions.single.label, 'أخرى: جلسة قديمة');
      },
    );
  });
}
