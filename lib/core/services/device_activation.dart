import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// ============================================================================
///  مدد الترخيص المعتمدة لبرنامج Smart Clinic (وفق المتطلبات الحصرية)
/// ============================================================================
enum LicenseDuration {
  oneMonth('1M', 'شهرية', 30, 'شهر واحد'),
  threeMonths('3M', 'ثلاثة أشهر', 90, '3 أشهر'),
  sixMonths('6M', 'ستة أشهر', 180, '6 أشهر'),
  nineMonths('9M', 'تسعة أشهر', 270, '9 أشهر'),
  oneYear('1Y', 'سنة', 365, 'سنة كاملة'),
  twoYears('2Y', 'سنتان', 730, 'سنتان كاملتان'),
  lifetime('LT', 'دائم', 36500, 'ترخيص دائم مدى الحياة');

  final String code;
  final String label;
  final int days;
  final String description;

  const LicenseDuration(this.code, this.label, this.days, this.description);

  bool get isLifetime => code == 'LT';

  static LicenseDuration? fromCode(String code) {
    final clean = code.trim().toUpperCase();
    for (final d in LicenseDuration.values) {
      if (d.code == clean) return d;
    }
    return null;
  }
}

/// نتيجة محاولة التفعيل
class ActivationResult {
  final bool success;
  final String message;
  final bool isLocked;
  final int remainingAttempts;
  final LicenseDuration? duration;
  final DateTime? expiresAt;

  const ActivationResult({
    required this.success,
    required this.message,
    this.isLocked = false,
    this.remainingAttempts = 0,
    this.duration,
    this.expiresAt,
  });
}

/// ============================================================================
///  نظام ترخيص وتفعيل برنامج Smart Clinic لإدارة العيادات الطبية — V26
/// ============================================================================
/// - كود خاص لكل جهاز مشتق من بصمة العتاد الثابتة
/// - مدد محددة حصراً: شهرية، 3 أشهر، 6 أشهر، 9 أشهر، سنة، سنتان، دائم
/// - لا يتجدد الترخيص إلا بكود جديد حصراً من المطور
/// - حد أقصى محاولتان فاشلتان: بعدهما يُقفل مربع الإدخال وتظهر رسالة التحذير
/// - الحفاظ التام على بيانات المرضى وقاعدة البيانات D:\myclinic دون مساس
class DeviceActivation {
  DeviceActivation._();

  /// السر المشترك لتوليد والتحقق من كود التفعيل وأكواد فك القفل
  static const _salt = 'LORANEEM-TECH-CLINIC-2026';

  /// اشتقاق مفتاح HMAC التشفيري الداخلي لمنع التلاعب بالملفات
  static String _deriveHmacKey(String devId) {
    const kPrefix = 'SC-2026-LORANEEM-SEC-VAULT';
    final step1 = sha256.convert(utf8.encode('$kPrefix:$_salt:$devId')).toString();
    return sha256.convert(utf8.encode('$step1:$devId:HMAC_INTEGRITY_KEY')).toString();
  }

  /// حساب التوقيع الرقمي لسجل التفعيل لحمايته من التعديل اليدوي في المفكرة
  static String _computeSignature({
    required String devId,
    required String durCode,
    required bool isPerm,
    required bool act,
    required String actAt,
    required String expAt,
    required int attempts,
    required bool locked,
    required List<String> codes,
  }) {
    final key = _deriveHmacKey(devId);
    final sorted = List<String>.from(codes)..sort();
    final payload = '$devId|$durCode|$isPerm|$act|$actAt|$expAt|$attempts|$locked|${sorted.join(",")}';
    final hmac = Hmac(sha256, utf8.encode(key));
    return hmac.convert(utf8.encode(payload)).toString().toUpperCase();
  }

  /// فحص رياضي لصحة كود التفعيل دون تطبيقه (للتحقق من سلامة الأكواد المحفوظة)
  static bool verifyCodeMathematically(String rawCode) {
    final clean = rawCode.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    final isDa = clean.startsWith('DA');
    final isSc = clean.startsWith('SC');
    if ((!isDa && !isSc) || clean.length != 20) return false;
    final durCode = clean.substring(2, 4);
    if (LicenseDuration.fromCode(durCode) == null) return false;
    final token = clean.substring(4, 8);
    final signature = clean.substring(8, 20);

    final expectedPayload = '$deviceId:$durCode:$token:$_salt';
    final expectedDigest = sha256
        .convert(utf8.encode(expectedPayload))
        .toString()
        .toUpperCase();
    final expectedSignature = expectedDigest.substring(0, 12);
    return signature == expectedSignature;
  }

  /// الحد الأقصى للمحاولات الفاشلة المسموحة قبل القفل التام
  static const int maxFailedAttempts = 2;

  /// أسماء ملفات التفعيل وبصمة الجهاز
  static const fileName = 'activation.json';
  static const _fpCacheName = 'device.id';

  /// مسارات التخزين الدائمة لحماية السجل حتى بعد فورمات C
  static const _dataDir = r'D:\myclinic';
  static const _dataDirAlt = r'C:\myclinic';

  static String _fingerprint = '';
  static String _hostname = '';
  static bool _isFallback = false;
  static String? _dirPath;

  /// حالة التفعيل الحالية (سارٍ وغير منتهٍ)
  static bool isActivated = false;

  /// هل انتهت فترة الترخيص السابقة؟
  static bool isExpired = false;

  /// هل تم اكتشاف تلاعب بساعة وتاريخ النظام؟
  static bool isClockTampered = false;

  /// هل تم قفل مربع الإدخال بعد استنفاد محاولتين فاشلتين؟
  static bool isLocked = false;

  /// عدد المحاولات الفاشلة المسجلة
  static int failedAttempts = 0;

  /// باقة المدة النشطة
  static LicenseDuration? activeDuration;

  /// هل الترخيص دائم مدى الحياة؟
  static bool get isPermanent => activeDuration == LicenseDuration.lifetime;

  /// تاريخ التفعيل
  static DateTime? activatedAt;

  /// تاريخ انتهاء الترخيص (null في حال الترخيص الدائم)
  static DateTime? expiresAt;

  /// تاريخ آخر تشغيل مسجل
  static DateTime? lastRunAt;

  /// سجل الأكواد المستخدمة سابقاً على هذا الجهاز
  static final Set<String> _usedCodes = {};

  /// وجود تفعيل سابق غير مطابق (وضع استعادة نادر)
  static bool recoveryAvailable = false;

  /// إشعار لإعادة بناء الواجهة فور التفعيل أو القفل أو فك القفل
  static final ValueNotifier<int> state = ValueNotifier(0);

  /// رمز الجهاز المعروض للعميل (12 حرفاً مميزاً للعتاد)
  static String get deviceId {
    if (_fingerprint.isEmpty) return 'unknown-device';
    return sha256
        .convert(utf8.encode(_fingerprint))
        .toString()
        .substring(0, 12)
        .toUpperCase();
  }

  /// عدد الأيام المتبقية في الاشتراك الحالي
  static int get daysRemaining {
    if (!isActivated) return 0;
    if (isPermanent) return 99999;
    if (expiresAt == null) return 0;
    final diff = expiresAt!.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  /// قائمة المسارات المرشحة لحفظ ملف التفعيل
  static List<File> _files(String name) {
    final list = <File>[];
    if (_dirPath != null) list.add(File(p.join(_dirPath!, name)));
    list.add(File(p.join(_dataDir, name)));
    list.add(File(p.join(_dataDirAlt, name)));
    return list;
  }

  /// يقرأ حالة التفعيل عند الإقلاع (يُستدعى في main قبل runApp).
  static Future<void> load() async {
    try {
      _hostname = Platform.localHostname;
    } catch (_) {}
    try {
      final dir = await getApplicationSupportDirectory();
      _dirPath = dir.path;
    } catch (_) {}

    _fingerprint = await _resolveFingerprint();

    // فحص ملفات التفعيل المخزنة
    for (final f in _files(fileName)) {
      Map<String, Object?> m;
      try {
        if (!f.existsSync()) continue;
        m = jsonDecode(f.readAsStringSync()) as Map<String, Object?>;
      } catch (_) {
        continue;
      }

      // قراءة سجل المحاولات الفاشلة والقفل
      final savedAttempts = (m['failedAttempts'] as num?)?.toInt() ?? 0;
      failedAttempts = savedAttempts;
      isLocked = (m['isLocked'] as bool?) ?? (failedAttempts >= maxFailedAttempts);

      // قراءة قائمة الأكواد السابقة
      final rawUsed = m['usedCodes'];
      if (rawUsed is List) {
        _usedCodes.clear();
        for (final item in rawUsed) {
          if (item != null) _usedCodes.add(item.toString().toUpperCase());
        }
      }

      // التحقق من مطابقة بصمة العتاد للجهاز الحالي
      final savedFp = m['fingerprint'] as String?;
      final savedDevId = m['deviceId'] as String?;
      final isCurrentDevice = (_fingerprint.isNotEmpty && savedFp == _fingerprint) ||
          (savedDevId != null && savedDevId == deviceId);

      if (!isCurrentDevice) {
        // فحص وضع الاستعادة
        final savedHosts = (m['hostnames'] as List?)?.cast<String>() ?? const <String>[];
        if (_isFallback || savedHosts.isNotEmpty) recoveryAvailable = true;
        continue;
      }

      // الجهاز مطابق: فحص حالة التفعيل والمدة مع التحقق من التوقيع الرقمي (Anti-Tamper)
      final wasActivated = m['activated'] == true;
      if (!wasActivated) {
        isActivated = false;
        continue;
      }

      final savedSig = m['signature'] as String?;
      final savedDur = (m['durationCode'] as String?) ?? '';
      final savedPerm = (m['isPermanent'] as bool?) ?? false;
      final savedActAt = (m['activatedAt'] as String?) ?? '';
      final savedExpAt = (m['expiresAt'] as String?) ?? '';

      final expectedSig = _computeSignature(
        devId: deviceId,
        durCode: savedDur,
        isPerm: savedPerm,
        act: true,
        actAt: savedActAt,
        expAt: savedExpAt,
        attempts: savedAttempts,
        locked: isLocked,
        codes: _usedCodes.toList(),
      );

      if (savedSig != expectedSig) {
        // فحص وجود كود شرعي محفوظ مسبقاً لاعتماده وترقية التوقيع
        bool validMigration = false;
        for (final code in _usedCodes) {
          if (verifyCodeMathematically(code)) {
            validMigration = true;
            break;
          }
        }
        if (!validMigration) {
          // تم اكتشاف تلاعب بالملف عبر المفكرة أو وسيلة خارجية!
          debugPrint('🚨 [SECURITY ALERT] تم رصد محاولة تلاعب بملف التفعيل: التوقيع الرقمي غير صالح!');
          isActivated = false;
          isExpired = true;
          isLocked = true;
          failedAttempts = maxFailedAttempts;
          _saveRecord();
          return;
        }
      }

      activatedAt = DateTime.tryParse((m['activatedAt'] as String?) ?? '');
      expiresAt = DateTime.tryParse((m['expiresAt'] as String?) ?? '');
      lastRunAt = DateTime.tryParse((m['lastRunAt'] as String?) ?? '');
      final durCode = m['durationCode'] as String?;
      if (durCode != null) {
        activeDuration = LicenseDuration.fromCode(durCode);
      }

      final now = DateTime.now();

      // إذا كان الترخيص دائماً: لا تنتهي صلاحيته أبداً
      if (activeDuration == LicenseDuration.lifetime) {
        isActivated = true;
        isExpired = false;
        isClockTampered = false;
        _saveRecord();
        return;
      }

      // فحص التلاعب بساعة الحاسوب (إرجاع الوقت للوراء بأكثر من ساعتين)
      if (lastRunAt != null && now.isBefore(lastRunAt!.subtract(const Duration(hours: 2)))) {
        isClockTampered = true;
        isActivated = false;
        isExpired = true;
        return;
      }

      // فحص انتهاء مدة الترخيص
      if (expiresAt != null && now.isAfter(expiresAt!)) {
        isExpired = true;
        isActivated = false;
        return;
      }

      // الترخيص سارٍ بنجاح!
      isActivated = true;
      isExpired = false;
      isClockTampered = false;

      // تحديث وقت آخر تشغيل وحفظه
      _saveRecord();
      return;
    }
  }

  /// يحسم بصمة الجهاز: كاش سابق، وإلا قراءة العتاد، وإلا الاسم احتياطياً.
  static Future<String> _resolveFingerprint() async {
    for (final f in _files(_fpCacheName)) {
      try {
        if (!f.existsSync()) continue;
        final v = f.readAsStringSync().trim();
        if (v.length >= 8) {
          _isFallback = v.startsWith('HOST:');
          return v;
        }
      } catch (_) {}
    }
    final hw = await _readHardwareId();
    final fp = hw.isNotEmpty ? 'HW:$hw' : 'HOST:$_hostname';
    _isFallback = hw.isEmpty;
    for (final f in _files(_fpCacheName)) {
      try {
        if (!f.parent.existsSync()) f.parent.createSync(recursive: true);
        f.writeAsStringSync(fp, flush: true);
      } catch (_) {}
    }
    return fp;
  }

  /// يقرأ (رقم اللوحة + المعالج + قرص النظام) باستدعاء WMI سريع.
  static Future<String> _readHardwareId() async {
    try {
      final r = await Process.run('powershell.exe', [
        '-NoProfile',
        '-NonInteractive',
        '-WindowStyle',
        'Hidden',
        '-Command',
        r'(Get-CimInstance Win32_ComputerSystemProduct).UUID; (Get-CimInstance Win32_Processor | Select-Object -First 1).ProcessorId; $d = (Get-CimInstance Win32_DiskPartition | Where-Object { $_.BootPartition } | Select-Object -First 1).DiskIndex; (Get-CimInstance Win32_DiskDrive | Where-Object { $_.Index -eq $d }).SerialNumber',
      ]).timeout(const Duration(seconds: 3));
      final out = (r.stdout as String?) ?? '';
      final parts = out
          .split(RegExp(r'\r?\n'))
          .map((e) => e.trim())
          .where(_looksReal)
          .toList();
      if (parts.isEmpty) return '';
      return parts.join('|');
    } catch (_) {
      return '';
    }
  }

  /// يرفض القيم الوهمية التي تضعها بعض اللوحات.
  static bool _looksReal(String v) {
    if (v.length < 4) return false;
    final u = v.toUpperCase();
    if (u.contains('TO BE FILLED')) return false;
    if (u == 'NONE' || u == 'UNKNOWN' || u == 'DEFAULT STRING') return false;
    if (RegExp(r'^0+$').hasMatch(u)) return false;
    if (u.startsWith('FFFFFFFF')) return false;
    return true;
  }

  /// حفظ بيانات التفعيل في كافة المسارات الدائمة مع التوقيع الرقمي المقاوم للتلاعب
  static bool _saveRecord() {
    try {
      final actAtStr = activatedAt?.toIso8601String() ?? '';
      final expAtStr = activeDuration == LicenseDuration.lifetime ? '' : (expiresAt?.toIso8601String() ?? '');
      final sig = _computeSignature(
        devId: deviceId,
        durCode: activeDuration?.code ?? '',
        isPerm: isPermanent,
        act: isActivated,
        actAt: actAtStr,
        expAt: expAtStr,
        attempts: failedAttempts,
        locked: isLocked,
        codes: _usedCodes.toList(),
      );

      final record = <String, Object?>{
        'fingerprint': _fingerprint,
        'deviceId': deviceId,
        'hostnames': _hostname.isEmpty ? <String>[] : <String>[_hostname],
        'activated': isActivated,
        'activatedAt': activatedAt?.toIso8601String(),
        'expiresAt': activeDuration == LicenseDuration.lifetime ? null : expiresAt?.toIso8601String(),
        'durationCode': activeDuration?.code,
        'durationLabel': activeDuration?.label,
        'isPermanent': isPermanent,
        'lastRunAt': DateTime.now().toIso8601String(),
        'failedAttempts': failedAttempts,
        'isLocked': isLocked,
        'usedCodes': _usedCodes.toList(),
        'signature': sig,
      };
      final text = const JsonEncoder.withIndent('  ').convert(record);
      var ok = false;
      for (final f in _files(fileName)) {
        try {
          if (!f.parent.existsSync()) f.parent.createSync(recursive: true);
          f.writeAsStringSync(text, flush: true);
          ok = true;
        } catch (_) {}
      }
      return ok;
    } catch (_) {
      return false;
    }
  }

  /// ==========================================================================
  ///  التحقق من كود التفعيل الممنوح وتطبيقه
  /// ==========================================================================
  /// صيغة الكود المعتمدة:
  /// DA-[المدة]-[رمز الإصدار]-[التوقيع الرقمي]
  /// مثال: DA-LT-K3R8-24AB-53DA-7D02
  static ActivationResult activateWithCode(String rawCode) {
    // 1) إذا كان مربع الإدخال مقفلاً بعد محاولتين
    if (isLocked) {
      return const ActivationResult(
        success: false,
        isLocked: true,
        remainingAttempts: 0,
        message: 'لا تحاول أكثر كي لا تخسر البيانات، اتصل بالمطور',
      );
    }

    final clean = rawCode.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();

    // 2) التحقق من البادئة والطول (يدعم بادئة DA و SC)
    final isDa = clean.startsWith('DA');
    final isSc = clean.startsWith('SC');
    if ((!isDa && !isSc) || clean.length != 20) {
      return _handleFailedAttempt('صيغة كود التفعيل غير صحيحة، يرجى مراجعة الكود بدقة.');
    }

    // 3) استخراج رمز المدة
    final durCode = clean.substring(2, 4);
    final duration = LicenseDuration.fromCode(durCode);
    if (duration == null) {
      return _handleFailedAttempt('مدة الترخيص في الكود غير معروفة، اتصل بالمطور.');
    }

    // 4) استخراج رمز الإصدار والتوقيع الرقمي
    final token = clean.substring(4, 8);
    final signature = clean.substring(8, 20);

    // 5) حساب التوقيع المتوقع لهذا الجهاز خصيصاً
    final expectedPayload = '$deviceId:$durCode:$token:$_salt';
    final expectedDigest = sha256
        .convert(utf8.encode(expectedPayload))
        .toString()
        .toUpperCase();
    final expectedSignature = expectedDigest.substring(0, 12);

    if (signature != expectedSignature) {
      return _handleFailedAttempt('كود التفعيل غير مطابق لهذا الجهاز أو غير صالح.');
    }

    // 6) فحص عدم إعادة استخدام كود قديم
    if (_usedCodes.contains(clean)) {
      return _handleFailedAttempt(
        'هذا الكود تم استخدامه سابقاً على هذا الجهاز! يتطلب التجديد كوداً جديداً حصراً من المطور.',
      );
    }

    // 7) نجاح التفعيل وتحديد مدة الاشتراك الجديدة
    final now = DateTime.now();
    DateTime? newExpires;

    if (duration == LicenseDuration.lifetime) {
      newExpires = null; // دائم مدى الحياة
    } else {
      DateTime baseDate = now;
      if (isActivated && expiresAt != null && expiresAt!.isAfter(now)) {
        baseDate = expiresAt!;
      }
      newExpires = baseDate.add(Duration(days: duration.days));
    }

    _usedCodes.add(clean);
    isActivated = true;
    isExpired = false;
    isClockTampered = false;
    isLocked = false;
    failedAttempts = 0;
    activeDuration = duration;
    activatedAt = now;
    expiresAt = newExpires;
    lastRunAt = now;
    recoveryAvailable = false;

    _saveRecord();
    state.value++;

    final expiryMsg = duration == LicenseDuration.lifetime
        ? 'تم تفعيل الترخيص الدائم مدى الحياة بنجاح.'
        : 'تم تفعيل الترخيص بنجاح لمدة ${duration.label} حتى ${newExpires!.year}/${newExpires.month.toString().padLeft(2, '0')}/${newExpires.day.toString().padLeft(2, '0')}.';

    return ActivationResult(
      success: true,
      message: expiryMsg,
      duration: duration,
      expiresAt: newExpires,
    );
  }

  /// معالجة المحاولة الفاشلة وحساب العداد وقفل الإدخال بعد محاولتين
  static ActivationResult _handleFailedAttempt(String customReason) {
    failedAttempts++;
    if (failedAttempts >= maxFailedAttempts) {
      isLocked = true;
      _saveRecord();
      state.value++;
      return const ActivationResult(
        success: false,
        isLocked: true,
        remainingAttempts: 0,
        message: 'لا تحاول أكثر كي لا تخسر البيانات، اتصل بالمطور',
      );
    }

    _saveRecord();
    state.value++;
    final remaining = maxFailedAttempts - failedAttempts;
    return ActivationResult(
      success: false,
      isLocked: false,
      remainingAttempts: remaining,
      message: '$customReason\nتبقى لديك محاولة واحدة أخيرة قبل قفل مربع الإدخال!',
    );
  }

  /// فك قفل الإدخال بعد انتهاء المحاولتين
  static bool unlockWithCode(String unlockCode) {
    final clean = unlockCode.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    final isDaUnlock = clean.startsWith('DAUNLOCK');
    final isScUnlock = clean.startsWith('SCUNLOCK');
    if ((!isDaUnlock && !isScUnlock) || clean.length != 24) return false;

    final token = clean.substring(8, 12);
    final signature = clean.substring(12, 24);

    final expectedPayload = '$deviceId:UNLOCK:$token:$_salt';
    final expectedDigest = sha256
        .convert(utf8.encode(expectedPayload))
        .toString()
        .toUpperCase();
    final expectedSignature = expectedDigest.substring(0, 12);

    if (signature != expectedSignature) return false;

    failedAttempts = 0;
    isLocked = false;
    _saveRecord();
    state.value++;
    return true;
  }

  /// تصفير القفل عبر دخول المبرمج بكلمة المرور
  static void resetLockout() {
    failedAttempts = 0;
    isLocked = false;
    _saveRecord();
    state.value++;
  }

  /// استعادة التفعيل بنقرة واحدة
  static bool recover() {
    if (!recoveryAvailable) return false;
    isActivated = true;
    recoveryAvailable = false;
    activatedAt = DateTime.now();
    _saveRecord();
    state.value++;
    return true;
  }

  /// تفعيل مباشر من وضع المبرمج
  static bool developerActivate({LicenseDuration duration = LicenseDuration.lifetime}) {
    final now = DateTime.now();
    isActivated = true;
    isExpired = false;
    isClockTampered = false;
    isLocked = false;
    failedAttempts = 0;
    activeDuration = duration;
    activatedAt = now;
    expiresAt = duration == LicenseDuration.lifetime ? null : now.add(Duration(days: duration.days));
    lastRunAt = now;
    recoveryAvailable = false;
    _saveRecord();
    state.value++;
    return true;
  }

  /// توليد كود تفعيل متوافق
  static String generateCode({
    required String targetDeviceId,
    required LicenseDuration duration,
    String? token,
  }) {
    final dev = targetDeviceId.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    final tok = (token ?? 'A1B2').replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase().padRight(4, '0').substring(0, 4);
    final payload = '$dev:${duration.code}:$tok:$_salt';
    final digest = sha256.convert(utf8.encode(payload)).toString().toUpperCase();
    final sig = digest.substring(0, 12);
    return 'DA-${duration.code}-$tok-${sig.substring(0, 4)}-${sig.substring(4, 8)}-${sig.substring(8, 12)}';
  }

  /// توليد كود فك القفل
  static String generateUnlockCode({
    required String targetDeviceId,
    String? token,
  }) {
    final dev = targetDeviceId.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    final tok = (token ?? 'UN01').replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase().padRight(4, '0').substring(0, 4);
    final payload = '$dev:UNLOCK:$tok:$_salt';
    final digest = sha256.convert(utf8.encode(payload)).toString().toUpperCase();
    final sig = digest.substring(0, 12);
    return 'DA-UNLOCK-$tok-${sig.substring(0, 4)}-${sig.substring(4, 8)}-${sig.substring(8, 12)}';
  }
}

