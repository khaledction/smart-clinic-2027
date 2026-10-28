import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import '../../core/database/app_database.dart';

/// V7 — نسخ احتياطي مجدول يومي مع تدوير 7 نسخ
class BackupScheduler {
  BackupScheduler._();
  static final instance = BackupScheduler._();

  Timer? _timer;
  DateTime? _lastRun;
  static String get lastBackupLabel {
    final t = instance._lastRun;
    if (t == null) return 'لم يتم بعد';
    return 'آخر نسخة: ${t.year}-${t.month.toString().padLeft(2,'0')}-${t.day.toString().padLeft(2,'0')} ${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}';
  }

  void start() {
    // أول نسخة بعد 5 دقائق من التشغيل
    Future.delayed(const Duration(minutes: 5), runIfNeeded);
    // ثم كل 24 ساعة
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(hours: 24), (_) => runIfNeeded());
    debugPrint('🔄 BackupScheduler started');
  }

  void stop() => _timer?.cancel();

  Future<void> runIfNeeded() async {
    try {
      final dir = _backupDir();
      if (!dir.existsSync()) dir.createSync(recursive: true);
      // لا تكرر في نفس اليوم
      final today = DateTime.now();
      final todayFile = File(p.join(dir.path, 'backup-${_ymd(today)}.db'));
      if (todayFile.existsSync()) return;
      await runNow();
    } catch (e) {
      debugPrint('BackupScheduler error: $e');
    }
  }

  Future<String> runNow() async {
    final dir = _backupDir();
    if (!dir.existsSync()) await dir.create(recursive: true);
    final path = p.join(dir.path, 'backup-${_ymd(DateTime.now())}.db');
    await AppDatabase.instance.backupTo(path);
    _lastRun = DateTime.now();
    await _rotate(dir);
    debugPrint('✅ Backup saved: $path');
    return path;
  }

  Directory _backupDir() {
    final dbPath = AppDatabase.instance.filePath ?? AppDatabase.resolveDbPath();
    final root = p.dirname(dbPath); // D:\myclinic أو C:\myclinic
    return Directory(p.join(root, 'backups'));
  }

  String _ymd(DateTime d) => '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';

  Future<void> _rotate(Directory dir) async {
    final files = dir.listSync().whereType<File>().where((f) => f.path.contains('backup-')).toList()
      ..sort((a,b) => b.statSync().modified.compareTo(a.statSync().modified));
    if (files.length <= 7) return;
    for (final f in files.skip(7)) {
      try { await f.delete(); debugPrint('🗑️ Deleted old backup: ${f.path}'); } catch (_) {}
    }
  }
}

