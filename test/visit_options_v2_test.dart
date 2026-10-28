import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:neuro_clinic/core/database/schema.dart';
import 'package:neuro_clinic/core/database/app_database.dart';
import 'package:neuro_clinic/core/widgets/day_groups.dart';
import 'package:neuro_clinic/data/models/visit.dart';
import 'package:neuro_clinic/data/repositories/visit_repository.dart';
import 'package:neuro_clinic/data/repositories/reports_repository.dart';

import 'fixtures/schema_v2.dart' as old;

void main() {
  test('Schema 2 to current preserves old visits and accepts first/session without rebuilding clinical tables', () async {
    sqfliteFfiInit();
    final dir = await Directory.systemTemp.createTemp('clinic-v3-');
    Database? db;
    try {
      final path = '${dir.path}/test.db';
      db = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 2,
          onCreate: (db, _) => old.createSchema(db),
          onConfigure: enableForeignKeys,
        ),
      );
      await db.insert('patients', {
        'id': 1,
        'full_name': 'اختبار',
        'age_years': 52,
      });
      await db.insert('visits', {
        'id': 1,
        'patient_id': 1,
        'visit_date': '2026-09-20',
        'visit_type': 'followup',
        'diagnosis': 'نص سابق',
      });
      await db.insert('neuro_exam', {
        'visit_id': 1,
        'speech': 'نص كلام قديم',
        'sensation': 'نص إحساس قديم',
      });
      await db.insert('payments', {
        'patient_id': 1,
        'visit_id': 1,
        'amount': 50000,
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
      AppDatabase.instance.useTestDatabase(db);
      final repo = VisitRepository();
      expect((await repo.full(1))?.diagnosis, 'نص سابق');
      expect((await repo.full(1))?.exam?.speech, 'نص كلام قديم');
      expect((await repo.full(1))?.exam?.sensation, 'نص إحساس قديم');
      expect((await db.query('payments')).single['amount'], 50000);
      for (final type in [
        'first',
        'session',
        'new',
        'followup',
        'emergency',
        'procedure',
      ]) {
        final id = await repo.saveFull(
          Visit(
            patientId: 1,
            visitDate: DateTime(2026, 9, 21),
            visitType: type,
          ),
          exam: const NeuroExam(speech: 'بصعوبة', sensation: 'تجاوب ضعيف'),
        );
        final stored = (await repo.full(id))!;
        expect(stored.visitType, type);
        expect(stored.exam?.speech, 'بصعوبة');
        expect(stored.exam?.sensation, 'تجاوب ضعيف');
        await repo.update(stored.copyWith(plan: 'تحديث الخطة'));
        expect((await repo.full(id))?.visitType, type);
      }
      expect(
        (await ReportsRepository().visitsByType()).any(
          (row) => row['type'] == 'session',
        ),
        true,
      );
      final export = await ReportsRepository().visitsExportRows();
      expect(export.any((row) => row[3] == 'first'), true);
      expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    } finally {
      await AppDatabase.instance.close();
      await db?.close();
      await dir.delete(recursive: true);
    }
  });
  testWidgets(
    'Today expands; past days collapse; search reveals historical matches',
    (tester) async {
      final today = DateTime.now();
      final yesterday = today.subtract(const Duration(days: 1));
      Widget build(bool search) => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DayGroups<DateTime>(
              items: [today, yesterday],
              dateOf: (d) => d,
              searching: search,
              groupBuilder: (days) =>
                  Text(days.first == today ? 'اليوم ظاهر' : 'السابق مخفي'),
            ),
          ),
        ),
      );
      await tester.pumpWidget(build(false));
      await tester.pumpAndSettle();
      expect(find.text('اليوم ظاهر'), findsOneWidget);
      expect(find.text('السابق مخفي'), findsNothing);
      String dayLabel(DateTime d) =>
          'يوم ${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
      String monthLabel(DateTime d) =>
          'شهر ${d.year}/${d.month.toString().padLeft(2, '0')}';
      if (monthLabel(yesterday) != monthLabel(today)) {
        await tester.tap(find.textContaining(monthLabel(yesterday)));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text(dayLabel(yesterday)));
      await tester.pumpAndSettle();
      expect(find.text('السابق مخفي'), findsOneWidget);
      final todayLabel = dayLabel(today).replaceFirst('يوم', 'اليوم');
      await tester.tap(find.text(todayLabel));
      await tester.pumpAndSettle();
      await tester.tap(find.text(dayLabel(yesterday)));
      await tester.pumpAndSettle();
      expect(find.text('اليوم ظاهر'), findsNothing);
      await tester.pumpWidget(build(true));
      await tester.pumpAndSettle();
      expect(find.text('السابق مخفي'), findsOneWidget);
      expect(find.text('اليوم ظاهر'), findsOneWidget);
      expect(tester.takeException(), null);
    },
  );
}

