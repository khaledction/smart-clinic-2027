import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_colors.dart';
import 'date_input.dart';

/// حقل نصي موحّد، مع دعم التحقق.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.initialValue,
    this.maxLines = 1,
    this.minLines,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.enabled = true,
    this.suffix,
    this.onChanged,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? initialValue;
  final int maxLines;
  final int? minLines;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool enabled;
  final Widget? suffix;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      initialValue: controller == null ? initialValue : null,
      maxLines: maxLines,
      minLines: minLines,
      enabled: enabled,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      validator: validator,
      onChanged: onChanged,
      style: Theme.of(context).textTheme.bodyLarge,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        alignLabelWithHint: maxLines > 1,
        suffixIcon: suffix,
      ),
    );
  }
}

/// قائمة منسدلة موحّدة.
class AppDropdownField<T> extends StatelessWidget {
  const AppDropdownField({
    super.key,
    required this.label,
    required this.items,
    this.value,
    this.onChanged,
    this.validator,
    this.enabled = true,
  });

  final String label;
  final List<DropdownMenuItem<T>> items;
  final T? value;
  final ValueChanged<T?>? onChanged;
  final String? Function(T?)? validator;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      items: items,
      onChanged: enabled ? onChanged : null,
      validator: validator,
      isExpanded: true,
      style: Theme.of(context).textTheme.bodyLarge,
      decoration: InputDecoration(labelText: label),
      borderRadius: BorderRadius.circular(10),
      menuMaxHeight: 320,
      icon: const Icon(Icons.keyboard_arrow_down_rounded),
    );
  }
}

/// حقل تاريخ يُكتب يوم/شهر/سنة (مثل 2/5/2023) مع زر تقويم.
class AppDateField extends StatelessWidget {
  const AppDateField({
    super.key,
    required this.label,
    this.value,
    this.onChanged,
    this.firstDate,
    this.lastDate,
    this.required = false,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?>? onChanged;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final bool required;

  @override
  Widget build(BuildContext context) => DateInputField(
    label: label,
    value: value,
    onChanged: onChanged,
    firstDate: firstDate,
    lastDate: lastDate,
    required: required,
  );
}

/// حقل وقت (ساعة:دقيقة).
class AppTimeField extends StatelessWidget {
  const AppTimeField({
    super.key,
    required this.label,
    this.value,
    this.onChanged,
  });

  final String label;
  final TimeOfDay? value;
  final ValueChanged<TimeOfDay?>? onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: value ?? const TimeOfDay(hour: 9, minute: 0),
          builder: (context, child) =>
              Theme(data: Theme.of(context), child: child!),
        );
        onChanged?.call(picked);
      },
      borderRadius: BorderRadius.circular(10),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.schedule_outlined, size: 18),
        ),
        child: Text(
          value == null ? '—' : value!.format(context),
          style: TextStyle(
            fontSize: 14,
            color: value == null
                ? AppColors.textSecondary
                : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

/// حقل رقمي مع تحويل تلقائي.
class AppNumberField extends StatelessWidget {
  const AppNumberField({
    super.key,
    this.controller,
    this.label,
    this.initialValue,
    this.validator,
    this.isDouble = false,
    this.enabled = true,
  });

  final TextEditingController? controller;
  final String? label;
  final String? initialValue;
  final String? Function(String?)? validator;
  final bool isDouble;
  final bool enabled;

  static final _int = NumberFormat('#,##0', 'en_US');

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      initialValue: controller == null ? initialValue : null,
      enabled: enabled,
      keyboardType: TextInputType.numberWithOptions(decimal: isDouble),
      validator: validator,
      style: Theme.of(context).textTheme.bodyLarge,
      decoration: InputDecoration(labelText: label),
    );
  }

  static String? format(num? v) => v == null ? null : _int.format(v);
}
