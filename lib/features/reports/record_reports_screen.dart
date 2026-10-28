import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../../core/printing/clinic_print.dart';
import '../../core/utils/csv_exporter.dart';
import '../../core/utils/neuro_constants.dart';
import '../../core/widgets/patient_link.dart';
import '../visits/visit_detail_screen.dart';
import '../../core/widgets/clinic_brand.dart';
import '../../core/widgets/range_picker.dart';

class RecordReportsScreen extends StatefulWidget {
  const RecordReportsScreen({super.key});
  @override
  State<RecordReportsScreen> createState() => _RecordReportsScreenState();
}

class _RecordReportsScreenState extends State<RecordReportsScreen> {
  bool files = false;
  String query = '', type = 'all';
  DateTimeRange? range;
  late Future<List<Map<String, Object?>>> records = load();
  Future<List<Map<String, Object?>>> load() async {
    final db = await AppDatabase.instance.database;
    final start = range?.start.toIso8601String().substring(0, 10),
        end = range?.end.toIso8601String().substring(0, 10);
    if (files) {
      return db.rawQuery(
        '''SELECT p.*, p.id AS patient_id,
      (SELECT COUNT(*) FROM visits v WHERE v.patient_id=p.id) AS visit_count,
      (SELECT MAX(visit_date) FROM visits v WHERE v.patient_id=p.id) AS last_visit
      FROM patients p WHERE (p.full_name LIKE ? OR COALESCE(p.file_no,'') LIKE ?)
      AND (? IS NULL OR date(p.created_at)>=?) AND (? IS NULL OR date(p.created_at)<=?) ORDER BY p.created_at DESC,p.id DESC''',
        ['%$query%', '%$query%', start, start, end, end],
      );
    }
    return db.rawQuery(
      '''SELECT v.*,p.full_name,p.file_no,COALESCE(v.visit_category,v.visit_type) AS type FROM visits v JOIN patients p ON p.id=v.patient_id
      WHERE (p.full_name LIKE ? OR COALESCE(p.file_no,'') LIKE ?) AND (?='all' OR COALESCE(v.visit_category,v.visit_type)=?)
      AND (? IS NULL OR date(v.visit_date)>=?) AND (? IS NULL OR date(v.visit_date)<=?) ORDER BY v.visit_date DESC,v.id DESC''',
      ['%$query%', '%$query%', type, type, start, start, end, end],
    );
  }

  void refresh() {
    setState(() {
      records = load();
    });
  }

  List<String> get headers => files
      ? [
          'رقم الملف',
          'المريض',
          'العمر',
          'الوزن كغ',
          'إنشاء الملف',
          'آخر زيارة',
          'عدد الزيارات',
        ]
      : ['رقم الملف', 'المريض', 'التاريخ', 'نوع الزيارة', 'الحالة'];
  List<List<String>> values(List<Map<String, Object?>> rows) => [
    for (final r in rows)
      files
          ? [
              '${r['file_no'] ?? ''}',
              '${r['full_name']}',
              '${r['age_years'] ?? ''}',
              '${r['weight_kg'] ?? ''}',
              '${r['created_at'] ?? ''}'.split('T').first,
              '${r['last_visit'] ?? ''}',
              '${r['visit_count']}',
            ]
          : [
              '${r['file_no'] ?? ''}',
              '${r['full_name']}',
              '${r['visit_date']}',
              NeuroConstants.visitTypes[r['type']] ?? '${r['type']}',
              r['completed_at'] == null ? 'غير منتهية' : 'منتهية',
            ],
  ];
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const BrandedAppBar(title: Text('تقارير الملفات والزيارات')),
    body: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            children: [
              ChoiceChip(
                label: const Text('تقرير زيارات المرضى'),
                selected: !files,
                onSelected: (_) {
                  files = false;
                  refresh();
                },
              ),
              ChoiceChip(
                label: const Text('تقرير ملفات المرضى'),
                selected: files,
                onSelected: (_) {
                  files = true;
                  refresh();
                },
              ),
              TextButton(
                onPressed: () async {
                  final r = await pickDateRange(
                    context,
                    firstDate: DateTime(1900),
                    lastDate: DateTime(2100),
                    initial: range,
                  );
                  if (r != null) {
                    range = r;
                    refresh();
                  }
                },
                child: Text(files ? 'فترة إنشاء الملفات' : 'فترة الزيارات'),
              ),
              if (range != null)
                TextButton(
                  onPressed: () {
                    range = null;
                    refresh();
                  },
                  child: const Text('كل التواريخ'),
                ),
            ],
          ),
          TextField(
            decoration: const InputDecoration(
              labelText: 'بحث باسم المريض أو رقم الملف',
            ),
            onChanged: (v) {
              query = v.trim();
              refresh();
            },
          ),
          if (!files)
            DropdownButton<String>(
              value: type,
              items: [
                const DropdownMenuItem(
                  value: 'all',
                  child: Text('كل أنواع الزيارات'),
                ),
                for (final e in NeuroConstants.visitTypes.entries)
                  DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: (v) {
                type = v!;
                refresh();
              },
            ),
          const Text(
            'التقرير لا يعرض التشخيصات والتفاصيل الحساسة افتراضياً. انقر اسم المريض لفتح ملفه.',
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, Object?>>>(
              future: records,
              builder: (ctx, s) {
                if (s.hasError) {
                  return Center(child: Text('تعذر التحميل: ${s.error}'));
                }
                if (!s.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final data = s.data!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text('العدد: ${data.length}')),
                        TextButton.icon(
                          onPressed: data.isEmpty
                              ? null
                              : () => ClinicPrint.preview(
                                  context,
                                  'معاينة التقرير',
                                  ClinicPrint.document(
                                    files
                                        ? 'تقرير ملفات المرضى'
                                        : 'تقرير زيارات المرضى',
                                    headers,
                                    values(data),
                                  ),
                                ),
                          icon: const Icon(Icons.print),
                          label: const Text('معاينة / طباعة PDF'),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () async {
                            try {
                              await CsvExporter.save(
                                suggestedName: files
                                    ? 'patients-report.csv'
                                    : 'visits-report.csv',
                                headers: headers,
                                rows: values(data),
                              );
                            } catch (e) {
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(content: Text(e.toString())),
                                );
                              }
                            }
                          },
                          child: const Text('تصدير CSV'),
                        ),
                      ],
                    ),
                    Expanded(
                      child: ListView(
                        children: [
                          for (final r in data)
                            Card(
                              child: ListTile(
                                title: PatientLink(
                                  patientId: r['patient_id'] as int,
                                  name: r['full_name'] as String,
                                ),
                                subtitle: Text(
                                  files
                                      ? 'ملف ${r['file_no'] ?? r['id']} • ${r['visit_count']} زيارة • آخر زيارة ${r['last_visit'] ?? 'لا توجد'}'
                                      : '${r['visit_date']} • ${NeuroConstants.visitTypes[r['type']] ?? r['type']}',
                                ),
                                trailing: files
                                    ? null
                                    : TextButton(
                                        onPressed: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => VisitDetailScreen(
                                              visitId: r['id'] as int,
                                            ),
                                          ),
                                        ),
                                        child: const Text('تفاصيل الزيارة'),
                                      ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

