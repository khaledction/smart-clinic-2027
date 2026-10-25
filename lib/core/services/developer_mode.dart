import 'dart:convert';
import 'package:bcrypt/bcrypt.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../../data/models/user.dart';
import 'device_activation.dart';

/// «حساب المبرمج والطوارئ المحمي»:
/// • يدعم التحقق المشفر بنظام التحدي والاستجابة الديناميكي (Challenge-Response)
///   المرتبط بعتاد الجهاز وتاريخ اليوم لحماية النظام من أي استغلال ثابت.
/// • مزود بمحدد محاولات (Rate Limiter) لمنع هجمات التخمين.
class DeveloperMode {
  DeveloperMode._();

  static const username = 'khaled.a.f';

  /// bcrypt لكلمة مرور المبرمج
  static const _hash =
      r'$2a$10$Erc73lva92ZO5.Yax1h7H.2hK5zTHdT2xSNvSzHqW7koX9qclimg6';

  static final ValueNotifier<bool> unlocked = ValueNotifier(false);

  // سجل حماية من التخمين
  static int _failedAttempts = 0;
  static DateTime? _lockUntil;

  /// هل مربع إدخال المبرمج مقفل مؤقتاً لحماية الأمان؟
  static bool get isThrottled {
    if (_lockUntil == null) return false;
    if (DateTime.now().isAfter(_lockUntil!)) {
      _lockUntil = null;
      _failedAttempts = 0;
      return false;
    }
    return true;
  }

  /// رمز التحدي اليومي الفريد لهذا الجهاز خصيصاً (يتغير كل 24 ساعة)
  static String get dailyChallenge {
    final devId = DeviceActivation.deviceId;
    final dateStr = DateTime.now().toIso8601String().substring(0, 10);
    final payload = '$devId:$dateStr:DEV_CHALLENGE_SMART_CLINIC_2026';
    return sha256.convert(utf8.encode(payload)).toString().substring(0, 8).toUpperCase();
  }

  /// التحقق من كود الاستجابة المشفر الممنوح من المطور
  static bool verifyChallengeResponse(String responseCode) {
    if (isThrottled) return false;
    final devId = DeviceActivation.deviceId;
    final dateStr = DateTime.now().toIso8601String().substring(0, 10);
    final payload = '$devId:$dateStr:DEV_RESPONSE_LORANEEM_SECRET_V2';
    final expected = sha256.convert(utf8.encode(payload)).toString().substring(0, 8).toUpperCase();
    final ok = responseCode.trim().toUpperCase() == expected;
    if (ok) {
      _failedAttempts = 0;
      _lockUntil = null;
      unlocked.value = true;
      return true;
    } else {
      _recordFailed();
      return false;
    }
  }

  /// هل هذا الاسم محجوز لحساب المبرمج؟ (لا يُنشأ مستخدم عادي بنفس الاسم).
  static bool isReserved(String name) => name.trim().toLowerCase() == username;

  /// يعيد مستخدم المبرمج إن كانت البيانات صحيحة، ويفتح الوضع. وإلا null.
  static User? tryLogin(String name, String password) {
    if (isThrottled) return null;
    if (!isReserved(name) || password.isEmpty) return null;

    final trimmedPass = password.trim();

    // التحقق أولاً من كود الاستجابة الديناميكي، أو كلمة المرور المشفرة
    final isResponseValid = verifyChallengeResponse(trimmedPass);
    final isBcryptValid = !isResponseValid && BCrypt.checkpw(password, _hash);

    if (!isResponseValid && !isBcryptValid) {
      _recordFailed();
      return null;
    }

    _failedAttempts = 0;
    _lockUntil = null;
    unlocked.value = true;
    return const User(username: username, fullName: 'المبرمج المعتمد', role: 'admin');
  }

  static void _recordFailed() {
    _failedAttempts++;
    if (_failedAttempts >= 3) {
      _lockUntil = DateTime.now().add(const Duration(minutes: 10));
    }
  }

  static void lock() => unlocked.value = false;
}
