import 'package:sqflite/sqflite.dart';

import 'workflow_schema.dart';

/// ============================================================================
///  مخطط قاعدة البيانات — عيادة أعصاب
/// ----------------------------------------------------------------------------
///  كل الجداول عادية (علائقية) ويمكن فتح الملف بأي أداة SQLite مثل DB Browser.
///  لإضافة حقل جديد في نسخة قادمة: ارفع [kSchemaVersion] وأضف تعليمات
///  ALTER TABLE داخل [migrate].
/// ============================================================================

const int kSchemaVersion = 8;

const String kDbFileName = 'neuro_clinic.db';

/// كل تعليمات إنشاء الجداول والفهارس لنسخة جديدة كلياً.
const List<String> kCreateStatements = [
  // ---------------------------------------------------------------- المستخدمون
  '''
  CREATE TABLE users (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    username      TEXT    NOT NULL UNIQUE,
    password_hash TEXT    NOT NULL,
    full_name     TEXT    NOT NULL,
    role          TEXT    NOT NULL CHECK(role IN ('doctor','reception','admin')),
    is_active     INTEGER NOT NULL DEFAULT 1,
    created_at    TEXT
  )
  ''',

  // ------------------------------------------------------- إعدادات العيادة
  '''
  CREATE TABLE clinic_settings (
    id              INTEGER PRIMARY KEY CHECK(id = 1),
    clinic_name     TEXT,
    doctor_name     TEXT,
    specialty       TEXT,
    phone           TEXT,
    address         TEXT,
    default_fee     REAL    NOT NULL DEFAULT 0,
    visit_duration  INTEGER NOT NULL DEFAULT 20,
    footer_note     TEXT
  )
  ''',

  // -------------------------------------------------------------------- المرضى
  '''
  CREATE TABLE patients (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    file_no         TEXT    UNIQUE,
    full_name       TEXT    NOT NULL,
    national_id     TEXT,
    gender          TEXT    CHECK(gender IN ('m','f')),
    birth_date      TEXT,
    age_years       INTEGER CHECK(age_years IS NULL OR age_years BETWEEN 0 AND 130),
    age_recorded_on TEXT,
    phone           TEXT,
    phone_alt       TEXT,
    address         TEXT,
    referral_source TEXT,
    blood_type      TEXT,
    allergies       TEXT,
    notes           TEXT,
    is_active       INTEGER NOT NULL DEFAULT 1,
    created_at      TEXT,
    updated_at      TEXT
  )
  ''',
  'CREATE INDEX idx_patients_name  ON patients(full_name)',
  'CREATE INDEX idx_patients_phone ON patients(phone)',
  'CREATE INDEX idx_patients_file  ON patients(file_no)',

  // ------------------------------------------------------- التاريخ المرضي العام
  '''
  CREATE TABLE medical_history (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    patient_id  INTEGER NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
    condition   TEXT    NOT NULL,
    since_year  INTEGER,
    notes       TEXT
  )
  ''',
  'CREATE INDEX idx_history_patient ON medical_history(patient_id)',

  // ----------------------------------------------------- الأدوية المزمنة
  '''
  CREATE TABLE medications (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    patient_id  INTEGER NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
    drug        TEXT    NOT NULL,
    dose        TEXT,
    frequency   TEXT,
    route       TEXT,
    indication  TEXT,
    started_on  TEXT,
    stopped_on  TEXT,
    is_active   INTEGER NOT NULL DEFAULT 1
  )
  ''',
  'CREATE INDEX idx_meds_patient ON medications(patient_id)',

  // ------------------------------------------------------------------- الزيارات
  '''
  CREATE TABLE visits (
    id                INTEGER PRIMARY KEY AUTOINCREMENT,
    patient_id        INTEGER NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
    visit_date        TEXT    NOT NULL,
    patient_age_years INTEGER,
    patient_age_recorded_on TEXT,
    session_name TEXT,
    visit_category TEXT CHECK(visit_category IS NULL OR visit_category IN ('first','session')),
    visit_type        TEXT    NOT NULL DEFAULT 'new'
                              CHECK(visit_type IN ('new','followup','emergency','procedure')),
    chief_complaint   TEXT,
    onset_duration    TEXT,
    diagnosis         TEXT,
    icd10             TEXT,
    plan              TEXT,
    followup_in_days  INTEGER,
    notes             TEXT,
    created_at        TEXT
  )
  ''',
  'CREATE INDEX idx_visits_patient ON visits(patient_id, visit_date DESC)',
  'CREATE INDEX idx_visits_date    ON visits(visit_date)',

  // ------------------------------------------------------------ الفحص العصبي
  '''
  CREATE TABLE neuro_exam (
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    visit_id       INTEGER NOT NULL UNIQUE REFERENCES visits(id) ON DELETE CASCADE,
    gcs            INTEGER,
    consciousness  TEXT,
    orientation    TEXT,
    speech         TEXT,
    cranial_nerves TEXT,
    motor_power    TEXT,
    tone           TEXT,
    reflexes       TEXT,
    sensation      TEXT,
    coordination   TEXT,
    gait           TEXT,
    meningeal      TEXT,
    findings       TEXT
  )
  ''',

  // -------------------------------------------------- المقاييس العصبية المعيارية
  '''
  CREATE TABLE neuro_scales (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    visit_id    INTEGER NOT NULL REFERENCES visits(id) ON DELETE CASCADE,
    scale       TEXT    NOT NULL,
    score       REAL    NOT NULL,
    max_score   REAL,
    notes       TEXT,
    recorded_at TEXT
  )
  ''',
  'CREATE INDEX idx_scales_visit ON neuro_scales(visit_id)',

  // ------------------------------------------------ الاستقصاءات والفحوص المساندة
  '''
  CREATE TABLE investigations (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    patient_id      INTEGER NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
    visit_id        INTEGER REFERENCES visits(id) ON DELETE SET NULL,
    kind            TEXT    NOT NULL,
    body_site       TEXT,
    performed_on    TEXT,
    report          TEXT,
    attachment_path TEXT,
    created_at      TEXT
  )
  ''',
  'CREATE INDEX idx_invest_patient ON investigations(patient_id)',

  // --------------------------------------------------------------- الوصفات
  '''
  CREATE TABLE prescriptions (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    visit_id      INTEGER NOT NULL REFERENCES visits(id) ON DELETE CASCADE,
    drug          TEXT    NOT NULL,
    dose          TEXT,
    frequency     TEXT,
    duration_days INTEGER,
    notes         TEXT
  )
  ''',
  'CREATE INDEX idx_presc_visit ON prescriptions(visit_id)',

  // --------------------------------------------------------------- المواعيد
  '''
  CREATE TABLE appointments (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    patient_id    INTEGER NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
    start_at      TEXT    NOT NULL,
    duration_min  INTEGER NOT NULL DEFAULT 20,
    status        TEXT    NOT NULL DEFAULT 'scheduled'
                          CHECK(status IN ('scheduled','arrived','done','cancelled','no_show')),
    reason        TEXT,
    created_at    TEXT
  )
  ''',
  'CREATE INDEX idx_appt_start   ON appointments(start_at)',
  'CREATE INDEX idx_appt_patient ON appointments(patient_id)',

  // ----------------------------------------------------------------- المالية
  '''
  CREATE TABLE payments (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    patient_id INTEGER NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
    visit_id   INTEGER REFERENCES visits(id) ON DELETE SET NULL,
    amount     REAL    NOT NULL,
    method     TEXT    NOT NULL DEFAULT 'cash'
                       CHECK(method IN ('cash','card','insurance','transfer')),
    paid_at    TEXT,
    note       TEXT,
    auto_generated INTEGER NOT NULL DEFAULT 0,
    invoice_no TEXT
  )
  ''',
  'CREATE INDEX idx_pay_patient ON payments(patient_id)',
  'CREATE INDEX idx_pay_date    ON payments(paid_at)',

  // --------------------------------------------------- سجل التدقيق (الأمان)
  '''
  CREATE TABLE audit_log (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id    INTEGER REFERENCES users(id) ON DELETE SET NULL,
    action     TEXT    NOT NULL,
    entity     TEXT,
    entity_id  INTEGER,
    detail     TEXT,
    at         TEXT
  )
  ''',
  'CREATE INDEX idx_audit_at ON audit_log(at)',
];

/// يُستدعى عند فتح قاعدة بيانات جديدة.
Future<void> createSchema(Database db) async {
  final batch = db.batch();
  for (final statement in kCreateStatements) {
    batch.execute(statement);
  }
  await batch.commit(noResult: true);
  await ensureWorkflowSchema(db);
  await ensureAppointmentKinds(db);
}

/// ============================================================================
///  الترقية من نسخة مخطط إلى أخرى — عدّل هنا عند تغيير الجداول.
///  مثال جاهز للتعليق عليه عند الحاجة:
///
///    if (from < 2) {
///      await db.execute('ALTER TABLE patients ADD COLUMN email TEXT');
///    }
/// ============================================================================
/// Check the actual schema as well as user_version. Existing values must never
/// be overwritten when a database already contains an additive column.
Future<void> _addColumnIfMissing(
  Database db,
  String table,
  String column,
  String declaration,
) async {
  // Identifiers/declarations come only from constants below, not user input.
  final columns = await db.rawQuery('PRAGMA table_info("$table")');
  if (columns.isEmpty) {
    throw StateError('Required database table is missing: $table');
  }
  if (columns.any(
    (row) => (row['name'] as String).toLowerCase() == column.toLowerCase(),
  )) {
    return;
  }
  await db.execute('ALTER TABLE "$table" ADD COLUMN "$column" $declaration');
}

Future<void> migrate(Database db, int from, int to) async {
  if (from < 5 && to >= 5) await ensureWorkflowSchema(db);
  if (from < 6 && to >= 6) await ensureWorkflowSchema(db);
  if (from < 2 && to >= 2) {
    await _addColumnIfMissing(
      db,
      'patients',
      'age_years',
      'INTEGER CHECK(age_years IS NULL OR age_years BETWEEN 0 AND 130)',
    );
    await _addColumnIfMissing(db, 'patients', 'age_recorded_on', 'TEXT');
    await _addColumnIfMissing(db, 'visits', 'patient_age_years', 'INTEGER');
    await _addColumnIfMissing(db, 'visits', 'patient_age_recorded_on', 'TEXT');
  }
  if (from < 3 && to >= 3) {
    await _addColumnIfMissing(
      db,
      'visits',
      'visit_category',
      "TEXT CHECK(visit_category IS NULL OR visit_category IN ('first','session'))",
    );
  }
  if (from < 4 && to >= 4) {
    await _addColumnIfMissing(db, 'visits', 'session_name', 'TEXT');
  }
  if (from < 7 && to >= 7) {
    // يعتمد على جداول الجلسات، لذا نضمن وجودها أولاً (إعادة الدخول آمنة).
    await ensureWorkflowSchema(db);
    await ensureAppointmentKinds(db);
  }
  if (from < 8 && to >= 8) {
    await _addColumnIfMissing(db, 'payments', 'auto_generated', 'INTEGER NOT NULL DEFAULT 0');
    await _addColumnIfMissing(db, 'payments', 'invoice_no', 'TEXT');
    await _addColumnIfMissing(db, 'appointments', 'reminder_sent', 'INTEGER NOT NULL DEFAULT 0');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS reminder_dismissed (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        appointment_id INTEGER NOT NULL UNIQUE,
        dismissed_at TEXT NOT NULL
      )
    ''');
  }
}

/// يفعّل قيود المفاتيح الأجنبية (SQLite يعطّلها افتراضياً).
Future<void> enableForeignKeys(Database db) async {
  await db.execute('PRAGMA foreign_keys = ON');
}


