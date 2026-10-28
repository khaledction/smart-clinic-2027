import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// تفضيلات هذا الجهاز: بيانات «نسيت كلمة المرور» (بريد اختياري + واتساب)
/// وإعدادات النسخ التلقائي.
/// تُحفظ ملف JSON بجانب قاعدة البيانات (بدون أي تغيير في جداول القاعدة).
class AppPrefs {
  const AppPrefs({
    this.recoveryEmail = '',
    this.recoveryWhatsapp = '',
    this.recoveryPinHash = '',
    this.lanMode = 'standalone',
    this.lanHostAddress = '',
    this.platformUrl = '',
    this.platformApiKey = '',
    this.platformSyncEnabled = false,
    this.autoBackup = true,
    this.backupDir2 = '',
    this.lastAutoBackup,
    this.lastAutoBackupPath = '',
  });

  /// البريد الذي يصله رمز الاستعادة.
  final String recoveryEmail;

  /// رقم واتساب (دولي) الذي يُرسل إليه رمز الاستعادة.
  final String recoveryWhatsapp;

  /// تجزئة BCrypt لرمز PIN الأمان الرئيسي للعيادة.
  final String recoveryPinHash;

  /// نمط الشبكة المحلية: standalone (مستقل) | host (رئيسي) | client (فرعي)
  final String lanMode;

  /// عنوان IP للجهاز الرئيسي في الشبكة المحلية
  final String lanHostAddress;

  /// رابط المنصة السحابية
  final String platformUrl;

  /// مفتاح الربط مع المنصة
  final String platformApiKey;

  /// تفعيل المزامنة السحابية
  final bool platformSyncEnabled;

  final bool autoBackup;
  final String backupDir2;
  final DateTime? lastAutoBackup;
  final String lastAutoBackupPath;

  /// البريد اختياري: إن ضُبط يُفتح برنامج البريد برسالة فيها الرمز.
  bool get canEmail => recoveryEmail.trim().contains('@');

  bool get canWhatsapp =>
      recoveryWhatsapp.replaceAll(RegExp(r'\D'), '').length >= 8;

  bool get hasRecoveryPin => recoveryPinHash.trim().isNotEmpty;

  factory AppPrefs.fromJson(Map<String, Object?> m) => AppPrefs(
    recoveryEmail: (m['recoveryEmail'] as String?) ?? '',
    recoveryWhatsapp: (m['recoveryWhatsapp'] as String?) ?? '',
    recoveryPinHash: (m['recoveryPinHash'] as String?) ?? '',
    lanMode: (m['lanMode'] as String?) ?? 'standalone',
    lanHostAddress: (m['lanHostAddress'] as String?) ?? '',
    platformUrl: (m['platformUrl'] as String?) ?? '',
    platformApiKey: (m['platformApiKey'] as String?) ?? '',
    platformSyncEnabled: (m['platformSyncEnabled'] as bool?) ?? false,
    autoBackup: (m['autoBackup'] as bool?) ?? true,
    backupDir2: (m['backupDir2'] as String?) ?? '',
    lastAutoBackup: DateTime.tryParse((m['lastAutoBackup'] as String?) ?? ''),
    lastAutoBackupPath: (m['lastAutoBackupPath'] as String?) ?? '',
  );

  Map<String, Object?> toJson() => {
    'recoveryEmail': recoveryEmail,
    'recoveryWhatsapp': recoveryWhatsapp,
    'recoveryPinHash': recoveryPinHash,
    'lanMode': lanMode,
    'lanHostAddress': lanHostAddress,
    'platformUrl': platformUrl,
    'platformApiKey': platformApiKey,
    'platformSyncEnabled': platformSyncEnabled,
    'autoBackup': autoBackup,
    'backupDir2': backupDir2,
    'lastAutoBackup': lastAutoBackup?.toIso8601String(),
    'lastAutoBackupPath': lastAutoBackupPath,
  };

  AppPrefs copyWith({
    String? recoveryEmail,
    String? recoveryWhatsapp,
    String? recoveryPinHash,
    String? lanMode,
    String? lanHostAddress,
    String? platformUrl,
    String? platformApiKey,
    bool? platformSyncEnabled,
    bool? autoBackup,
    String? backupDir2,
    DateTime? lastAutoBackup,
    String? lastAutoBackupPath,
  }) => AppPrefs(
    recoveryEmail: recoveryEmail ?? this.recoveryEmail,
    recoveryWhatsapp: recoveryWhatsapp ?? this.recoveryWhatsapp,
    recoveryPinHash: recoveryPinHash ?? this.recoveryPinHash,
    lanMode: lanMode ?? this.lanMode,
    lanHostAddress: lanHostAddress ?? this.lanHostAddress,
    platformUrl: platformUrl ?? this.platformUrl,
    platformApiKey: platformApiKey ?? this.platformApiKey,
    platformSyncEnabled: platformSyncEnabled ?? this.platformSyncEnabled,
    autoBackup: autoBackup ?? this.autoBackup,
    backupDir2: backupDir2 ?? this.backupDir2,
    lastAutoBackup: lastAutoBackup ?? this.lastAutoBackup,
    lastAutoBackupPath: lastAutoBackupPath ?? this.lastAutoBackupPath,
  );
}

class AppPrefsRepository {
  /// مجلد الحفظ (مجلد قاعدة البيانات). قابل للاستبدال في الاختبارات.
  static Future<Directory> Function() directory =
      getApplicationSupportDirectory;

  static const fileName = 'clinic_prefs.json';

  Future<File> _file() async =>
      File(p.join((await directory()).path, fileName));

  Future<AppPrefs> load() async {
    try {
      // ملف صغير جداً ← قراءة متزامنة فورية.
      final f = await _file();
      if (!f.existsSync()) return const AppPrefs();
      final data = jsonDecode(f.readAsStringSync());
      if (data is Map<String, Object?>) return AppPrefs.fromJson(data);
    } catch (_) {
      // ملف غير موجود أو تالف ← القيم الافتراضية.
    }
    return const AppPrefs();
  }

  Future<void> save(AppPrefs prefs) async {
    final f = await _file();
    f.parent.createSync(recursive: true);
    // كتابة آمنة: ملف مؤقت ثم استبدال.
    final tmp = File('${f.path}.tmp');
    tmp.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(prefs.toJson()),
      flush: true,
    );
    if (f.existsSync()) f.deleteSync();
    tmp.renameSync(f.path);
  }

  Future<AppPrefs> update(AppPrefs Function(AppPrefs) change) async {
    final next = change(await load());
    await save(next);
    return next;
  }
}

