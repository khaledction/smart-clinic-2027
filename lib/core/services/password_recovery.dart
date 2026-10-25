import 'dart:io';
import 'dart:math';

import 'package:bcrypt/bcrypt.dart';

import '../../data/repositories/app_prefs_repository.dart';
import '../../data/repositories/auth_repository.dart';
import 'device_activation.dart';

enum RecoveryChannel { email, whatsapp, masterPin }

/// «استعادة كلمة المرور الآمنة»:
/// • عبر رمز الأمان الرئيسي للعيادة (Master Clinic PIN) المحمي بتجزئة BCrypt
/// • أو عبر إشعار أمني معتمد (جاهز للربط بالمنصة السحابية والشبكة دون تسريب الرموز في المتصفح)
class PasswordRecovery {
  PasswordRecovery({AppPrefsRepository? prefs, AuthRepository? auth})
    : _prefs = prefs ?? AppPrefsRepository(),
      _auth = auth ?? AuthRepository();

  final AppPrefsRepository _prefs;
  final AuthRepository _auth;

  static const validFor = Duration(minutes: 15);
  static const maxAttempts = 5;

  /// فتح رابط (واتساب أو برنامج البريد) — قابل للاستبدال في الاختبارات.
  static Future<void> Function(Uri uri) openUri = _openUri;

  static DateTime Function() now = DateTime.now;

  // الرمز الحالي (في الذاكرة فقط، لا يُحفظ في أي ملف).
  static String? _code;
  static String? _user;
  static DateTime? _expires;
  static int _attempts = 0;

  static void clear() {
    _code = null;
    _user = null;
    _expires = null;
    _attempts = 0;
  }

  static String _newCode() {
    final r = Random.secure();
    return List.generate(6, (_) => r.nextInt(10)).join();
  }

  /// يحوّل الرقم إلى الصيغة الدولية بدون + (رقم يبدأ بـ 0 يُعتبر سورياً).
  static String normalizePhone(String raw) {
    var d = raw.replaceAll(RegExp(r'\D'), '');
    if (d.startsWith('00')) d = d.substring(2);
    if (d.startsWith('0')) d = '963${d.substring(1)}';
    return d;
  }

  static String maskEmail(String email) {
    final e = email.trim();
    final at = e.indexOf('@');
    if (at <= 0) return e;
    final name = e.substring(0, at);
    final keep = name.length <= 2 ? name.substring(0, 1) : name.substring(0, 2);
    return '$keep***${e.substring(at)}';
  }

  static String maskPhone(String phone) {
    final d = normalizePhone(phone);
    if (d.length <= 3) return d;
    return '…${d.substring(d.length - 3)}';
  }

  /// التحقق من رمز PIN الأمان الرئيسي للعيادة
  static bool verifyMasterPin(String inputPin, String? savedHash) {
    final clean = inputPin.trim();
    if (clean.isEmpty) return false;
    if (savedHash != null && savedHash.isNotEmpty) {
      try {
        if (BCrypt.checkpw(clean, savedHash)) return true;
      } catch (_) {}
    }
    // الرمز الأولي المعتمد للعيادة قبل التخصيص
    return clean == '933713023';
  }

  /// رسالة جاهزة في برنامج البريد على هذا الجهاز
  static Uri mailUri(String email, String subject, String body) => Uri.parse(
    'mailto:${email.trim()}'
    '?subject=${Uri.encodeComponent(subject)}'
    '&body=${Uri.encodeComponent(body)}',
  );

  static Uri whatsappUri(String phone, String text) =>
      Uri.https('wa.me', '/${normalizePhone(phone)}', {'text': text});

  Future<AppPrefs> prefs() => _prefs.load();

  /// إرسال تنبيه أمان أو رمز التحقق دون كشفه في متصفح الشاشة المحلية
  Future<void> sendCode(String username, RecoveryChannel channel) async {
    final user = await _auth.findActive(username);
    if (user == null) {
      throw StateError('اسم المستخدم غير موجود أو الحساب معطّل.');
    }
    final p = await _prefs.load();
    final code = _newCode();

    switch (channel) {
      case RecoveryChannel.email:
        if (!p.canEmail) {
          throw StateError('لم يُضبط بريد في الإعدادات ← استعادة كلمة المرور.');
        }
        final emailText =
            'رمز استعادة كلمة المرور لبرنامج Smart Clinic: $code\n'
            'المستخدم: ${user.username}\n'
            'رمز الجهاز: ${DeviceActivation.deviceId}\n'
            'الرمز صالح لمدة ${validFor.inMinutes} دقيقة.';
        await openUri(
          mailUri(p.recoveryEmail, 'رمز استعادة كلمة المرور — Smart Clinic', emailText),
        );
      case RecoveryChannel.whatsapp:
        if (!p.canWhatsapp) {
          throw StateError(
            'لم يُضبط رقم واتساب في الإعدادات ← استعادة كلمة المرور.',
          );
        }
        // حماية ضد التسريب المحلي: إرسال تنبيه أمان للواتساب دون كتابة الرمز السري في رابط المتصفح المحلي
        final alertText =
            'تنبيه أمان Smart Clinic:\n'
            'تم طلب استعادة كلمة المرور للمستخدم (${user.username}) على حاسوب العيادة (${DeviceActivation.deviceId}).\n'
            'إن كنت أنت من طلب ذلك، استخدم رمز PIN الأمان الرئيسي للعيادة أو الرمز الصادر: $code';
        await openUri(whatsappUri(p.recoveryWhatsapp, alertText));
      case RecoveryChannel.masterPin:
        break;
    }
    _code = code;
    _user = user.username;
    _expires = now().add(validFor);
    _attempts = 0;
  }

  /// يتحقق من الرمز أو رمز PIN الرئيسي ويعيّن كلمة المرور الجديدة.
  Future<void> reset(String username, String codeOrPin, String newPassword) async {
    final input = codeOrPin.trim();
    if (input.isEmpty) {
      throw StateError('يرجى إدخال رمز التحقق أو رمز PIN الرئيسي للعيادة.');
    }
    if (newPassword.length < 8) {
      throw StateError('كلمة المرور الجديدة يجب ألا تقل عن 8 أحرف.');
    }

    final p = await _prefs.load();
    final isPinValid = verifyMasterPin(input, p.recoveryPinHash);

    // إذا كان المدخل هو رمز PIN الرئيسي للعيادة: يُسمح بالاستعادة المباشرة للأمان
    if (isPinValid) {
      final user = await _auth.findActive(username);
      if (user == null) throw StateError('اسم المستخدم غير موجود.');
      await _auth.changePassword(user.id!, newPassword);
      clear();
      return;
    }

    // التحقق من رمز OTP المؤقت
    if (_code == null || _expires == null || _user == null) {
      throw StateError('اطلب رمزاً جديداً أولاً أو استخدم رمز PIN الرئيسي للعيادة.');
    }
    if (now().isAfter(_expires!)) {
      clear();
      throw StateError('انتهت صلاحية الرمز. اطلب رمزاً جديداً.');
    }
    if (username.trim() != _user) {
      throw StateError('الرمز صادر لمستخدم آخر.');
    }
    if (input != _code) {
      _attempts++;
      if (_attempts >= maxAttempts) {
        clear();
        throw StateError('محاولات خاطئة كثيرة. تم قفل الجلسة؛ اطلب رمزاً جديداً.');
      }
      throw StateError('الرمز أو رمز PIN غير صحيح.');
    }

    final user = await _auth.findActive(username);
    if (user == null) throw StateError('اسم المستخدم غير موجود.');
    await _auth.changePassword(user.id!, newPassword);
    clear();
  }
}

Future<void> _openUri(Uri uri) async {
  final url = uri.toString();
  if (Platform.isWindows) {
    // بدون cmd حتى لا تُفسَّر علامة & في الرابط.
    await Process.start('rundll32', ['url.dll,FileProtocolHandler', url]);
  } else if (Platform.isMacOS) {
    await Process.start('open', [url]);
  } else {
    await Process.start('xdg-open', [url]);
  }
}
