import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// نافذة «اختيار فترة» موحّدة: ترويسة كحلية مثل إطار البرنامج،
/// وزر «حفظ» واضح (خط أبيض على خلفية أفتح قليلاً مع إطار أبيض).
///
/// (في الشكل الافتراضي كان زر الحفظ رمادياً باهتاً على كحلي فلا يُقرأ.)
Future<DateTimeRange?> pickDateRange(
  BuildContext context, {
  required DateTime firstDate,
  required DateTime lastDate,
  DateTimeRange? initial,
  String helpText = 'اختيار فترة',
}) => showDateRangePicker(
  context: context,
  firstDate: firstDate,
  lastDate: lastDate,
  initialDateRange: initial,
  initialEntryMode: DatePickerEntryMode.calendarOnly,
  helpText: helpText,
  saveText: 'حفظ',
  builder: (ctx, child) =>
      Theme(data: rangePickerTheme(Theme.of(ctx)), child: child!),
);

/// ثيم نافذة الفترة (مكشوف للاختبارات).
ThemeData rangePickerTheme(ThemeData base) {
  final baseStyle = base.textButtonTheme.style ?? const ButtonStyle();
  return base.copyWith(
    datePickerTheme: base.datePickerTheme.copyWith(
      rangePickerBackgroundColor: Colors.white,
      rangePickerHeaderBackgroundColor: AppColors.sidebar,
      rangePickerHeaderForegroundColor: Colors.white,
      rangeSelectionBackgroundColor: AppColors.navy.withValues(alpha: 0.12),
      dayBackgroundColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? AppColors.navy : null,
      ),
      dayForegroundColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Colors.white : null,
      ),
      todayForegroundColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Colors.white : AppColors.navy,
      ),
      todayBorder: const BorderSide(color: AppColors.navy),
    ),
    textButtonTheme: TextButtonThemeData(
      style: baseStyle.copyWith(
        // لون الخط يفرضه Flutter (= لون الترويسة الأبيض)؛ نضبط الخلفية
        // والإطار فقط حتى يظهر الزر بوضوح على الكحلي.
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.disabled)
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.white.withValues(alpha: 0.18),
        ),
        side: WidgetStateProperty.resolveWith(
          (s) => BorderSide(
            color: s.contains(WidgetState.disabled)
                ? Colors.white24
                : Colors.white70,
          ),
        ),
        minimumSize: const WidgetStatePropertyAll(Size(96, 40)),
      ),
    ),
  );
}

