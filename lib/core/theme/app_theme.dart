import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_sizes.dart';

/// سمة التطبيق: Material 3 بخط مقروء وأحجام مريحة لشاشة سطح المكتب.
class AppTheme {
  AppTheme._();

  static const String fontFamily = 'Cairo'; // غيّرها إلى Cairo إن أضفت الخط

  static const _buttonText = TextStyle(
    fontFamily: 'NotoSansArabic',
    fontSize: 13.5,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );
  static const _buttonPadding = EdgeInsets.symmetric(horizontal: 16);
  static final _buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
  );
  static const _navyDisabled = Color(0x5512314B);

  static ThemeData light() {
    const textColor = AppColors.textPrimary;
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      secondary: AppColors.accent,
      surface: AppColors.surface,
      error: AppColors.danger,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: AppColors.bg,
      visualDensity: VisualDensity.compact,
      textTheme: const TextTheme(
        displaySmall: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
        bodyLarge: TextStyle(fontSize: 14, color: textColor, height: 1.5),
        bodyMedium: TextStyle(
          fontSize: 13,
          color: AppColors.textSecondary,
          height: 1.5,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
      // مربعات الإدخال: حواف واضحة (لا تضيع داخل الأبيض) + عنوان عائم
      // بحجم مقروء + مسافة داخلية مريحة حتى لا تتداخل العناوين.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        isDense: false,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: AppColors.fieldBorder,
            width: 1.2,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: AppColors.fieldBorder,
            width: 1.2,
          ),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.navy, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.8),
        ),
        labelStyle: const TextStyle(
          fontSize: 13.5,
          color: AppColors.textSecondary,
        ),
        // العنوان العائم يُصغَّر تلقائياً (×0.75) ← نبدأ بحجم أكبر ليبقى مقروءاً.
        floatingLabelStyle: WidgetStateTextStyle.resolveWith(
          (s) => TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: s.contains(WidgetState.error)
                ? AppColors.danger
                : AppColors.navy,
          ),
        ),
        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF98A4B3)),
        helperStyle: const TextStyle(
          fontSize: 11.5,
          color: AppColors.textSecondary,
          height: 1.4,
        ),
        helperMaxLines: 2,
        errorMaxLines: 2,
      ),
      // النوافذ المنبثقة: خلفية بيضاء صافية (بدل الرمادي) وحواف مستديرة.
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        titleTextStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 19,
          fontWeight: FontWeight.w700,
          color: AppColors.navy,
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      ),
      // كل الأزرار: كحلي القائمة الجانبية + خط أبيض + مقاس وشكل واحد.
      // (زر الدفع وحده أخضر — انظر PayToggle.)
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.navy,
          foregroundColor: Colors.white,
          iconColor: Colors.white,
          disabledBackgroundColor: _navyDisabled,
          disabledForegroundColor: Colors.white,
          disabledIconColor: Colors.white,
          minimumSize: const Size(0, AppSizes.button),
          // مقاس ثابت حتى مع الكثافة المدمجة لسطح المكتب.
          visualDensity: VisualDensity.standard,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: _buttonPadding,
          shape: _buttonShape,
          textStyle: _buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.navy,
          foregroundColor: Colors.white,
          iconColor: Colors.white,
          disabledBackgroundColor: _navyDisabled,
          disabledForegroundColor: Colors.white,
          disabledIconColor: Colors.white,
          minimumSize: const Size(0, AppSizes.button),
          // مقاس ثابت حتى مع الكثافة المدمجة لسطح المكتب.
          visualDensity: VisualDensity.standard,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: _buttonPadding,
          side: const BorderSide(color: AppColors.navy),
          shape: _buttonShape,
          textStyle: _buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          backgroundColor: AppColors.navy,
          foregroundColor: Colors.white,
          iconColor: Colors.white,
          disabledBackgroundColor: _navyDisabled,
          disabledForegroundColor: Colors.white,
          disabledIconColor: Colors.white,
          minimumSize: const Size(0, AppSizes.button),
          // مقاس ثابت حتى مع الكثافة المدمجة لسطح المكتب.
          visualDensity: VisualDensity.standard,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: _buttonPadding,
          shape: _buttonShape,
          textStyle: _buttonText,
        ),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          // إطار كحلي نحيف وهادئ حول كل نافذة في البرنامج.
          side: BorderSide(color: AppColors.frame),
        ),
      ),
      // لون أزرار موحّد = كحلي القائمة الجانبية.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.navy,
          foregroundColor: Colors.white,
          iconColor: Colors.white,
          disabledBackgroundColor: _navyDisabled,
          disabledForegroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(0, AppSizes.button),
          // مقاس ثابت حتى مع الكثافة المدمجة لسطح المكتب.
          visualDensity: VisualDensity.standard,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: _buttonPadding,
          shape: _buttonShape,
          textStyle: _buttonText,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: AppColors.navy),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? AppColors.navy
                : Colors.white,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? Colors.white
                : AppColors.navy,
          ),
          iconColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? Colors.white
                : AppColors.navy,
          ),
          side: const WidgetStatePropertyAll(
            BorderSide(color: AppColors.frame),
          ),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(
              fontFamily: 'NotoSansArabic',
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      chipTheme: const ChipThemeData(
        selectedColor: Color(0x2212314B),
        checkmarkColor: AppColors.navy,
        side: BorderSide(color: AppColors.frame),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStateProperty.all(const Color(0xFFF0F3F7)),
        dataRowColor: WidgetStateProperty.all(Colors.white),
        headingTextStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        dataTextStyle: const TextStyle(
          fontSize: 13,
          color: AppColors.textPrimary,
        ),
        dividerThickness: 0.6,
        columnSpacing: 28,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

