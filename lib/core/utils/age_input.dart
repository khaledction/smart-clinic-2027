/// Accept Western, Arabic-Indic and Eastern Arabic digits, without inventing DOB.
String normalizeDigits(String value) {
  const western = '0123456789';
  const arabic = '٠١٢٣٤٥٦٧٨٩';
  const eastern = '۰۱۲۳۴۵۶۷۸۹';
  return value.trim().split('').map((c) {
    final a = arabic.indexOf(c);
    final e = eastern.indexOf(c);
    return a >= 0
        ? western[a]
        : e >= 0
        ? western[e]
        : c;
  }).join();
}

int? parseAge(String value) => int.tryParse(normalizeDigits(value));
String? validateAge(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  final normalized = normalizeDigits(value);
  final age = int.tryParse(normalized);
  if (!RegExp(r'^\d{1,3}$').hasMatch(normalized) ||
      age == null ||
      age < 0 ||
      age > 130) {
    return 'أدخل سنوات صحيحة بين 0 و130، أو اتركه فارغاً';
  }
  return null;
}

/// Optional numeric weight in kg; Arabic and Western decimal notation.
double? parseWeight(String value) => double.tryParse(
  normalizeDigits(value).replaceAll('٫', '.').replaceAll(',', '.'),
);
String? validateWeight(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  final n = parseWeight(value);
  if (n == null || !n.isFinite || n <= 0 || n > 700) {
    return 'أدخل وزناً رقمياً أكبر من صفر وحتى 700 كغ';
  }
  return null;
}

