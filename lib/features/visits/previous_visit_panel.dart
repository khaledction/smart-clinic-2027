import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/date_fmt.dart';
import '../../data/models/patient.dart';
import '../../data/models/visit.dart';
import '../../data/repositories/patient_repository.dart';
import '../../data/repositories/visit_repository.dart';
import 'visit_detail_screen.dart';

/// A separate read-only context panel. It never writes to the current visit form.
class PreviousVisitPanel extends StatefulWidget {
  const PreviousVisitPanel({super.key, required this.patientId});
  final int patientId;
  @override
  State<PreviousVisitPanel> createState() => _PreviousVisitPanelState();
}

class _PreviousVisitPanelState extends State<PreviousVisitPanel> {
  late Future<(Patient?, Visit?, List<Medication>)> _record;
  @override
  void initState() {
    super.initState();
    _record = _load();
  }

  Future<(Patient?, Visit?, List<Medication>)> _load() async {
    final p = await PatientRepository().byId(widget.patientId);
    final visits = await VisitRepository().forPatient(widget.patientId);
    final last = visits.isEmpty
        ? null
        : await VisitRepository().full(visits.first.id!);
    final meds = await PatientRepository().medications(
      widget.patientId,
      onlyActive: true,
    );
    return (p, last, meds);
  }

  @override
  Widget build(BuildContext context) => Card(
    color: const Color(0xFFF0F7F9),
    child: FutureBuilder<(Patient?, Visit?, List<Medication>)>(
      future: _record,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Expanded(child: Text('تعذّر تحميل السجل السابق')),
                TextButton(
                  onPressed: () => setState(() {
                    _record = _load();
                  }),
                  child: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: LinearProgressIndicator(),
          );
        }
        final (p, v, meds) = snapshot.data!;
        return ExpansionTile(
          initiallyExpanded: true,
          leading: const Icon(Icons.history, color: AppColors.primary),
          title: const Text(
            'مرجع قبل الكشف • للقراءة فقط',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            v == null
                ? 'لا توجد زيارة سابقة لهذا المريض'
                : 'آخر زيارة: ${DateFmt.date(v.visitDate)}',
          ),
          childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('العمر: ${p?.ageLabel ?? "غير محدد"}'),
            Text(
              'الحساسية: ${p?.allergies?.trim().isNotEmpty == true ? p!.allergies : "غير محددة"}',
              style: const TextStyle(color: AppColors.danger),
            ),
            const SizedBox(height: 8),
            Text(
              'الأدوية الحالية: ${meds.isEmpty ? "غير محددة" : meds.map((m) => "${m.drug} ${m.dose ?? ''} ${m.frequency ?? ''}").join(' • ')}',
            ),
            if (v != null) ...[
              const Divider(),
              SelectableText(
                'الشكوى السابقة: ${v.chiefComplaint ?? "غير محددة"}',
              ),
              SelectableText('التشخيص السابق: ${v.diagnosis ?? "غير محدد"}'),
              SelectableText('الخطة السابقة: ${v.plan ?? "غير محددة"}'),
              if (v.prescriptions.isNotEmpty)
                SelectableText(
                  'وصفة الزيارة السابقة (ليست بالضرورة العلاج الحالي): ${v.prescriptions.map((rx) => "${rx.drug} ${rx.dose ?? ''}").join(' • ')}',
                ),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => VisitDetailScreen(visitId: v.id!),
                    ),
                  ),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('عرض الفحص والوصفة السابقين'),
                ),
              ),
            ],
            const SizedBox(height: 6),
            const Text(
              'لن تُنسخ نتائج الفحص أو الأدوية تلقائياً إلى الزيارة الحالية.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        );
      },
    ),
  );
}
