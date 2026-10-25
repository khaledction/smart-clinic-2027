import 'package:flutter/material.dart';

import 'app_colors.dart';

/// مقاسات موحّدة للأزرار ومربعات البحث والعناوين في كل الشاشات.
class AppSizes {
  AppSizes._();

  /// ارتفاع موحّد لمربعات البحث وكل الأزرار في البرنامج.
  static const double control = 40;

  /// ارتفاع كل الأزرار (الكحلية وزر الدفع الأخضر) — مقاس واحد في كل مكان.
  static const double button = control;

  /// الأزرار داخل الصفوف (تمت الزيارة / دفع) بالمقاس نفسه.
  static const double rowAction = button;

  /// انحناء زوايا موحّد للأزرار.
  static const double buttonRadius = 10;

  /// فجوة قياسية بين عنصرين متجاورين.
  static const double gap = 10;

  /// انحناء مربعات البحث (شكل كبسولة مميّز).
  static const double searchRadius = 22;

  /// زخرفة مربع البحث الموحّد: كبسولة بيضاء بحافة كحلية واضحة،
  /// وأيقونة بحث داخل دائرة كحلية، وحافة أعرض عند الكتابة.
  static InputDecoration search(
    String hint, {
    Widget? suffixIcon,
    bool prefix = true,
  }) {
    OutlineInputBorder border(Color c, double w) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(searchRadius),
      borderSide: BorderSide(color: c, width: w),
    );
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF8A97A8)),
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      prefixIcon: prefix
          ? Padding(
              padding: const EdgeInsetsDirectional.only(start: 6, end: 8),
              child: Container(
                key: const Key('searchIconChip'),
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: AppColors.navy,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.search, size: 17, color: Colors.white),
              ),
            )
          : null,
      prefixIconConstraints: const BoxConstraints(minWidth: 42, minHeight: 32),
      suffixIcon: suffixIcon,
      suffixIconConstraints: const BoxConstraints(minWidth: 38, minHeight: 38),
      border: border(AppColors.navy.withValues(alpha: 0.45), 1.4),
      enabledBorder: border(AppColors.navy.withValues(alpha: 0.45), 1.4),
      focusedBorder: border(AppColors.navy, 2),
    );
  }

  /// ظل خفيف يميّز مربع البحث عن باقي الحقول.
  static List<BoxShadow> get searchShadow => [
    BoxShadow(
      color: AppColors.navy.withValues(alpha: 0.10),
      blurRadius: 10,
      offset: const Offset(0, 3),
    ),
  ];
}
