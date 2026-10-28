import 'record_reports_screen.dart';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/csv_exporter.dart';
import '../../core/services/report_export_service.dart';
import '../../core/utils/date_fmt.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/section_card.dart';
import '../../data/repositories/reports_repository.dart';
import '../../core/widgets/range_picker.dart';

/// تقارير العيادة: رسوم بيانية + جداول + تصدير CSV.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _repo = ReportsRepository();

  bool _loading = true;
  DateTime? _from;
  DateTime? _to;

  List<Map<String, Object?>> _perDay = [];
  List<Map<String, Object?>> _topDiagnoses = [];
  List<Map<String, Object?>> _monthlyIncome = [];
  List<Map<String, Object?>> _ageBands = [];
  List<Map<String, Object?>> _monthlyDone = [];
  Map<String, num> _stats = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      _repo.visitsPerDay(days: 30),
      _repo.topDiagnoses(),
      _repo.monthlyIncome(),
      _repo.ageDistribution(),
      _repo.dashboardNumbers(),
      _repo.monthlyDone(),
    ]);
    if (!mounted || !context.mounted) return;
    setState(() {
      _perDay = results[0] as List<Map<String, Object?>>;
      _topDiagnoses = results[1] as List<Map<String, Object?>>;
      _monthlyIncome = results[2] as List<Map<String, Object?>>;
      _ageBands = results[3] as List<Map<String, Object?>>;
      _stats = results[4] as Map<String, num>;
      _monthlyDone = results[5] as List<Map<String, Object?>>;
      _loading = false;
    });
  }

  Future<void> _exportVisits() async {
    final rows = await _repo.visitsExportRows(from: _from, to: _to);
    final path = await CsvExporter.save(
      suggestedName: 'الزيارات-${DateFmt.isoDate(DateTime.now())}.csv',
      headers: const [
        'التاريخ',
        'رقم الملف',
        'المريض',
        'النوع',
        'الشكوى',
        'ICD-10',
        'التشخيص',
        'الخطة',
      ],
      rows: rows,
    );
    if (path != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم التصدير'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _pickRange() async {
    final range = await pickDateRange(
      context,
      firstDate: DateTime(2015),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initial: _from == null || _to == null
          ? null
          : DateTimeRange(start: _from!, end: _to!),
    );
    if (range != null) {
      setState(() {
        _from = range.start;
        _to = range.end;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat('#,##0', 'en_US');

    if (_loading) return const Center(child: CircularProgressIndicator());

    final maxCount = _perDay.isEmpty
        ? 10.0
        : _perDay
              .map((e) => (e['count'] as num?)?.toDouble() ?? 0)
              .reduce((a, b) => a > b ? a : b);

    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: FilledButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RecordReportsScreen()),
            ),
            icon: const Icon(Icons.table_chart_outlined),
            label: const Text('تقارير ملفات المرضى والزيارات'),
          ),
        ),
        const SizedBox(height: 16),
        // ---------------------------------------------------- ملخص سريع
        LayoutBuilder(
          builder: (context, c) => GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: c.maxWidth > 1300
                  ? 6
                  : (c.maxWidth > 640 ? 3 : 2),
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              mainAxisExtent: 78,
            ),
            children: [
              _miniStat(
                'إجمالي المرضى',
                '${_stats['patientsTotal'] ?? 0}',
                Icons.people_outline,
                AppColors.navy,
              ),
              _miniStat(
                'معاينات منجزة اليوم',
                '${_stats['checkupsDoneToday'] ?? 0}',
                Icons.medical_services_outlined,
                AppColors.primary,
              ),
              _miniStat(
                'جلسات منجزة اليوم',
                '${_stats['sessionsDoneToday'] ?? 0}',
                Icons.bolt_outlined,
                AppColors.accent,
              ),
              _miniStat(
                'إيراد المعاينات — الشهر',
                currency.format(_stats['incomeConsultationMonth'] ?? 0),
                Icons.payments_outlined,
                AppColors.primary,
              ),
              _miniStat(
                'إيراد الجلسات — الشهر',
                currency.format(_stats['incomeSessionMonth'] ?? 0),
                Icons.payments_outlined,
                AppColors.accent,
              ),
              _miniStat(
                'مراجعات متأخرة',
                '${_stats['pendingFollowUps'] ?? 0}',
                Icons.follow_the_signs_outlined,
                AppColors.danger,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // -------------------------------------------------- الرسم البياني
        SectionCard(
          title: 'عدد الزيارات — آخر 30 يوماً',
          icon: Icons.bar_chart_outlined,
          child: SizedBox(
            height: 240,
            child: _perDay.isEmpty
                ? const EmptyState(message: 'لا توجد بيانات كافية')
                : BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: (maxCount < 5 ? 5 : maxCount * 1.25).toDouble(),
                      barTouchData: BarTouchData(enabled: false),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: maxCount < 5
                            ? 1
                            : (maxCount / 4).ceilToDouble(),
                        getDrawingHorizontalLine: (_) => const FlLine(
                          color: AppColors.divider,
                          strokeWidth: 1,
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 32,
                            getTitlesWidget: (value, meta) => Text(
                              value.toInt().toString(),
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 26,
                            interval: 5,
                            getTitlesWidget: (value, meta) {
                              final i = value.toInt();
                              if (i < 0 || i >= _perDay.length) {
                                return const SizedBox.shrink();
                              }
                              final day = (_perDay[i]['day'] as String? ?? '')
                                  .substring(5);
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  day,
                                  style: const TextStyle(
                                    fontSize: 9.5,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      barGroups: _perDay.asMap().entries.map((e) {
                        return BarChartGroupData(
                          x: e.key,
                          barRods: [
                            BarChartRodData(
                              toY: (e.value['count'] as num?)?.toDouble() ?? 0,
                              color: AppColors.primary,
                              width: 12,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 18),

        LayoutBuilder(
          builder: (context, c) {
            final diagnosesCard = SectionCard(
              title: 'أكثر التشخيصات تكراراً',
              icon: Icons.medical_services_outlined,
              child: _topDiagnoses.isEmpty
                  ? const EmptyState(message: 'لا توجد بيانات')
                  : DataTable(
                      columnSpacing: 20,
                      columns: const [
                        DataColumn(label: Text('ICD-10')),
                        DataColumn(label: Text('التشخيص')),
                        DataColumn(label: Text('العدد')),
                      ],
                      rows: _topDiagnoses
                          .map(
                            (r) => DataRow(
                              cells: [
                                DataCell(Text('${r['icd10']}')),
                                DataCell(
                                  SizedBox(
                                    width: 240,
                                    child: Text(
                                      '${r['diagnosis']}',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                DataCell(Text('${r['count']}')),
                              ],
                            ),
                          )
                          .toList(),
                    ),
            );

            final incomeCard = SectionCard(
              title: 'الإيراد الشهري',
              icon: Icons.payments_outlined,
              child: _monthlyIncome.isEmpty
                  ? const EmptyState(message: 'لا توجد مدفوعات مسجلة')
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columnSpacing: 20,
                        columns: const [
                          DataColumn(label: Text('الشهر')),
                          DataColumn(label: Text('المعاينات')),
                          DataColumn(label: Text('الجلسات')),
                          DataColumn(label: Text('سابقة / يدوية')),
                          DataColumn(label: Text('الإجمالي')),
                        ],
                        rows: _monthlyIncome.map((r) {
                          String m(String k) =>
                              currency.format((r[k] as num?)?.toDouble() ?? 0);
                          return DataRow(
                            cells: [
                              DataCell(Text('${r['month']}')),
                              DataCell(Text(m('consultation'))),
                              DataCell(Text(m('session'))),
                              DataCell(Text(m('legacy'))),
                              DataCell(
                                Text(
                                  m('total'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
            );

            final doneCard = SectionCard(
              title: 'المنجز شهرياً — معاينات وجلسات',
              icon: Icons.task_alt_outlined,
              child: _monthlyDone.isEmpty
                  ? const EmptyState(message: 'لا توجد معاينات أو جلسات منجزة')
                  : DataTable(
                      columnSpacing: 20,
                      columns: const [
                        DataColumn(label: Text('الشهر')),
                        DataColumn(label: Text('المعاينات')),
                        DataColumn(label: Text('الجلسات')),
                      ],
                      rows: _monthlyDone
                          .map(
                            (r) => DataRow(
                              cells: [
                                DataCell(Text('${r['month']}')),
                                DataCell(Text('${r['checkups'] ?? 0}')),
                                DataCell(Text('${r['sessions'] ?? 0}')),
                              ],
                            ),
                          )
                          .toList(),
                    ),
            );

            final ageCard = SectionCard(
              title: 'التوزيع العمري للمرضى',
              icon: Icons.pie_chart_outline,
              child: _ageBands.isEmpty
                  ? const EmptyState(message: 'لا توجد بيانات')
                  : DataTable(
                      columnSpacing: 20,
                      columns: const [
                        DataColumn(label: Text('الفئة')),
                        DataColumn(label: Text('العدد')),
                      ],
                      rows: _ageBands
                          .map(
                            (r) => DataRow(
                              cells: [
                                DataCell(Text('${r['band']}')),
                                DataCell(Text('${r['count']}')),
                              ],
                            ),
                          )
                          .toList(),
                    ),
            );

            if (c.maxWidth > 1000) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: diagnosesCard),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      children: [
                        incomeCard,
                        const SizedBox(height: 16),
                        doneCard,
                        const SizedBox(height: 16),
                        ageCard,
                      ],
                    ),
                  ),
                ],
              );
            }
            return Column(
              children: [
                diagnosesCard,
                const SizedBox(height: 16),
                incomeCard,
                const SizedBox(height: 16),
                doneCard,
                const SizedBox(height: 16),
                ageCard,
              ],
            );
          },
        ),
        const SizedBox(height: 18),

        // ------------------------------------------------------------ التصدير
        SectionCard(
          title: 'تصدير البيانات',
          icon: Icons.download_outlined,
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _pickRange,
                  icon: const Icon(Icons.date_range_outlined, size: 17),
                  label: Text(
                    _from == null
                        ? 'تحديد نطاق زمني (اختياري)'
                        : '${DateFmt.date(_from!)} → ${DateFmt.date(_to!)}',
                  ),
                ),
                FilledButton.icon(
                  onPressed: _exportVisits,
                  icon: const Icon(Icons.table_view_outlined, size: 17),
                  label: const Text('تصدير الزيارات CSV'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(icon: const Icon(Icons.picture_as_pdf_outlined), label: const Text('PDF'), onPressed: () => ReportExportService.exportDailyPdf(context, DateTime.now())),
                const SizedBox(width: 8),
                FilledButton.icon(icon: const Icon(Icons.table_chart_outlined), label: const Text('Excel'), onPressed: () => ReportExportService.exportDailyExcel(context, DateTime.now())),
                if (_from != null)
                  TextButton(
                    onPressed: () => setState(() {
                      _from = null;
                      _to = null;
                    }),
                    child: const Text('إزالة النطاق'),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _miniStat(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
