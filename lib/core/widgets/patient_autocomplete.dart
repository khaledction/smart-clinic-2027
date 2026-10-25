import 'package:flutter/material.dart';

import '../../data/models/patient.dart';
import '../theme/app_colors.dart';
import '../theme/app_sizes.dart';

/// مربع بحث عن مريض مع إكمال تلقائي (بالاسم أو رقم الملف أو الهاتف).
/// يُستدعى [onSelected] عند اختيار مريض، وبـ null عند تعديل النص بعد الاختيار.
class PatientAutocomplete extends StatefulWidget {
  const PatientAutocomplete({
    super.key,
    required this.patients,
    required this.onSelected,
    this.autofocus = true,
    this.hint = 'اكتب اسم المريض أو رقم الملف أو الهاتف…',
    this.fieldKey = const Key('patientAutocomplete'),
    this.compact = false,
  });

  final List<Patient> patients;
  final ValueChanged<Patient?> onSelected;
  final bool autofocus;
  final String hint;

  /// مفتاح حقل النص (لتمييز أكثر من مربع بحث في الشاشة نفسها).
  final Key fieldKey;

  /// حقل أقصر ارتفاعاً لأشرطة الأدوات (بجانب الأزرار).
  final bool compact;

  /// مطابقة بسيطة: كل كلمة مكتوبة يجب أن تظهر في الاسم أو الملف أو الهاتف.
  static bool matches(Patient p, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    final hay = [
      p.fullName,
      p.fileNo ?? '',
      p.phone ?? '',
      p.phoneAlt ?? '',
    ].join(' ').toLowerCase();
    return q.split(RegExp(r'\s+')).every(hay.contains);
  }

  @override
  State<PatientAutocomplete> createState() => _PatientAutocompleteState();
}

class _PatientAutocompleteState extends State<PatientAutocomplete> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  Patient? _picked;

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  String _label(Patient p) => p.fullName;

  @override
  Widget build(BuildContext context) => RawAutocomplete<Patient>(
    textEditingController: _controller,
    focusNode: _focus,
    displayStringForOption: _label,
    optionsBuilder: (value) {
      final list = widget.patients
          .where((p) => PatientAutocomplete.matches(p, value.text))
          .take(30);
      return list;
    },
    onSelected: (p) {
      setState(() => _picked = p);
      widget.onSelected(p);
    },
    fieldViewBuilder: (context, controller, focus, onSubmit) => Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSizes.searchRadius),
        boxShadow: AppSizes.searchShadow,
      ),
      child: TextField(
        key: widget.fieldKey,
        controller: controller,
        focusNode: focus,
        autofocus: widget.autofocus,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        onChanged: (_) {
          if (_picked != null) {
            setState(() => _picked = null);
            widget.onSelected(null);
          }
        },
        onSubmitted: (_) => onSubmit(),
        decoration:
            AppSizes.search(
              widget.hint,
              suffixIcon: _picked != null
                  ? const Icon(
                      Icons.check_circle,
                      color: AppColors.success,
                      size: 20,
                    )
                  : null,
            ).copyWith(
              isDense: widget.compact ? true : null,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 14,
                vertical: widget.compact ? 11 : 13,
              ),
            ),
      ),
    ),
    optionsViewBuilder: (context, onSelected, options) {
      final list = options.toList();
      return Align(
        alignment: AlignmentDirectional.topStart,
        child: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Material(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.fieldBorder),
            ),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: list.isEmpty
                  ? const SizedBox.shrink()
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      shrinkWrap: true,
                      itemCount: list.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, color: AppColors.divider),
                      itemBuilder: (context, i) {
                        final p = list[i];
                        final highlighted =
                            AutocompleteHighlightedOption.of(context) == i;
                        return InkWell(
                          key: Key('patientOption:${p.id}'),
                          onTap: () => onSelected(p),
                          child: Container(
                            color: highlighted
                                ? AppColors.cardTint
                                : Colors.transparent,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 9,
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.person_outline,
                                  size: 18,
                                  color: AppColors.navy,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    p.fullName,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Text(
                                  [
                                    if (p.fileNo?.isNotEmpty == true)
                                      'ملف ${p.fileNo}',
                                    if (p.phone?.isNotEmpty == true) p.phone!,
                                  ].join('  •  '),
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ),
      );
    },
  );
}
