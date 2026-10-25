import 'package:sqflite/sqflite.dart';

/// Additive and re-entrant. Never reclassifies legacy investigations/payments.
Future<void> ensureWorkflowSchema(Database db) async {
  Future<void> column(String table, String name, String definition) async {
    final rows = await db.rawQuery('PRAGMA table_info("$table")');
    if (!rows.any((r) => r['name'] == name)) {
      await db.execute('ALTER TABLE "$table" ADD COLUMN "$name" $definition');
    }
  }

  await column(
    'patients',
    'weight_kg',
    'REAL CHECK(weight_kg IS NULL OR (weight_kg > 0 AND weight_kg <= 700))',
  );
  await column('patients', 'weight_recorded_on', 'TEXT');
  await column('visits', 'patient_weight_kg', 'REAL');
  await column('visits', 'completed_at', 'TEXT');
  await db.execute(
    '''CREATE TABLE IF NOT EXISTS treatment_services (
    id INTEGER PRIMARY KEY, name TEXT NOT NULL UNIQUE, price REAL NOT NULL DEFAULT 0 CHECK(price >= 0), active INTEGER NOT NULL DEFAULT 1)''',
  );
  for (final name in ['جلسة سحب فقرات', 'جلسة EMS']) {
    await db.rawInsert(
      'INSERT OR IGNORE INTO treatment_services(name) VALUES (?)',
      [name],
    );
  }
  await db.execute(
    '''CREATE TABLE IF NOT EXISTS treatment_orders (
    id INTEGER PRIMARY KEY, patient_id INTEGER NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
    source_visit_id INTEGER NOT NULL REFERENCES visits(id) ON DELETE RESTRICT,
    service_id INTEGER REFERENCES treatment_services(id), service_name TEXT NOT NULL,
    indication TEXT, planned_count INTEGER NOT NULL CHECK(planned_count BETWEEN 1 AND 100), created_at TEXT NOT NULL)''',
  );
  await db.execute('''CREATE TABLE IF NOT EXISTS treatment_sessions (
    id INTEGER PRIMARY KEY, order_id INTEGER NOT NULL REFERENCES treatment_orders(id) ON DELETE CASCADE,
    sequence_no INTEGER NOT NULL, scheduled_on TEXT, performed_on TEXT,
    status TEXT NOT NULL DEFAULT 'requested' CHECK(status IN ('requested','scheduled','in_progress','completed','cancelled')),
    diagnosis TEXT, result TEXT, notes TEXT, price REAL NOT NULL CHECK(price >= 0), updated_at TEXT,
    UNIQUE(order_id, sequence_no))''');
  await column(
    'payments',
    'session_id',
    'INTEGER REFERENCES treatment_sessions(id) ON DELETE RESTRICT',
  );
  await column('payments', 'category', "TEXT NOT NULL DEFAULT 'legacy'");
  await column('payments', 'service_label', 'TEXT');
  await db.execute(
    'CREATE UNIQUE INDEX IF NOT EXISTS idx_payment_session_once ON payments(session_id) WHERE session_id IS NOT NULL',
  );
  await db.execute(
    "CREATE UNIQUE INDEX IF NOT EXISTS idx_payment_visit_once ON payments(visit_id) WHERE category = 'consultation'",
  );
  await column(
    'investigations',
    'workflow_status',
    "TEXT NOT NULL DEFAULT 'legacy'",
  );
  await column('investigations', 'facility', 'TEXT');
  await db.execute('''CREATE TABLE IF NOT EXISTS investigation_attachments (
    id INTEGER PRIMARY KEY, investigation_id INTEGER NOT NULL REFERENCES investigations(id) ON DELETE CASCADE,
    name TEXT NOT NULL, bytes BLOB NOT NULL)''');
  await db.execute(
    '''CREATE TABLE IF NOT EXISTS referrals (
    id INTEGER PRIMARY KEY, patient_id INTEGER NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
    visit_id INTEGER REFERENCES visits(id) ON DELETE SET NULL,
    category TEXT NOT NULL CHECK(category IN ('consultation','transfer')),
    target_type TEXT NOT NULL, destination TEXT, reason TEXT, created_at TEXT NOT NULL)''',
  );
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_referrals_patient ON referrals(patient_id)',
  );
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_referrals_visit ON referrals(visit_id)',
  );
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_orders_patient ON treatment_orders(patient_id)',
  );
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_orders_visit ON treatment_orders(source_visit_id)',
  );
}

/// V7 — نوع الموعد (معاينة/جلسة) وربطه بالزيارة أو الجلسة عند الإنجاز.
/// حقول إضافية فارغة فقط: المواعيد القديمة تبقى kind = NULL («غير محدد»)
/// ولا يُعاد تصنيف أي سجل قديم.
Future<void> ensureAppointmentKinds(Database db) async {
  Future<void> column(String table, String name, String definition) async {
    final rows = await db.rawQuery('PRAGMA table_info("$table")');
    if (!rows.any((r) => r['name'] == name)) {
      await db.execute('ALTER TABLE "$table" ADD COLUMN "$name" $definition');
    }
  }

  await column(
    'appointments',
    'kind',
    "TEXT CHECK(kind IS NULL OR kind IN ('checkup','session'))",
  );
  await column('appointments', 'session_name', 'TEXT');
  await column(
    'appointments',
    'session_id',
    'INTEGER REFERENCES treatment_sessions(id) ON DELETE SET NULL',
  );
  await column(
    'appointments',
    'visit_id',
    'INTEGER REFERENCES visits(id) ON DELETE SET NULL',
  );
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_appt_session ON appointments(session_id)',
  );
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_appt_visit ON appointments(visit_id)',
  );
}
