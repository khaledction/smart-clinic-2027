import '../../core/widgets/day_groups.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/csv_exporter.dart';
import '../../core/utils/date_fmt.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/section_card.dart';
import '../../data/models/patient.dart';
import '../../data/providers/patients_provider.dart';
import '../../data/providers/session_provider.dart';
import '../../data/repositories/reports_repository.dart';
import 'patient_detail_screen.dart';
import 'patient_form_screen.dart';
import '../../core/widgets/search_field.dart';

/// شاشة قائمة المرضى: بحث + جدول + إضافة.
class PatientsScreen extends StatefulWidget {
  const PatientsScreen({super.key});

  @override
  State<PatientsScreen> createState() => _PatientsScreenState();
}

class _PatientsScreenState extends State<PatientsScreen> {
  final _search = TextEditingController();
  final _reports = ReportsRepository();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<PatientsProvider>().load();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _openForm(BuildContext context, {Patient? patient}) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => PatientFormScreen(patient: patient)),
    );
    if (changed != true) return;
    if (!mounted || !context.mounted) return;
    await context.read<PatientsProvider>().load();
  }

  Future<void> _export() async {
    final rows = await _reports.patientsExportRows();
    final path = await CsvExporter.save(
      suggestedName: 'المرضى-${DateFmt.isoDate(DateTime.now())}.csv',
      headers: const [
        'رقم الملف',
        'الاسم',
        'الجنس',
        'تاريخ الميلاد',
        'الهاتف',
        'العنوان',
        'الحساسية',
        'الحالة',
        'تاريخ الإضافة',
        'العمر بالسنوات',
        'تاريخ تسجيل العمر',
      ],
      rows: rows,
    );
    if (path != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تصدير الملف بنجاح'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PatientsProvider>();
    final user = context.watch<SessionProvider>().user;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: SectionCard(
          title: 'المرضى (${provider.total})',
          icon: Icons.people_outline,
          padding: const EdgeInsets.all(0),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 280,
                child: AppSearchField(
                  controller: _search,
                  onChanged: provider.setQuery,
                  hint: 'بحث بالاسم أو الهاتف أو رقم الملف…',
                ),
              ),
              const SizedBox(width: 8),
              if (user?.isAdmin ?? false)
                OutlinedButton.icon(
                  onPressed: _export,
                  icon: const Icon(Icons.download_outlined, size: 17),
                  label: const Text('تصدير CSV'),
                ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => _openForm(context),
                icon: const Icon(Icons.add, size: 17),
                label: const Text('مريض جديد'),
              ),
            ],
          ),
          child: provider.loading && provider.items.isEmpty
              ? const SizedBox(
                  height: 260,
                  child: Center(child: CircularProgressIndicator()),
                )
              : provider.items.isEmpty
              ? const EmptyState(
                  message: 'لا يوجد مرضى مطابقون — أضف مريضاً جديداً للبدء',
                  icon: Icons.person_search_outlined,
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'المرضى حسب تاريخ إنشاء الملف • البحث يعرض النتائج في جميع الأيام',
                      ),
                    ),
                    DayGroups<Patient>(
                      items: provider.items,
                      dateOf: (p) => p.createdAt,
                      noun: 'مريض',
                      searching: provider.query.trim().isNotEmpty,
                      groupBuilder: (dayPatients) => _PatientsTable(
                        items: dayPatients,
                        onOpen: (p) async {
                          if (user?.isDoctor != true) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("السجل السريري متاح للطبيب فقط"),
                              ),
                            );
                            return;
                          }
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PatientDetailScreen(
                                patientId: p.id!,
                                name: p.fullName,
                              ),
                            ),
                          );
                          if (!mounted || !context.mounted) return;
                          await context.read<PatientsProvider>().load();
                        },
                        onEdit: (p) => _openForm(context, patient: p),
                        onArchive: (p) async {
                          final provider = context.read<PatientsProvider>();
                          final future = p.isActive
                              ? provider.archive(p.id!)
                              : provider.restore(p.id!);
                          await future;
                        },
                      ),
                    ),
                    if (provider.hasMore)
                      TextButton(
                        onPressed: provider.loading ? null : provider.loadMore,
                        child: const Text('تحميل المزيد من المرضى'),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _PatientsTable extends StatelessWidget {
  const _PatientsTable({
    required this.items,
    required this.onOpen,
    required this.onEdit,
    required this.onArchive,
  });

  final List<Patient> items;
  final ValueChanged<Patient> onOpen;
  final ValueChanged<Patient> onEdit;
  final ValueChanged<Patient> onArchive;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: MediaQuery.of(context).size.width - 260,
        ),
        child: DataTable(
          showCheckboxColumn: false,
          columns: const [
            DataColumn(label: Text('رقم الملف')),
            DataColumn(label: Text('الاسم')),
            DataColumn(label: Text('العمر')),
            DataColumn(label: Text('الجنس')),
            DataColumn(label: Text('الهاتف')),
            DataColumn(label: Text('العنوان')),
            DataColumn(label: Text('الحالة')),
            DataColumn(label: Text('إجراءات')),
          ],
          rows: items.map((p) {
            return DataRow(
              onSelectChanged: (_) => onOpen(p),
              cells: [
                DataCell(Text(p.fileNo ?? '—')),
                DataCell(
                  Text(
                    p.fullName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                DataCell(Text(p.age == null ? '—' : '${p.age}')),
                DataCell(Text(p.genderLabel)),
                DataCell(Text(p.phone ?? '—')),
                DataCell(Text(p.address ?? '—')),
                DataCell(
                  p.isActive
                      ? const StatusChipInline(
                          label: 'نشط',
                          color: AppColors.success,
                        )
                      : const StatusChipInline(
                          label: 'مؤرشف',
                          color: AppColors.textSecondary,
                        ),
                ),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'تعديل',
                        icon: const Icon(
                          Icons.edit_outlined,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        onPressed: () => onEdit(p),
                      ),
                      IconButton(
                        tooltip: p.isActive ? 'أرشفة' : 'استعادة',
                        icon: Icon(
                          p.isActive
                              ? Icons.archive_outlined
                              : Icons.unarchive_outlined,
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                        onPressed: () => onArchive(p),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

class StatusChipInline extends StatelessWidget {
  const StatusChipInline({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
  );
}
