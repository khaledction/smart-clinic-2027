import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:neuro_clinic/core/database/schema.dart';
import 'package:neuro_clinic/data/models/visit.dart';
import 'package:neuro_clinic/core/widgets/day_groups.dart';

import 'fixtures/schema_v3.dart' as old;

void main() {
  test('Schema 3 to 4 preserves unnamed old sessions; all session names round-trip', () async {
    sqfliteFfiInit();
    final dir = await Directory.systemTemp.createTemp('clinic-session-');
    Database? db;
    try {
      final path = '${dir.path}/test.db';
      db = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 3,
          onCreate: (db, _) => old.createSchema(db),
        ),
      );
      await db.insert('patients', {'id': 1, 'full_name': 'اختبار'});
      await db.insert('visits', {
        'id': 1,
        'patient_id': 1,
        'visit_date': '2026-09-20',
        'visit_type': 'procedure',
        'visit_category': 'session',
        'notes': 'نص قديم',
      });
      await db.close();
      db = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: kSchemaVersion,
          onUpgrade: migrate,
        ),
      );
      final prior = Visit.fromMap((await db.query('visits')).single);
      expect(prior.sessionName, null);
      expect(prior.notes, 'نص قديم');
      for (final name in [
        'جلسة سحب فقرات',
        'جلسة EMS',
        'أخرى: جلسة مخصصة',
        // قيمة قديمة محفوظة في قواعد سابقة — يجب أن تظل مقروءة.
        'جلسة كهرومغناطيسية',
      ]) {
        final v = Visit(
          patientId: 1,
          visitDate: DateTime.now(),
          visitType: 'session',
          sessionName: name,
        );
        final id = await db.insert('visits', v.toMap()..remove('created_at'));
        final read = Visit.fromMap(
          (await db.query('visits', where: 'id = ?', whereArgs: [id])).single,
        );
        expect(read.sessionName, name);
        expect(read.copyWith(notes: 'تعديل').sessionName, name);
        expect(read.copyWith(visitType: 'new').toMap()['session_name'], null);
      }
      expect(await db.getVersion(), 7);
    } finally {
      await db?.close();
      await dir.delete(recursive: true);
    }
  });
  testWidgets(
    'Months default collapsed; month toggles preserve expanded days, including across years',
    (tester) async {
      final now = DateTime.now();
      final old = DateTime(now.year - 1, 12, 5);
      final oldMonth = 'شهر ${old.year}/12';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DayGroups<DateTime>(
                items: [now, old],
                dateOf: (d) => d,
                groupBuilder: (rows) =>
                    Text(rows.first == now ? 'سجل اليوم' : 'سجل قديم'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('سجل اليوم'), findsOneWidget);
      expect(find.text('سجل قديم'), findsNothing);
      await tester.tap(find.textContaining(oldMonth));
      await tester.pumpAndSettle();
      expect(find.text('سجل قديم'), findsNothing);
      await tester.tap(find.text('يوم ${old.year}/12/05'));
      await tester.pumpAndSettle();
      expect(find.text('سجل قديم'), findsOneWidget);
      await tester.tap(find.textContaining(oldMonth));
      await tester.pumpAndSettle();
      expect(find.text('سجل قديم'), findsNothing);
      await tester.tap(find.textContaining(oldMonth));
      await tester.pumpAndSettle();
      expect(find.text('سجل قديم'), findsOneWidget);
      await tester.tap(find.textContaining(oldMonth));
      await tester.pumpAndSettle();
      final nowMonth =
          'شهر ${now.year}/${now.month.toString().padLeft(2, '0')}';
      await tester.tap(find.textContaining(nowMonth));
      await tester.pumpAndSettle();
      expect(find.text('سجل اليوم'), findsNothing);
      expect(find.text('سجل قديم'), findsNothing);
      expect(tester.takeException(), null);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
