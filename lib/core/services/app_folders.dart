import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// مجلد البرنامج الظاهر للمستخدم: D:\myclinic — وإن لم يوجد القرص D
/// فـ C:\myclinic بنفس التسمية (يُنشأ تلقائياً عند التنصيب وعند كل تشغيل).
/// النسخ الاحتياطية بداخله:
///   backups\daily و backups\monthly  ← التلقائية
///   backups\manual                    ← اليدوية
/// ويبقى ممكناً النسخ إلى مسار آخر (فلاشة أو قرص خارجي).
class AppFolders {
  AppFolders._();

  static const windowsRoot = r'D:\myclinic';
  static const windowsRootC = r'C:\myclinic';

  /// بديل عند غياب القرص D. قابل للاستبدال في الاختبارات.
  static Future<Directory> Function() fallback = getApplicationSupportDirectory;

  /// لتحديد المجلد في الاختبارات.
  static String? overrideRoot;

  static Future<Directory> root() async {
    final forced = overrideRoot;
    if (forced != null) return Directory(forced);
    if (Platform.isWindows) {
      final candidates = [
        if (Directory(r'D:\').existsSync()) windowsRoot,
        windowsRootC,
      ];
      for (final path in candidates) {
        final d = Directory(path);
        try {
          d.createSync(recursive: true);
          return d;
        } catch (_) {
          // لا صلاحية كتابة ← المرشح التالي.
        }
      }
    }
    return Directory(p.join((await fallback()).path, 'myclinic'));
  }

  static Future<Directory> backups() async {
    final d = Directory(p.join((await root()).path, 'backups'));
    d.createSync(recursive: true);
    return d;
  }

  /// مجلد النسخ اليدوية: `root/backups/manual`
  static Future<Directory> manualBackups() async {
    final d = Directory(p.join((await backups()).path, 'manual'));
    d.createSync(recursive: true);
    return d;
  }

  /// يُستدعى عند تشغيل البرنامج لإنشاء المجلدات إن لم تكن موجودة.
  static Future<void> ensure() async {
    try {
      await manualBackups();
    } catch (_) {}
  }
}
