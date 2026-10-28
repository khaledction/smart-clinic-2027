import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:neuro_clinic/core/database/schema.dart';

import 'fixtures/schema_v3.dart' as old;

void main() {
  test('Upgrade accepts existing session_name and preserves clinical and login data', () async {
    sqfliteFfiInit();
    final dir = await Directory.systemTemp.createTemp('migration-reentry-');
    Database? db;
    try {
      final path = '${dir.path}/clinic.db';
      db = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 3,
          onCreate: (db, _) => old.createSchema(db),
          onConfigure: enableForeignKeys,
        ),
      );
      await db.execute('ALTER TABLE visits ADD COLUMN session_name TEXT');
      await db.insert('users', {
        'username': 'doctor-test',
        'password_hash': 'unchanged-hash-test',
        'full_name': 'Ø§Ø®ØªØ¨Ø§Ø±',
        'role': 'doctor',
      });
      await db.insert('patients', {
        'id': 1,
        'full_name': 'Ø§Ø®ØªØ¨Ø§Ø±',
        'age_years': 42,
      });
      await db.insert('visits', {
        'id': 1,
        'patient_id': 1,
        'visit_date': '2026-09-21',
        'visit_type': 'procedure',
        'visit_category': 'session',
        'session_name': 'Ø¬Ù„Ø³Ø© Ø³Ø­Ø¨ ÙÙ‚Ø±Ø§Øª',
        'notes': 'ÙŠØ¬Ø¨ Ø§Ù„Ø­ÙØ§Ø¸ Ø¹Ù„Ù‰ Ø§Ù„Ù†Øµ',
      });
      await db.insert('payments', {
        'patient_id': 1,
        'visit_id': 1,
        'amount': 12345,
      });
      final patientsBefore = await db.query('patients');
      final visitsBefore = await db.query('visits');
      final paymentsBefore = await db.query('payments');
      final usersBefore = await db.query('users');
      await db.close();
      db = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: kSchemaVersion,
          onUpgrade: migrate,
          onConfigure: enableForeignKeys,
        ),
      );
      expect(await db.getVersion(), 8);
      expect(
        await db.query('patients', columns: patientsBefore.first.keys.toList()),
        patientsBefore,
      );
      expect(
        await db.query('visits', columns: visitsBefore.first.keys.toList()),
        visitsBefore,
      );
      expect(
        await db.query('payments', columns: paymentsBefore.first.keys.toList()),
        paymentsBefore,
      );
      expect(await db.query('users'), usersBefore);
      // Re-enter all additive migrations, simulating stale version metadata.
      await migrate(db, 1, 4);
      await migrate(db, 1, 4);
      expect(
        await db.query('visits', columns: visitsBefore.first.keys.toList()),
        visitsBefore,
      );
      expect(
        await db.query('patients', columns: patientsBefore.first.keys.toList()),
        patientsBefore,
      );
      expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
      expect(
        (await db.rawQuery('PRAGMA integrity_check')).single.values.single,
        'ok',
      );
    } finally {
      await db?.close();
      await dir.delete(recursive: true);
    }
  });
}


