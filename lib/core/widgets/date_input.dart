import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/age_input.dart';
import '../utils/date_fmt.dart';

/// يرتّب ما يُكتب في حقل التاريخ: يوم/شهر/سنة.
/// • يحوّل الأرقام العربية ٠-٩ إلى لاتينية.
/// • يحوّل الفواصل (- . مسافة) إلى /.
/// • يضيف / تلقائياً بعد يوم أو شهر من رقمين عند متابعة الكتابة.
class DateInputFormatter extends TextInputFormatter {
  const DateInputFormatter();

  static String format(String raw) {
    final text = normalizeDigits(raw);
    final segments = <StringBuffer>[StringBuffer()];
    for (final ch in text.split('')) {
      final isDigit = ch.codeUnitAt(0) >= 48 && ch.codeUnitAt(0) <= 57;
      final isSep = RegExp(r'[\s\-\.\\/،,٫؍]').hasMatch(ch);
      if (isDigit) {
        final current = segments.last;
        final index = segments.length - 1;
        if (index < 2 && current.length == 2) {
          segments.add(StringBuffer(ch));
        } else if (index == 2 && current.length == 4) {
          continue;
        } else {
          current.write(ch);
        }
      } else if (isSep) {
        if (segments.last.isNotEmpty && segments.length < 3) {
          segments.add(StringBuffer());
        }
      }
    }
    final out = StringBuffer(segments.first.toString());
    for (final s in segments.skip(1)) {
      out
        ..write('/')
        ..write(s.toString());
    }
    return out.toString();
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final formatted = format(newValue.text);
    if (formatted == newValue.text) return newValue;
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// حقل تاريخ يُكتب يدوياً بترتيب ثابت يوم/شهر/سنة (مثل 2/5/2023)،
/// مع زر تقويم. اتجاه الكتابة داخل الحقل ثابت فلا تتبدل الأرقام أثناء الإدخال.
class DateInputField extends StatefulWidget {
  const DateInputField({
    super.key,
    required this.label,
    this.value,
    this.onChanged,
    this.firstDate,
    this.lastDate,
    this.required = false,
    this.enabled = true,
    this.fieldKey,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?>? onChanged;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final bool required;
  final bool enabled;

  /// مفتاح اختياري لحقل النص نفسه (للاختبارات).
  final Key? fieldKey;

  @override
  State<DateInputField> createState() => _DateInputFieldState();
}

class _DateInputFieldState extends State<DateInputField> {
  late final TextEditingController _text = TextEditingController(
    text: widget.value == null ? '' : DateFmt.date(widget.value!),
  );

  DateTime get _first => widget.firstDate ?? DateTime(1920);
  DateTime get _last => widget.lastDate ?? DateTime(DateTime.now().year + 20);

  static bool _sameDay(DateTime? a, DateTime? b) => a == null || b == null
      ? a == b
      : a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  void didUpdateWidget(covariant DateInputField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final current = DateFmt.parseInput(_text.text);
    if (!_sameDay(widget.value, oldWidget.value) &&
        !_sameDay(widget.value, current)) {
      _text.text = widget.value == null ? '' : DateFmt.date(widget.value!);
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  bool _inRange(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    final first = DateTime(_first.year, _first.month, _first.day);
    final last = DateTime(_last.year, _last.month, _last.day);
    return !day.isBefore(first) && !day.isAfter(last);
  }

  String? _validate(String? text) {
    final t = text?.trim() ?? '';
    if (t.isEmpty) return widget.required ? 'أدخل التاريخ' : null;
    final d = DateFmt.parseInput(t);
    if (d == null) return 'اكتب التاريخ يوم/شهر/سنة مثل 2/5/2023';
    if (!_inRange(d)) return 'التاريخ خارج المجال المسموح';
    return null;
  }

  void _changed(String text) {
    if (text.trim().isEmpty) {
      widget.onChanged?.call(null);
      return;
    }
    final d = DateFmt.parseInput(text);
    if (d != null && _inRange(d)) widget.onChanged?.call(d);
  }

  Future<void> _pick() async {
    final picked = await showAppDatePicker(
      context,
      initialDate: DateFmt.parseInput(_text.text) ?? widget.value,
      firstDate: _first,
      lastDate: _last,
      helpText: widget.label,
    );
    if (picked == null || !mounted) return;
    setState(() => _text.text = DateFmt.date(picked));
    widget.onChanged?.call(picked);
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: widget.fieldKey,
      controller: _text,
      enabled: widget.enabled,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.right,
      keyboardType: TextInputType.datetime,
      maxLength: 10,
      inputFormatters: const [DateInputFormatter()],
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: _validate,
      onChanged: _changed,
      style: Theme.of(context).textTheme.bodyLarge,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: '2/5/2023',
        counterText: '',
        suffixIcon: IconButton(
          tooltip: 'التقويم',
          icon: const Icon(Icons.calendar_month_outlined, size: 18),
          onPressed: widget.enabled ? _pick : null,
        ),
      ),
    );
  }
}

/// نافذة اختيار تاريخ موحّدة: حقل كتابة يوم/شهر/سنة فوق تقويم شهري.
/// تُستخدم بدل منتقي Material الافتراضي حتى يبقى الإدخال بصيغة واحدة.
Future<DateTime?> showAppDatePicker(
  BuildContext context, {
  DateTime? initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  String? helpText,
}) {
  DateTime clamp(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    if (day.isBefore(firstDate)) return firstDate;
    if (day.isAfter(lastDate)) return lastDate;
    return day;
  }

  var current = clamp(initialDate ?? DateTime.now());
  return showDialog<DateTime>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, update) => AlertDialog(
        title: Text(helpText ?? 'اختيار التاريخ'),
        content: SizedBox(
          width: 340,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _PlainDateField(
                  value: current,
                  firstDate: firstDate,
                  lastDate: lastDate,
                  onChanged: (d) => update(() => current = d),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 300,
                  child: CalendarDatePicker(
                    key: ValueKey(DateFmt.isoDate(current)),
                    initialDate: current,
                    firstDate: firstDate,
                    lastDate: lastDate,
                    onDateChanged: (d) => update(() => current = d),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, current),
            child: const Text('اختيار'),
          ),
        ],
      ),
    ),
  );
}

/// حقل الكتابة داخل نافذة التقويم (دون زر تقويم ثانٍ).
class _PlainDateField extends StatefulWidget {
  const _PlainDateField({
    required this.value,
    required this.firstDate,
    required this.lastDate,
    required this.onChanged,
  });

  final DateTime value;
  final DateTime firstDate;
  final DateTime lastDate;
  final ValueChanged<DateTime> onChanged;

  @override
  State<_PlainDateField> createState() => _PlainDateFieldState();
}

class _PlainDateFieldState extends State<_PlainDateField> {
  late final TextEditingController _text = TextEditingController(
    text: DateFmt.date(widget.value),
  );

  @override
  void didUpdateWidget(covariant _PlainDateField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final typed = DateFmt.parseInput(_text.text);
    if (typed == null ||
        DateFmt.isoDate(typed) != DateFmt.isoDate(widget.value)) {
      if (DateFmt.isoDate(oldWidget.value) != DateFmt.isoDate(widget.value)) {
        _text.text = DateFmt.date(widget.value);
      }
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _text,
      autofocus: true,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.right,
      keyboardType: TextInputType.datetime,
      maxLength: 10,
      inputFormatters: const [DateInputFormatter()],
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: (t) {
        final d = DateFmt.parseInput(t);
        if (d == null) return 'اكتب التاريخ يوم/شهر/سنة مثل 2/5/2023';
        if (d.isBefore(widget.firstDate) || d.isAfter(widget.lastDate)) {
          return 'التاريخ خارج المجال المسموح';
        }
        return null;
      },
      onChanged: (t) {
        final d = DateFmt.parseInput(t);
        if (d != null &&
            !d.isBefore(widget.firstDate) &&
            !d.isAfter(widget.lastDate)) {
          widget.onChanged(d);
        }
      },
      decoration: const InputDecoration(
        labelText: 'اكتب التاريخ (يوم/شهر/سنة)',
        hintText: '2/5/2023',
        counterText: '',
      ),
    );
  }
}
