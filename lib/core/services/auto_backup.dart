import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../data/repositories/app_prefs_repository.dart';
import '../database/app_database.dart';
import 'app_folders.dart';

class AutoBackupResult {
  const AutoBackupResult({
    required this.path,
    this.secondCopy,
    this.secondError,
  });
  final String path;
  final String? secondCopy;
  final String? secondError;
}

/// نسخ احتياطي تلقائي يومي:
/// • نسخة واحدة يومياً عند أول تشغيل (ويُفحص كل ساعة إن بقي البرنامج مفتوحاً).
/// • يُحتفظ بآخر 30 نسخة يومية + نسخة لكل شهر لآخر 12 شهراً.
/// • نسخة إضافية اختيارية في مجلد ثانٍ (فلاشة أو قرص آخر).
class AutoBackup {
  AutoBackup._();

  static const keepDaily = 30;
  static const keepMonthly = 12;
  static const prefix = 'neuro_clinic-';

  /// المجلد الأساسي: D:\myclinic. قابل للاستبدال في الاختبارات.
  static Future<Directory> Function() baseDirectory = AppFolders.root;

  /// إنشاء النسخة — قابل للاستبدال في الاختبارات.
  static Future<void> Function(String target) writeBackup =
      AppDatabase.instance.backupTo;

  static DateTime Function() now = DateTime.now;

  static Timer? _timer;
  static bool _running = false;

  static Future<Directory> folder() async =>
      Directory(p.join((await baseDirectory()).path, 'backups'));

  static String _two(int v) => v.toString().padLeft(2, '0');

  static String dailyName(DateTime d) =>
      '$prefix${d.year}-${_two(d.month)}-${_two(d.day)}.db';

  static String monthlyName(DateTime d) =>
      '$prefix${d.year}-${_two(d.month)}.db';

  /// يبدأ الفحص الدوري (من main فقط، لا في الاختبارات).
  static void start({Duration firstDelay = const Duration(seconds: 15)}) {
    _timer?.cancel();
    Timer(firstDelay, () => runIfDue());
    _timer = Timer.periodic(const Duration(hours: 1), (_) => runIfDue());
  }

  static void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// ينشئ نسخة اليوم إن لم تكن موجودة (أو دائماً عند [force]).
  static Future<AutoBackupResult?> runIfDue({bool force = false}) async {
    if (_running) return null;
    _running = true;
    try {
      final repo = AppPrefsRepository();
      final prefs = await repo.load();
      if (!prefs.autoBackup && !force) return null;
      final today = now();
      final dir = await folder();
      final daily = Directory(p.join(dir.path, 'daily'));
      final monthly = Directory(p.join(dir.path, 'monthly'));
      await daily.create(recursive: true);
      await monthly.create(recursive: true);

      final file = File(p.join(daily.path, dailyName(today)));
      if (!force && await file.exists()) return null;

      // VACUUM INTO لا يكتب فوق ملف موجود ← ملف مؤقت ثم استبدال.
      final tmp = File('${file.path}.tmp');
      if (await tmp.exists()) await tmp.delete();
      await writeBackup(tmp.path);
      if (await file.exists()) await file.delete();
      await tmp.rename(file.path);

      final month = File(p.join(monthly.path, monthlyName(today)));
      if (!await month.exists()) await file.copy(month.path);

      await _prune(daily, keepDaily);
      await _prune(monthly, keepMonthly);

      String? second;
      String? secondError;
      final dir2 = prefs.backupDir2.trim();
      if (dir2.isNotEmpty) {
        try {
          final target = Directory(dir2);
          if (!await target.exists()) {
            throw const FileSystemException('المجلد الثاني غير متاح');
          }
          second = p.join(target.path, dailyName(today));
          await file.copy(second);
          await _prune(target, keepDaily);
        } catch (e) {
          second = null;
          secondError = 'تعذّر النسخ إلى المجلد الثاني: $dir2';
        }
      }

      await repo.update(
        (x) => x.copyWith(lastAutoBackup: today, lastAutoBackupPath: file.path),
      );
      return AutoBackupResult(
        path: file.path,
        secondCopy: second,
        secondError: secondError,
      );
    } finally {
      _running = false;
    }
  }

  /// يحذف الأقدم ويُبقي أحدث [keep] نسخة (الأسماء مرتّبة بالتاريخ).
  static Future<void> _prune(Directory dir, int keep) async {
    final files =
        (await dir.list().toList()).whereType<File>().where((f) {
            final n = p.basename(f.path);
            return n.startsWith(prefix) && n.endsWith('.db');
          }).toList()
          ..sort((a, b) => p.basename(b.path).compareTo(p.basename(a.path)));
    for (final f in files.skip(keep)) {
      try {
        await f.delete();
      } catch (_) {}
    }
  }
}
