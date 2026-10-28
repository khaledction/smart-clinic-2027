import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'schema.dart';
import 'seed.dart';

/// ============================================================================
///  إدارة الاتصال بقاعدة البيانات
/// ----------------------------------------------------------------------------
///  • على سطح المكتب (Windows / Linux / macOS) لا تعمل حزمة sqflite مباشرة،
///    لذلك نستخدم [sqfliteFfiInit] ونمرّر [databaseFactoryFfi].
///  • ملف قاعدة البيانات يُحفظ في D:\myclinic\database.db،
///    وإن لم يوجد القرص D في C:\myclinic\database.db —
///    وعلى أجهزة التاب (Android/iOS) يُحفظ داخل مجلد التطبيق الآمن Documents.
/// ============================================================================
class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  Database? _db;
  String? _path;

  /// Test-only in-memory connection.
  void useTestDatabase(Database db) {
    _db = db;
  }

  /// مسار ملف قاعدة البيانات الحالي (مفيد لعرضه في شاشة الإعدادات).
  String? get filePath => _path;

  Future<Database> get database async => _db ??= await _open();

  /// يهيّئ sqflite ليعمل على أجهزة سطح المكتب.
  /// يجب استدعاؤها مرة واحدة قبل أي استخدام، من داخل main().
  static void initForDesktop() {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }

  /// مسار قاعدة البيانات: `D:\myclinic\database.db`،
  /// أو `C:\myclinic\database.db` إن لم يوجد القرص D.
  static String resolveDbPath() {
    if (Platform.isWindows) {
      final root =
          Directory(r'D:\').existsSync() ? r'D:\myclinic' : r'C:\myclinic';
      return p.join(root, 'database.db');
    }
    return 'database.db';
  }

  Future<Database> _open() async {
    if (Platform.isAndroid || Platform.isIOS) {
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory(p.join(docs.path, 'myclinic'));
      if (!dir.existsSync()) await dir.create(recursive: true);
      _path = p.join(dir.path, 'database.db');
    } else {
      _path = resolveDbPath();
      await File(_path!).parent.create(recursive: true);
    }
    await backupBeforeUpgrade(_path!);

    final db = await databaseFactory.openDatabase(
      _path!,
      options: OpenDatabaseOptions(
        version: kSchemaVersion,
        onCreate: (db, version) async {
          await createSchema(db);
          await seedInitialData(db);
        },
        onUpgrade: (db, from, to) => migrate(db, from, to),
        onConfigure: (db) => enableForeignKeys(db),
        // تفعيل WAL وضبط مهلة الانتظار والأداء للعمل بسلاسة على الشبكة المحلية والحواسيب المتعددة
        onOpen: (db) async {
          await db.execute('PRAGMA journal_mode = WAL');
          await db.execute('PRAGMA busy_timeout = 5000');
          await db.execute('PRAGMA synchronous = NORMAL');
        },
      ),
    );

    debugPrint('📂 قاعدة البيانات: $_path');
    return db;
  }

  /// قبل ترقية مخطط قاعدة بيانات قائمة يحفظ نسخة كاملة بجانبها:
  /// database.db.before-v7-<الوقت>. لا يلمس قاعدة جديدة أو محدّثة.
  /// يعيد مسار النسخة أو null إن لم تلزم.
  static Future<String?> backupBeforeUpgrade(String path) async {
    if (!await File(path).exists()) return null;
    Database? probe;
    try {
      probe = await databaseFactory.openDatabase(
        path,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      final version = await probe.getVersion();
      if (version <= 0 || version >= kSchemaVersion) return null;
      final target =
          '$path.before-v$kSchemaVersion-${DateTime.now().millisecondsSinceEpoch}';
      // VACUUM INTO يشمل ما في ملف WAL أيضاً.
      await probe.execute('VACUUM INTO ?', [target]);
      debugPrint('🛟 نسخة قبل الترقية: $target');
      return target;
    } finally {
      await probe?.close();
    }
  }

  /// يغلق الاتصال (قبل إغلاق التطبيق أو قبل استرجاع نسخة احتياطية).
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  /// ==========================================================================
  ///  نسخ احتياطي / استرجاع
  /// ==========================================================================

  /// ينشئ نسخة احتياطية باستخدام أمر SQLite الآمن (backup API عبر VACUUM INTO).
  /// [targetPath] هو المسار الكامل للملف الجديد.
  Future<void> backupTo(String targetPath) async {
    final db = await database;
    // VACUUM INTO ينتج نسخة متسقة ومضغوطة من قاعدة البيانات.
    await db.execute("VACUUM INTO ?", [targetPath]);
  }

  /// يسترجع نسخة احتياطية: يستبدل قاعدة البيانات الحالية بالملف المختار.
  Future<void> restoreFrom(String sourcePath) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw Exception('ملف النسخة الاحتياطية غير موجود');
    }
    final current = await database;
    final target = File(_path!);
    if (p.equals(p.absolute(sourcePath), p.absolute(target.path))) {
      throw ArgumentError('اختر نسخة أخرى غير قاعدة البيانات الحالية');
    }
    // Validate a staged copy before touching the active database.
    final staged = File('${target.path}.restore');
    await source.copy(staged.path);
    Database? candidate;
    try {
      candidate = await databaseFactory.openDatabase(
        staged.path,
        options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
      );
      final check = await candidate.rawQuery('PRAGMA integrity_check');
      final version = await candidate.getVersion();
      // نسخ V6 مقبولة وتُرقّى تلقائياً عند الفتح (حقول إضافية فقط).
      if (check.first.values.first != 'ok' ||
          version < 6 ||
          version > kSchemaVersion) {
        throw StateError('النسخة تالفة أو إصدارها غير متوافق');
      }
      for (final table in [
        'patients',
        'users',
        'clinic_settings',
        'visits',
        'neuro_exam',
        'neuro_scales',
        'prescriptions',
        'medications',
        'medical_history',
        'investigations',
        'payments',
        'appointments',
        'audit_log',
        'treatment_services',
        'treatment_orders',
        'treatment_sessions',
        'investigation_attachments',
        'referrals',
      ]) {
        await candidate.rawQuery('SELECT * FROM $table LIMIT 0');
      }
    } finally {
      await candidate?.close();
    }
    final rollback =
        '${target.path}.before-restore-${DateTime.now().millisecondsSinceEpoch}';
    await current.execute('VACUUM INTO ?', [rollback]);
    await close();
    try {
      for (final suffix in ['-wal', '-shm']) {
        final side = File('${target.path}$suffix');
        if (await side.exists()) await side.delete();
      }
      await staged.copy(target.path);
      await database;
    } catch (_) {
      await close();
      await File(rollback).copy(target.path);
      await database;
      rethrow;
    } finally {
      if (await staged.exists()) await staged.delete();
    }
  }
}

