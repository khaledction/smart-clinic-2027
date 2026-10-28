import '../../core/widgets/patient_link.dart';
import '../../core/widgets/day_groups.dart';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_sizes.dart';
import '../../core/utils/date_fmt.dart';
import '../../core/utils/neuro_constants.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/section_card.dart';
import '../../data/models/patient.dart';
import '../../data/models/visit.dart';
import '../../data/repositories/patient_repository.dart';
import '../../data/repositories/visit_repository.dart';
import 'visit_form_screen.dart';
import 'visit_detail_screen.dart';
import '../../core/widgets/patient_autocomplete.dart';

/// سجل الزيارات في العيادة كلها + زر زيارة جديدة.
class VisitsScreen extends StatefulWidget {
  const VisitsScreen({super.key});

  @override
  State<VisitsScreen> createState() => _VisitsScreenState();
}

class _VisitsScreenState extends State<VisitsScreen> {
  final _visitsRepo = VisitRepository();
  final _patientRepo = PatientRepository();

  List<Visit> _visits = [];
  List<Patient> _patients = [];
  int? _filterPatientId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      _visitsRepo.recent(limit: 200),
      _patientRepo.search(query: '', limit: 500),
    ]);
    if (!mounted || !context.mounted) return;
    setState(() {
      _visits = results[0] as List<Visit>;
      _patients = results[1] as List<Patient>;
      _loading = false;
    });
  }

  Future<void> _openNewVisit() async {
    final result = await showDialog<_NewVisitChoice>(
      context: context,
      builder: (ctx) {
        Patient? selected;
        void open() {
          if (selected == null) return;
          Navigator.pop(
            ctx,
            _NewVisitChoice(selected!.id!, selected!.fullName),
          );
        }

        return StatefulBuilder(
          builder: (ctx, setD) => AlertDialog(
            title: const Text('زيارة جديدة'),
            content: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'ابحث عن المريض ثم اختره من القائمة:',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  PatientAutocomplete(
                    patients: _patients,
                    onSelected: (p) => setD(() => selected = p),
                  ),
                  // مساحة لقائمة الاقتراحات أسفل المربع.
                  const SizedBox(height: 8),
                  if (selected != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'المريض المختار: ${selected!.fullName}'
                        '${selected!.fileNo?.isNotEmpty == true ? '  •  ملف ${selected!.fileNo}' : ''}',
                        key: const Key('newVisitPicked'),
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                key: const Key('newVisitOpen'),
                onPressed: selected == null ? null : open,
                child: const Text('فتح الاستمارة'),
              ),
            ],
          ),
        );
      },
    );

    if (result == null || !mounted) return;
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => VisitFormScreen(
          patientId: result.patientId,
          patientName: result.patientName,
        ),
      ),
    );
    if (changed == true && mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filterPatientId == null
        ? _visits
        : _visits.where((v) => v.patientId == _filterPatientId).toList();

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: SectionCard(
          padding: const EdgeInsets.all(0),
          title: 'سجل الزيارات (${filtered.length})',
          icon: Icons.medical_information_outlined,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // مربع البحث وزر «زيارة جديدة» بالمقاس نفسه تماماً ومتحاذيان.
              SizedBox(
                width: _toolWidth,
                height: AppSizes.control,
                // بحث بالإكمال التلقائي أثناء الكتابة (الاسم أو رقم الملف أو
                // الهاتف). تعديل النص بعد الاختيار يعيد عرض كل الزيارات.
                child: PatientAutocomplete(
                  key: const Key('visitsSearchBox'),
                  fieldKey: const Key('visitsSearch'),
                  patients: _patients,
                  autofocus: false,
                  compact: true,
                  hint: 'ابحث عن مريض…',
                  onSelected: (p) => setState(() => _filterPatientId = p?.id),
                ),
              ),
              const SizedBox(width: AppSizes.gap),
              SizedBox(
                width: _toolWidth,
                height: AppSizes.control,
                child: FilledButton.icon(
                  key: const Key('newVisit'),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _openNewVisit,
                  icon: const Icon(Icons.add_circle_outline, size: 19),
                  label: const Text(
                    'زيارة جديدة',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          child: _loading
              ? const SizedBox(
                  height: 260,
                  child: Center(child: CircularProgressIndicator()),
                )
              : filtered.isEmpty
              ? const EmptyState(
                  message: 'لا توجد زيارات',
                  icon: Icons.medical_information_outlined,
                )
              : DayGroups<Visit>(
                  items: filtered,
                  dateOf: (v) => v.visitDate,
                  noun: 'زيارة',
                  searching: _filterPatientId != null,
                  groupBuilder: (dayVisits) => SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: MediaQuery.of(context).size.width - 260,
                      ),
                      child: DataTable(
                        showCheckboxColumn: false,
                        columns: const [
                          DataColumn(label: Text('التاريخ')),
                          DataColumn(label: Text('المريض')),
                          DataColumn(label: Text('النوع')),
                          DataColumn(label: Text('الشكوى الرئيسية')),
                          DataColumn(label: Text('التشخيص')),
                          DataColumn(label: Text('ICD-10')),
                        ],
                        rows: dayVisits.map((v) {
                          return DataRow(
                            onSelectChanged: (_) => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    VisitDetailScreen(visitId: v.id!),
                              ),
                            ),
                            cells: [
                              DataCell(Text(DateFmt.date(v.visitDate))),
                              DataCell(
                                PatientLink(
                                  patientId: v.patientId,
                                  name: v.patientName ?? '—',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              DataCell(_VisitTypeChip(visit: v)),
                              DataCell(
                                SizedBox(
                                  width: 260,
                                  child: Text(
                                    v.chiefComplaint ?? '—',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: 220,
                                  child: Text(
                                    v.diagnosis ?? '—',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              DataCell(Text(v.icd10 ?? '—')),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

/// عرض موحّد لمربع المرضى وزر «زيارة جديدة».
const double _toolWidth = 240;

/// شارة نوع الزيارة: المعاينات بالأزرق، والجلسات بالتركوازي
/// (نفس ألوان لوحة اليوم والمواعيد والمالية). الأنواع القديمة الأخرى
/// (مثل «إجراء») تبقى رمادية كما سُجّلت دون إعادة تصنيف.
class _VisitTypeChip extends StatelessWidget {
  const _VisitTypeChip({required this.visit});

  final Visit visit;

  static const _checkupTypes = {'first', 'new', 'followup', 'emergency'};

  @override
  Widget build(BuildContext context) {
    final v = visit;
    final isSession = v.visitType == 'session';
    final isCheckup = _checkupTypes.contains(v.visitType);
    final color = isSession
        ? AppColors.accent
        : isCheckup
        ? AppColors.primary
        : AppColors.textSecondary;
    final icon = isSession
        ? Icons.bolt_outlined
        : isCheckup
        ? Icons.medical_services_outlined
        : Icons.history;
    final label =
        (isSession ? v.sessionName : null) ??
        NeuroConstants.visitTypes[v.visitType] ??
        v.visitType;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isSession ? 0.14 : 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _NewVisitChoice {
  const _NewVisitChoice(this.patientId, this.patientName);

  final int patientId;
  final String patientName;
}

