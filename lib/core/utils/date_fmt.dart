import 'package:intl/intl.dart';

import 'age_input.dart';

/// تنسيق التواريخ بأرقام لاتينية: يوم/شهر/سنة، مثل 2/5/2023.
/// التخزين داخل SQLite يبقى yyyy-MM-dd عبر [isoDate].
class DateFmt {
  static final _d = DateFormat('d/M/yyyy');
  static final _dt = DateFormat('d/M/yyyy  HH:mm');
  static final _t = DateFormat('HH:mm');
  static final _monthName = DateFormat('MMMM yyyy', 'ar');

  static String date(DateTime d) => _d.format(d);
  static String dateTime(DateTime d) => _dt.format(d);
  static String time(DateTime d) => _t.format(d);
  static String monthName(DateTime d) => _monthName.format(d);

  static String? dateOrNull(DateTime? d) => d == null ? null : _d.format(d);

  /// 'yyyy-MM-dd' (صيغة التخزين داخل SQLite)
  static String isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static DateTime? parse(String? s) =>
      s == null || s.isEmpty ? null : DateTime.tryParse(s);

  /// يقرأ تاريخاً مكتوباً يوم/شهر/سنة بأرقام عربية أو لاتينية.
  /// يقبل رقماً أو رقمين لليوم والشهر، والفواصل / - . أو مسافة.
  static DateTime? parseInput(String? text) {
    if (text == null) return null;
    final t = normalizeDigits(text)
        .replaceAll(RegExp(r'[\s\-\.\\/،,٫؍]+'), '/');
    final m = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(t);
    if (m == null) return null;
    final day = int.parse(m[1]!);
    final month = int.parse(m[2]!);
    final year = int.parse(m[3]!);
    if (year < 1900 || year > 2100 || month < 1 || month > 12 || day < 1) {
      return null;
    }
    final result = DateTime(year, month, day);
    if (result.month != month || result.day != day) return null;
    return result;
  }

  /// عمر المريض بالسنوات
  static int? age(DateTime? birth) {
    if (birth == null) return null;
    final now = DateTime.now();
    var years = now.year - birth.year;
    if (now.month < birth.month ||
        (now.month == birth.month && now.day < birth.day)) {
      years--;
    }
    return years;
  }

  static String describe(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(d.year, d.month, d.day);
    final diff = target.difference(today).inDays;
    if (diff == 0) return 'اليوم';
    if (diff == 1) return 'غداً';
    if (diff == -1) return 'أمس';
    return date(d);
  }
}
