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
      await db.insert('patients', {'id': 1, 'full_name': 'Ø§Ø®ØªØ¨Ø§Ø±'});
      await db.insert('visits', {
        'id': 1,
        'patient_id': 1,
        'visit_date': '2026-09-20',
        'visit_type': 'procedure',
        'visit_category': 'session',
        'notes': 'Ù†Øµ Ù‚Ø¯ÙŠÙ…',
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
      expect(prior.notes, 'Ù†Øµ Ù‚Ø¯ÙŠÙ…');
      for (final name in [
        'Ø¬Ù„Ø³Ø© Ø³Ø­Ø¨ ÙÙ‚Ø±Ø§Øª',
        'Ø¬Ù„Ø³Ø© EMS',
        'Ø£Ø®Ø±Ù‰: Ø¬Ù„Ø³Ø© Ù…Ø®ØµØµØ©',
        // Ù‚ÙŠÙ…Ø© Ù‚Ø¯ÙŠÙ…Ø© Ù…Ø­ÙÙˆØ¸Ø© ÙÙŠ Ù‚ÙˆØ§Ø¹Ø¯ Ø³Ø§Ø¨Ù‚Ø© â€” ÙŠØ¬Ø¨ Ø£Ù† ØªØ¸Ù„ Ù…Ù‚Ø±ÙˆØ¡Ø©.
        'Ø¬Ù„Ø³Ø© ÙƒÙ‡Ø±ÙˆÙ…ØºÙ†Ø§Ø·ÙŠØ³ÙŠØ©',
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
        expect(read.copyWith(notes: 'ØªØ¹Ø¯ÙŠÙ„').sessionName, name);
        expect(read.copyWith(visitType: 'new').toMap()['session_name'], null);
      }
      expect(await db.getVersion(), 8);
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
      final oldMonth = 'Ø´Ù‡Ø± ${old.year}/12';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DayGroups<DateTime>(
                items: [now, old],
                dateOf: (d) => d,
                groupBuilder: (rows) =>
                    Text(rows.first == now ? 'Ø³Ø¬Ù„ Ø§Ù„ÙŠÙˆÙ…' : 'Ø³Ø¬Ù„ Ù‚Ø¯ÙŠÙ…'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ø³Ø¬Ù„ Ø§Ù„ÙŠÙˆÙ…'), findsOneWidget);
      expect(find.text('Ø³Ø¬Ù„ Ù‚Ø¯ÙŠÙ…'), findsNothing);
      await tester.tap(find.textContaining(oldMonth));
      await tester.pumpAndSettle();
      expect(find.text('Ø³Ø¬Ù„ Ù‚Ø¯ÙŠÙ…'), findsNothing);
      await tester.tap(find.text('ÙŠÙˆÙ… ${old.year}/12/05'));
      await tester.pumpAndSettle();
      expect(find.text('Ø³Ø¬Ù„ Ù‚Ø¯ÙŠÙ…'), findsOneWidget);
      await tester.tap(find.textContaining(oldMonth));
      await tester.pumpAndSettle();
      expect(find.text('Ø³Ø¬Ù„ Ù‚Ø¯ÙŠÙ…'), findsNothing);
      await tester.tap(find.textContaining(oldMonth));
      await tester.pumpAndSettle();
      expect(find.text('Ø³Ø¬Ù„ Ù‚Ø¯ÙŠÙ…'), findsOneWidget);
      await tester.tap(find.textContaining(oldMonth));
      await tester.pumpAndSettle();
      final nowMonth =
          'Ø´Ù‡Ø± ${now.year}/${now.month.toString().padLeft(2, '0')}';
      await tester.tap(find.textContaining(nowMonth));
      await tester.pumpAndSettle();
      expect(find.text('Ø³Ø¬Ù„ Ø§Ù„ÙŠÙˆÙ…'), findsNothing);
      expect(find.text('Ø³Ø¬Ù„ Ù‚Ø¯ÙŠÙ…'), findsNothing);
      expect(tester.takeException(), null);
      await tester.pumpWidget(const SizedBox());
    },
  );
}


