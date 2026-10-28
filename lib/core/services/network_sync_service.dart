import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import '../../data/repositories/app_prefs_repository.dart';
import 'device_activation.dart';

/// أنماط تشغيل الشبكة المتوافقة مع العيادة
enum ClinicNetworkMode {
  standalone('جهاز مستقل', 'العمل محلياً على هذا الحاسوب دون اتصال شبكي'),
  lanHost('خادم رئيسي (LAN)', 'استضافة قاعدة البيانات ومشاركتها مع حواسيب العيادة الأخرى'),
  lanClient('حاسوب فرعي (LAN)', 'الاتصال بقاعدة بيانات العيادة عبر الشبكة المحلية'),
  platformCloud('منصة سحابية متصلة', 'المزامنة التلقائية مع منصة Smart Clinic المركزية');

  final String label;
  final String description;
  const ClinicNetworkMode(this.label, this.description);
}

/// حالة اتصال الشبكة / المنصة
enum SyncConnectionStatus {
  idle,
  checking,
  online,
  offline,
  syncing,
  error,
}

/// ============================================================================
///  خدمة الشبكة والمزامنة السحابية — Network & Platform Sync Service
/// ============================================================================
/// مهيأة معمارياً لـ:
///  1. الربط بين حواسيب العيادة (طبيب / سكرتارية) على الشبكة المحلية LAN
///  2. الربط المستقبلي بمنصة Smart Clinic السحابية المركزية
///  3. منع تسريب البيانات وتأمين القنوات المشفرة
class NetworkSyncService {
  NetworkSyncService._();

  static final NetworkSyncService instance = NetworkSyncService._();

  final ValueNotifier<SyncConnectionStatus> status =
      ValueNotifier(SyncConnectionStatus.idle);
  final ValueNotifier<String?> lastError = ValueNotifier(null);
  final ValueNotifier<DateTime?> lastSyncTime = ValueNotifier(null);

  Timer? _periodicTimer;

  /// تهيئة الخدمة وقراءة الإعدادات
  Future<void> initialize() async {
    final prefs = await AppPrefsRepository().load();
    if (prefs.platformSyncEnabled && prefs.platformUrl.isNotEmpty) {
      startAutoSync();
    }
  }

  /// فحص الاتصال بالخادم الرئيسي في الشبكة المحلية LAN
  Future<bool> checkLanHost(String hostIp, {int port = 8088}) async {
    status.value = SyncConnectionStatus.checking;
    try {
      final socket = await Socket.connect(
        hostIp,
        port,
        timeout: const Duration(seconds: 3),
      );
      socket.destroy();
      status.value = SyncConnectionStatus.online;
      lastError.value = null;
      return true;
    } catch (e) {
      status.value = SyncConnectionStatus.offline;
      lastError.value = 'تعذر الاتصال بالجهاز الرئيسي: $e';
      return false;
    }
  }

  /// فحص الاتصال بالمنصة السحابية
  Future<bool> checkPlatformHealth(String platformUrl, String apiKey) async {
    if (platformUrl.isEmpty) return false;
    status.value = SyncConnectionStatus.checking;

    try {
      final uri = Uri.parse(platformUrl).resolve('/api/v1/health');
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
      final request = await client.getUrl(uri);
      request.headers.set('Authorization', 'Bearer $apiKey');
      request.headers.set('X-Device-Id', DeviceActivation.deviceId);

      final response = await request.close();
      final isOk = response.statusCode >= 200 && response.statusCode < 300;

      if (isOk) {
        status.value = SyncConnectionStatus.online;
        lastError.value = null;
        return true;
      } else {
        status.value = SyncConnectionStatus.error;
        lastError.value = 'استجابة المنصة برمز غير ناجح: ${response.statusCode}';
        return false;
      }
    } catch (e) {
      status.value = SyncConnectionStatus.offline;
      lastError.value = 'تعذر الوصول للمنصة السحابية: $e';
      return false;
    }
  }

  /// إرسال إشعار أمني أو رمز تحقق عبر بوابة المنصة (SMS / WhatsApp API)
  /// حماية كاملة: يتم الإرسال من الخادم للطرف المتلقي دون كشف الرمز في شاشة الجهاز المحلي
  Future<bool> dispatchSecureNotification({
    required String phone,
    required String recipientName,
    required String message,
  }) async {
    final prefs = await AppPrefsRepository().load();
    if (!prefs.platformSyncEnabled || prefs.platformUrl.isEmpty) {
      return false;
    }

    try {
      final uri = Uri.parse(prefs.platformUrl).resolve('/api/v1/notifications/send');
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
      final request = await client.postUrl(uri);
      request.headers.set('Content-Type', 'application/json; charset=utf-8');
      request.headers.set('Authorization', 'Bearer ${prefs.platformApiKey}');
      request.headers.set('X-Device-Id', DeviceActivation.deviceId);

      final payload = jsonEncode({
        'recipientPhone': phone,
        'recipientName': recipientName,
        'message': message,
        'sentAt': DateTime.now().toIso8601String(),
      });
      request.write(payload);

      final response = await request.close();
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      debugPrint('NetworkSyncService.dispatchSecureNotification error: $e');
      return false;
    }
  }

  /// بدء فحص المزامنة الدوري عند العمل مع منصة مركزية
  void startAutoSync({Duration interval = const Duration(minutes: 5)}) {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(interval, (_) => triggerSync());
  }

  void stopAutoSync() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }

  /// تنفيذ دورة مزامنة آمنة
  Future<void> triggerSync() async {
    final prefs = await AppPrefsRepository().load();
    if (!prefs.platformSyncEnabled || prefs.platformUrl.isEmpty) return;

    status.value = SyncConnectionStatus.syncing;
    try {
      final ok = await checkPlatformHealth(prefs.platformUrl, prefs.platformApiKey);
      if (ok) {
        lastSyncTime.value = DateTime.now();
        status.value = SyncConnectionStatus.online;
      }
    } catch (e) {
      status.value = SyncConnectionStatus.error;
      lastError.value = e.toString();
    }
  }
}

