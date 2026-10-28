import 'package:flutter/material.dart';

/// لوحة ألوان هادئة تناسب بيئة عيادة.
class AppColors {
  AppColors._();

  static const primary = Color(0xFF1B6CA8); // أزرق طبي
  static const primaryDark = Color(0xFF0F4C75);

  /// زر موحّد: خلفية كحلية وخط أبيض.
  static const navy = Color(0xFF12314B);
  static const accent = Color(0xFF17A2B8); // تركوازي
  static const success = Color(0xFF2E9E5B);
  static const warning = Color(0xFFE0A106);
  static const danger = Color(0xFFD64545);

  static const bg = Color(0xFFF4F6F9);
  static const surface = Colors.white;
  static const sidebar = Color(0xFF12314B);

  static const textPrimary = Color(0xFF1F2933);
  static const textSecondary = Color(0xFF6B7684);
  static const divider = Color(0xFFE3E8EF);

  /// حافة مربعات الإدخال: أغمق قليلاً من الفواصل حتى تظهر على الأبيض.
  static const fieldBorder = Color(0xFFB3C0CE);

  /// Unified calm header tint for every card/window header in the app.
  static const headerTint = Color(0xFFEAF1F6);

  /// Hover highlight for names and rows (mouse pass confirmation).
  static const hoverTint = Color(0xFFE0EEF5);

  /// Distinct side-column background (chart navigator).
  static const navColumn = Color(0xFFE5EDF3);

  /// إطار كحلي خفيف موحّد حول كل نافذة/بطاقة (كحلي القائمة الجانبية بشفافية).
  static const frame = Color(0x6612314B);

  /// إطار أوضح قليلاً عند مرور المؤشر.
  static const frameHover = Color(0x9912314B);

  /// لون تأكيد الدفع (أخضر).
  static const paid = Color(0xFF2E9E5B);

  /// Very calm card background for chart windows.
  static const cardTint = Color(0xFFF7FAFC);

  /// لون حسب حالة الموعد
  static Color forAppointmentStatus(String status) {
    switch (status) {
      case 'scheduled':
        return primary;
      case 'arrived':
        return accent;
      case 'done':
        return success;
      case 'cancelled':
        return textSecondary;
      case 'no_show':
        return danger;
      default:
        return textSecondary;
    }
  }
}

