import '../../core/printing/clinic_print.dart';
import '../../data/repositories/treatment_repository.dart';
import '../sessions/sessions_screen.dart';
import '../investigations/investigations_screen.dart';
import '../../core/widgets/patient_link.dart';

import 'package:flutter/material.dart';

import '../../core/widgets/paid_widgets.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/date_fmt.dart';
import '../../core/utils/neuro_constants.dart';
import '../../data/models/visit.dart';
import '../../data/repositories/visit_repository.dart';
import '../../data/repositories/plan_repository.dart';
import '../../core/widgets/clinic_brand.dart';

/// Read-only, sectioned encounter view. Original clinical values are preserved.
class VisitDetailScreen extends StatefulWidget {
  const VisitDetailScreen({super.key, required this.visitId});
  final int visitId;
  @override
  State<VisitDetailScreen> createState() => _VisitDetailScreenState();
}

class _VisitDetailScreenState extends State<VisitDetailScreen> {
  late Future<Visit?> _record = VisitRepository().full(widget.visitId);
  Future<void> _action(Future<void> Function() action) async {
    try {
      await action();
      if (mounted) {
        setState(() {
          _record = VisitRepository().full(widget.visitId);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  /// يسجّل أجر المعاينة مباشرة بسعر الإعدادات. التكرار ممنوع.
  Future<bool> _pay() async {
    try {
      await TreatmentRepository().payVisit(widget.visitId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('سُجّل أجر المعاينة في مالية المعاينات'),
            backgroundColor: AppColors.success,
          ),
        );
        setState(() {
          _record = VisitRepository().full(widget.visitId);
        });
      }
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e is StateError ? e.message : e.toString()),
            backgroundColor: AppColors.danger,
          ),
        );
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF2F6FA),
    appBar: const BrandedAppBar(title: Text('تفاصيل الزيارة')),
    body: FutureBuilder<Visit?>(
      future: _record,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('تعذّر تحميل الزيارة'),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _record = VisitRepository().full(widget.visitId);
                    });
                  },
                  child: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final v = snapshot.data;
        if (v == null) return const Center(child: Text('الزيارة غير موجودة'));
        final exam = v.exam;
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1240),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF113E59),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'السجل الطبي / تفاصيل الزيارة',
                        style: TextStyle(
                          color: Color(0xFFB9DBE8),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      PatientLink(
                        patientId: v.patientId,
                        name: v.patientName ?? 'المريض',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 25,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 10,
                        children: [
                          _badge(
                            Icons.event_outlined,
                            DateFmt.date(v.visitDate),
                            ltr: true,
                          ),
                          _badge(
                            Icons.medical_services_outlined,
                            NeuroConstants.visitTypes[v.visitType] ??
                                v.visitType,
                          ),
                          if (v.patientAgeYears != null)
                            Tooltip(
                              message:
                                  'تاريخ توثيق العمر: ${v.patientAgeRecordedOn ?? "غير محدد"}',
                              child: _badge(
                                Icons.person_outline,
                                'العمر: ${v.patientAgeYears} سنة',
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        onPressed: () =>
                            requestTreatment(context, v.patientId, v.id!),
                        icon: const Icon(Icons.spa_outlined),
                        label: const Text('طلب جلسات / إجراء'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => InvestigationsScreen(
                              patientId: v.patientId,
                              sourceVisitId: v.id,
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.biotech),
                        label: const Text('الفحوص والنتائج'),
                      ),
                      OutlinedButton.icon(
                        onPressed: v.prescriptions.isEmpty
                            ? null
                            : () => ClinicPrint.preview(
                                context,
                                'معاينة الوصفة',
                                ClinicPrint.prescription(v),
                              ),
                        icon: const Icon(Icons.print),
                        label: const Text('طباعة الوصفة'),
                      ),
                      OutlinedButton(
                        onPressed: v.completedAt != null
                            ? null
                            : () => _action(
                                () =>
                                    TreatmentRepository().completeVisit(v.id!),
                              ),
                        child: Text(
                          v.completedAt != null
                              ? 'الزيارة منتهية'
                              : 'إنهاء الزيارة',
                        ),
                      ),
                      if (v.visitType != 'session')
                        FutureBuilder<bool>(
                          future: TreatmentRepository().visitPaid(v.id!),
                          builder: (context, s) => PayToggle(
                            key: ValueKey('pay-v${v.id}'),
                            paid: s.data == true,
                            enabled: s.hasData,
                            tooltip: 'دفع أجر المعاينة',
                            onPay: _pay,
                          ),
                        ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'إنهاء الزيارة لا ينهي الجلسات أو الفحوص المعلقة، ولا يسجل دفعة.',
                  ),
                ),
                _PlanActionsCard(visitId: v.id!, patientId: v.patientId),
                if (v.patientWeightKg != null)
                  Text('الوزن عند الزيارة: ${v.patientWeightKg} كغ'),
                const SizedBox(height: 20),
                _section('الشكوى والتقييم', Icons.assignment_outlined, [
                  if (v.visitType == 'session')
                    _field('نوع الجلسة', v.sessionName),
                  _field('الشكوى الرئيسية', v.chiefComplaint),
                  _field('بداية الأعراض ومدتها', v.onsetDuration),
                  _field('التشخيص', v.diagnosis),
                  if (v.icd10?.isNotEmpty == true)
                    _field('رمز التشخيص ICD', v.icd10),
                ]),
                const SizedBox(height: 18),
                _section('الفحص العصبي', Icons.psychology_outlined, [
                  if (exam == null)
                    const Text(
                      'لا توجد تفاصيل فحص لهذه الزيارة. هذا لا يعني أن النتيجة طبيعية.',
                    )
                  else
                    LayoutBuilder(
                      builder: (context, c) {
                        final fields = <String, Object?>{
                          'الوعي': exam.consciousness,
                          'GCS': exam.gcs,
                          'التوجّه': exam.orientation,
                          'الكلام واللغة': exam.speech,
                          'الأعصاب القحفية': exam.cranialNerves,
                          'القوة العضلية': exam.motorPower,
                          'التوتر العضلي': exam.tone,
                          'المنعكسات': exam.reflexes,
                          'الإحساس': exam.sensation,
                          'التناسق': exam.coordination,
                          'المشية': exam.gait,
                          'العلامات السحائية': exam.meningeal,
                          'موجودات أخرى': exam.findings,
                        };
                        return Wrap(
                          spacing: 14,
                          runSpacing: 12,
                          children: [
                            for (final entry in fields.entries)
                              SizedBox(
                                width: c.maxWidth > 700
                                    ? (c.maxWidth - 14) / 2
                                    : c.maxWidth,
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF4F8FB),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: _field(
                                    entry.key,
                                    entry.value?.toString(),
                                    missing: 'لم يُوثّق',
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                ]),
                if (v.scales.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  _section('المقاييس', Icons.speed_outlined, [
                    Wrap(
                      spacing: 14,
                      runSpacing: 12,
                      children: [
                        for (final s in v.scales)
                          Container(
                            width: 260,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEAF5F6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.scale,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  '${s.score} / ${s.maxScore ?? "—"}',
                                  textDirection: TextDirection.ltr,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                                if (s.notes?.isNotEmpty == true)
                                  SelectableText(s.notes!),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ]),
                ],
                const SizedBox(height: 18),
                _section('الخطة والمراجعة', Icons.fact_check_outlined, [
                  _field('الخطة العلاجية', v.plan),
                  if (v.followUpDate != null)
                    _field(
                      'المراجعة الموصى بها في هذه الزيارة',
                      DateFmt.date(v.followUpDate!),
                    ),
                  _field('ملاحظات إضافية', v.notes),
                ]),
                const SizedBox(height: 18),
                _section('الوصفة الطبية', Icons.medication_outlined, [
                  if (v.prescriptions.isEmpty)
                    const Text('لا توجد أدوية في وصفة هذه الزيارة'),
                  for (final entry in v.prescriptions.asMap().entries)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.divider),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            '${entry.key + 1}. ${entry.value.drug}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryDark,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 30,
                            runSpacing: 12,
                            children: [
                              _field('الجرعة', entry.value.dose),
                              _field('التكرار', entry.value.frequency),
                              _field(
                                'المدة',
                                entry.value.durationDays == null
                                    ? null
                                    : '${entry.value.durationDays} يوم',
                              ),
                            ],
                          ),
                          if (entry.value.notes?.isNotEmpty == true)
                            _field('تعليمات', entry.value.notes),
                        ],
                      ),
                    ),
                ]),
                const SizedBox(height: 14),
                const Text(
                  'عرض للقراءة فقط • بيانات الزيارة الأصلية محفوظة',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
  Widget _badge(IconData icon, String label, {bool ltr = false}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: const Color(0xFF96D9DC), size: 18),
        const SizedBox(width: 8),
        Text(
          label,
          textDirection: ltr ? TextDirection.ltr : TextDirection.rtl,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
      ],
    ),
  );
  Widget _section(String title, IconData icon, List<Widget> children) => Card(
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.accent),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryDark,
                ),
              ),
            ],
          ),
          const Divider(height: 28),
          ...children,
        ],
      ),
    ),
  );
  Widget _field(String title, String? value, {String missing = 'غير محدد'}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            SelectableText(
              value?.trim().isNotEmpty == true ? value! : missing,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textPrimary,
                height: 1.7,
              ),
            ),
          ],
        ),
      );
}

/// Linked requests created from this visit's plan. Hidden when empty.
class _PlanActionsCard extends StatelessWidget {
  const _PlanActionsCard({required this.visitId, required this.patientId});
  final int visitId;
  final int patientId;

  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<Map<String, List<Map<String, Object?>>>>(
    future: PlanRepository().forVisit(visitId),
    builder: (context, snapshot) {
      final data = snapshot.data;
      if (data == null ||
          (data['sessions']!.isEmpty &&
              data['investigations']!.isEmpty &&
              data['referrals']!.isEmpty)) {
        return const SizedBox.shrink();
      }
      return Card(
        margin: const EdgeInsets.only(bottom: 20),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'طلبات هذه الزيارة',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              if (data['sessions']!.isNotEmpty)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.spa_outlined),
                  title: Text(
                    'جلسات: ${data['sessions']!.length} — ${data['sessions']!.first['service_name']}',
                  ),
                  trailing: TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SessionsScreen(patientId: patientId),
                      ),
                    ),
                    child: const Text('فتح الجلسات'),
                  ),
                ),
              if (data['investigations']!.isNotEmpty)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.biotech),
                  title: Text(
                    'تصوير وفحوص: ${data['investigations']!.map((e) => (e['kind'] as String? ?? '').trim().isEmpty ? 'فحص بدون اسم' : e['kind']).join('، ')}',
                  ),
                  trailing: TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            InvestigationsScreen(patientId: patientId),
                      ),
                    ),
                    child: const Text('فتح الفحوص'),
                  ),
                ),
              for (final r in data['referrals']!)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.forward_to_inbox_outlined),
                  title: Text(
                    '${r['category'] == 'consultation' ? 'استشارة' : 'تحويل إلى ${r['target_type']}'}: ${r['destination'] ?? '—'}',
                  ),
                  subtitle: (r['reason'] as String?)?.isNotEmpty == true
                      ? Text('السبب: ${r['reason']}')
                      : null,
                ),
            ],
          ),
        ),
      );
    },
  );
}

