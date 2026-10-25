import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/date_fmt.dart';
import '../../data/models/patient.dart';
import '../../data/models/visit.dart';
import '../../data/repositories/patient_repository.dart';
import '../../data/repositories/visit_repository.dart';

/// ترويسة الملف الطبي للمريض (الاسم، رقم الملف، الوزن، العمر، الجنس،
/// الهاتف، أول وآخر زيارة، الحساسية). تظهر نفسها في الملف الطبي وفي
/// نافذتي الفحوص والجلسات للتأكد أننا في ملف المريض الصحيح.
class PatientChartHeader extends StatelessWidget {
  const PatientChartHeader({
    super.key,
    required this.patient,
    required this.visits,
    this.actions = const [],
  });

  final Patient patient;

  /// زيارات المريض، الأحدث أولاً.
  final List<Visit> visits;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final p = patient;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 12,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircleAvatar(
                    radius: 26,
                    backgroundColor: Color(0xFFE2F1F4),
                    child: Icon(
                      Icons.person_outline,
                      color: AppColors.primaryDark,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 14),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.fullName,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            _identityTag(
                              'رقم الملف',
                              '${p.fileNo ?? p.id}',
                              numeric: true,
                            ),
                            _identityTag(
                              'الوزن',
                              p.weightKg?.toString() ?? 'غير محدد',
                              suffix: p.weightKg == null ? null : 'كغ',
                              numeric: p.weightKg != null,
                              tooltip: p.weightRecordedOn == null
                                  ? null
                                  : 'تاريخ القياس: ${DateFmt.date(p.weightRecordedOn!)}',
                            ),
                            _identityTag(
                              'العمر',
                              p.age == null ? 'غير محدد' : '${p.age}',
                              suffix: p.age == null ? null : 'سنة',
                              numeric: p.age != null,
                            ),
                            _identityTag('الجنس', p.genderLabel),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (actions.isNotEmpty)
                Wrap(spacing: 10, runSpacing: 8, children: actions),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 20,
            runSpacing: 8,
            children: [
              _meta(
                Icons.phone_outlined,
                p.phone?.isNotEmpty == true ? p.phone! : 'الهاتف غير محدد',
              ),
              _meta(
                Icons.history,
                'أول زيارة: ${visits.isEmpty ? "لا توجد" : DateFmt.date(visits.last.visitDate)}',
              ),
              _meta(
                Icons.event_available_outlined,
                'آخر زيارة: ${visits.isEmpty ? "لا توجد" : DateFmt.date(visits.first.visitDate)}',
              ),
              _meta(Icons.folder_outlined, '${visits.length} زيارة'),
              if (!p.isActive)
                _meta(
                  Icons.archive_outlined,
                  'ملف مؤرشف — استعد نشاطه قبل كشف جديد',
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: p.allergies?.trim().isNotEmpty == true
                  ? const Color(0xFFFFF0ED)
                  : const Color(0xFFF4F7FA),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'الحساسية: ${p.allergies?.trim().isNotEmpty == true ? p.allergies : "غير محددة — يلزم التحقق مع المريض"}',
              style: TextStyle(
                color: p.allergies?.trim().isNotEmpty == true
                    ? AppColors.danger
                    : AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _identityTag(
    String label,
    String value, {
    bool numeric = false,
    String? suffix,
    String? tooltip,
  }) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xFFF1F6FA),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Tooltip(
      message:
          tooltip ??
          (label == 'العمر' && patient.ageRecordedOn != null
              ? 'تاريخ توثيق العمر: ${DateFmt.date(patient.ageRecordedOn!)}'
              : label),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        textDirection: TextDirection.rtl,
        children: [
          Text(
            '$label:',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            textDirection: numeric ? TextDirection.ltr : TextDirection.rtl,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (suffix != null) ...[
            const SizedBox(width: 4),
            Text(suffix, style: const TextStyle(fontSize: 13)),
          ],
        ],
      ),
    ),
  );

  Widget _meta(IconData icon, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 16, color: AppColors.accent),
      const SizedBox(width: 6),
      Text(text, style: const TextStyle(fontSize: 12)),
    ],
  );
}

/// يحمّل المريض وزياراته ثم يعرض [PatientChartHeader] نفسها.
class PatientChartHeaderLoader extends StatefulWidget {
  const PatientChartHeaderLoader({super.key, required this.patientId});

  final int patientId;

  @override
  State<PatientChartHeaderLoader> createState() =>
      _PatientChartHeaderLoaderState();
}

class _PatientChartHeaderLoaderState extends State<PatientChartHeaderLoader> {
  late final Future<(Patient?, List<Visit>)> _data = _load();

  Future<(Patient?, List<Visit>)> _load() async {
    final patient = await PatientRepository().byId(widget.patientId);
    final visits = await VisitRepository().forPatient(widget.patientId);
    return (patient, visits);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<(Patient?, List<Visit>)>(
    future: _data,
    builder: (context, s) {
      if (s.hasError) {
        return const Padding(
          padding: EdgeInsets.all(12),
          child: Text('تعذّر تحميل بيانات المريض'),
        );
      }
      if (!s.hasData) return const LinearProgressIndicator();
      final (patient, visits) = s.data!;
      if (patient == null) {
        return const Padding(
          padding: EdgeInsets.all(12),
          child: Text('لم يُعثر على المريض'),
        );
      }
      return DecoratedBox(
        key: const Key('patientChartHeader'),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.frame)),
        ),
        child: PatientChartHeader(patient: patient, visits: visits),
      );
    },
  );
}

/// ملخص مختصر لأهم بيانات المريض أعلى النوافذ (مثل تفاصيل الجلسة):
/// الاسم، العمر، الوزن، زمرة الدم، أول زيارة (ورقم الملف والحساسية إن وجدت).
class PatientSummaryStrip extends StatelessWidget {
  const PatientSummaryStrip({
    super.key,
    required this.patient,
    required this.firstVisit,
  });

  final Patient patient;
  final DateTime? firstVisit;

  @override
  Widget build(BuildContext context) {
    final p = patient;
    final allergies = p.allergies?.trim() ?? '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F8FB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.frame),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            radius: 20,
            backgroundColor: Color(0xFFE2F1F4),
            child: Icon(Icons.person_outline, color: AppColors.primaryDark),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.fullName,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _summaryTag(
                      Icons.cake_outlined,
                      'العمر',
                      p.age == null ? 'غير محدد' : '${p.age} سنة',
                    ),
                    _summaryTag(
                      Icons.monitor_weight_outlined,
                      'الوزن',
                      p.weightKg == null
                          ? 'غير محدد'
                          : '${_num(p.weightKg!)} كغ',
                    ),
                    _summaryTag(
                      Icons.bloodtype_outlined,
                      'زمرة الدم',
                      p.bloodType?.trim().isNotEmpty == true
                          ? p.bloodType!
                          : 'غير محددة',
                      ltr: p.bloodType?.trim().isNotEmpty == true,
                    ),
                    _summaryTag(
                      Icons.history,
                      'أول زيارة',
                      firstVisit == null
                          ? 'لا توجد'
                          : DateFmt.date(firstVisit!),
                    ),
                    _summaryTag(
                      Icons.folder_outlined,
                      'رقم الملف',
                      '${p.fileNo ?? p.id}',
                      ltr: true,
                    ),
                    if (allergies.isNotEmpty)
                      _summaryTag(
                        Icons.warning_amber_rounded,
                        'الحساسية',
                        allergies,
                        danger: true,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _num(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toString();

Widget _summaryTag(
  IconData icon,
  String label,
  String value, {
  bool ltr = false,
  bool danger = false,
}) {
  final color = danger ? AppColors.danger : AppColors.textPrimary;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: danger ? const Color(0xFFFFF0ED) : Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: danger ? const Color(0xFFF5C6BD) : AppColors.frame,
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: danger ? AppColors.danger : AppColors.accent,
        ),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 13,
            color: danger ? AppColors.danger : AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          textDirection: ltr ? TextDirection.ltr : null,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    ),
  );
}

/// يحمّل المريض وأول زيارة ثم يعرض [PatientSummaryStrip].
class PatientSummaryLoader extends StatefulWidget {
  const PatientSummaryLoader({super.key, required this.patientId});

  final int patientId;

  @override
  State<PatientSummaryLoader> createState() => _PatientSummaryLoaderState();
}

class _PatientSummaryLoaderState extends State<PatientSummaryLoader> {
  late final Future<(Patient?, List<Visit>)> _data = () async {
    final patient = await PatientRepository().byId(widget.patientId);
    final visits = await VisitRepository().forPatient(widget.patientId);
    return (patient, visits);
  }();

  @override
  Widget build(BuildContext context) => FutureBuilder<(Patient?, List<Visit>)>(
    future: _data,
    builder: (context, s) {
      if (s.hasError) return const Text('تعذّر تحميل بيانات المريض');
      if (!s.hasData) return const LinearProgressIndicator();
      final (patient, visits) = s.data!;
      if (patient == null) return const Text('لم يُعثر على المريض');
      return KeyedSubtree(
        key: const Key('patientSummary'),
        child: PatientSummaryStrip(
          patient: patient,
          firstVisit: visits.isEmpty ? null : visits.last.visitDate,
        ),
      );
    },
  );
}
