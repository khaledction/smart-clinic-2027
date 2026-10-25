import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_fmt.dart';
import '../../core/widgets/patient_link.dart';
import '../../core/theme/app_sizes.dart';
import '../../core/utils/csv_exporter.dart';
import '../../data/repositories/treatment_repository.dart';
import '../../core/widgets/clinic_brand.dart';
import '../../core/widgets/range_picker.dart';
import '../../core/widgets/search_field.dart';

String fmtMoney(Object? v) {
  final n = (v as num?)?.toDouble() ?? 0;
  return n == n.roundToDouble() ? n.toInt().toString() : n.toString();
}

class _TypeTotal {
  const _TypeTotal(this.name, this.count, this.paid);
  final String name;
  final int count;
  final double paid;
}

class _FinanceSummary {
  const _FinanceSummary({
    required this.todayIncome,
    required this.monthIncome,
    required this.todayPatients,
    required this.monthPatients,
    required this.types,
    required this.today,
    required this.month,
  });
  final double todayIncome;
  final double monthIncome;
  final int todayPatients;
  final int monthPatients;
  final List<_TypeTotal> types;

  /// المقبوضات حسب القسم: consultation / session / legacy.
  final Map<String, double> today;
  final Map<String, double> month;
}

const _categories = {
  'consultation': 'المعاينات',
  'session': 'الجلسات',
  'legacy': 'دفعات سابقة / يدوية',
};

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key, this.embedded = false});

  /// داخل الإطار الرئيسي يظهر العنوان «المالية» في الشريط العلوي للبرنامج،
  /// فلا نكرره بشريط عنوان ثانٍ.
  final bool embedded;
  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  String category = 'consultation', query = '';
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  DateTimeRange? range;
  late Future<List<Map<String, Object?>>> rows = load();
  late Future<_FinanceSummary> summary = loadSummary();

  Future<List<Map<String, Object?>>> load() async =>
      (await AppDatabase.instance.database).rawQuery(
        '''SELECT x.*, p.full_name FROM payments x JOIN patients p ON p.id=x.patient_id
    WHERE x.category=? AND p.full_name LIKE ? AND (? IS NULL OR date(x.paid_at)>=?) AND (? IS NULL OR date(x.paid_at)<=?) ORDER BY x.paid_at DESC,x.id DESC''',
        [
          category,
          '%$query%',
          range?.start.toIso8601String().substring(0, 10),
          range?.start.toIso8601String().substring(0, 10),
          range?.end.toIso8601String().substring(0, 10),
          range?.end.toIso8601String().substring(0, 10),
        ],
      );

  Future<_FinanceSummary> loadSummary() async {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month);
    final nextMonth = DateTime(now.year, now.month + 1);
    String day(DateTime d) => d.toIso8601String().substring(0, 10);
    final today = day(now);
    final db = await AppDatabase.instance.database;
    final payments = await db.rawQuery(
      '''SELECT patient_id, amount, paid_at, category FROM payments
         WHERE paid_at IS NOT NULL AND date(paid_at) >= ? AND date(paid_at) < ?''',
      [day(monthStart), day(nextMonth)],
    );
    var todayIncome = 0.0, monthIncome = 0.0;
    final byToday = <String, double>{for (final k in _categories.keys) k: 0};
    final byMonth = <String, double>{for (final k in _categories.keys) k: 0};
    final todayIds = <int>{};
    final monthIds = <int>{};
    for (final row in payments) {
      final amount = (row['amount'] as num?)?.toDouble() ?? 0;
      final paid = '${row['paid_at']}';
      final id = (row['patient_id'] as num?)?.toInt();
      final cat = _categories.containsKey(row['category'])
          ? row['category'] as String
          : 'legacy';
      monthIncome += amount;
      byMonth[cat] = byMonth[cat]! + amount;
      if (id != null) monthIds.add(id);
      if (paid.length >= 10 && paid.substring(0, 10) == today) {
        todayIncome += amount;
        byToday[cat] = byToday[cat]! + amount;
        if (id != null) todayIds.add(id);
      }
    }
    final sessions = await TreatmentRepository().sessions();
    final byType = <String, _TypeTotal>{};
    for (final row in sessions) {
      final when = DateFmt.parse(
        (row['performed_on'] ?? row['scheduled_on'] ?? row['ordered_at'])
            as String?,
      );
      if (when == null || when.year != now.year || when.month != now.month) {
        continue;
      }
      final name = (row['service_name'] as String?)?.trim();
      final label = name == null || name.isEmpty ? 'دون اسم' : name;
      final paid = row['payment_id'] == null
          ? 0.0
          : ((row['price'] as num?)?.toDouble() ?? 0);
      final prev = byType[label];
      byType[label] = _TypeTotal(
        label,
        (prev?.count ?? 0) + 1,
        (prev?.paid ?? 0) + paid,
      );
    }
    final types = byType.values.toList()
      ..sort((a, b) => b.paid.compareTo(a.paid));
    return _FinanceSummary(
      todayIncome: todayIncome,
      monthIncome: monthIncome,
      todayPatients: todayIds.length,
      monthPatients: monthIds.length,
      types: types,
      today: byToday,
      month: byMonth,
    );
  }

  void refresh() {
    setState(() {
      rows = load();
      summary = loadSummary();
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: widget.embedded
        ? null
        : BrandedAppBar(
            title: const Text('المالية'),
            actions: [
              IconButton(onPressed: refresh, icon: const Icon(Icons.refresh)),
            ],
          ),
    body: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FutureBuilder<_FinanceSummary>(
            future: summary,
            builder: (context, snap) {
              if (snap.hasError) {
                return Text('تعذر تحميل الملخص: ${snap.error}');
              }
              if (!snap.hasData) {
                return const LinearProgressIndicator();
              }
              final s = snap.data!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _mini('إيرادات اليوم', fmtMoney(s.todayIncome)),
                      _mini('إيرادات الشهر', fmtMoney(s.monthIncome)),
                      _mini('مرضى اليوم', '${s.todayPatients}'),
                      _mini('مرضى الشهر', '${s.monthPatients}'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _split(
                          'مالية المعاينات',
                          Icons.medical_services_outlined,
                          AppColors.primary,
                          s.today['consultation']!,
                          s.month['consultation']!,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _split(
                          'مالية الجلسات',
                          Icons.bolt_outlined,
                          AppColors.accent,
                          s.today['session']!,
                          s.month['session']!,
                        ),
                      ),
                      if (s.month['legacy']! > 0) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: _split(
                            'دفعات سابقة / يدوية',
                            Icons.history,
                            AppColors.textSecondary,
                            s.today['legacy']!,
                            s.month['legacy']!,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Card(
                    color: AppColors.cardTint,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'الصافي',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.navy,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'صافي الشهر: ${fmtMoney(s.monthIncome)}    •    صافي اليوم: ${fmtMoney(s.todayIncome)}',
                          ),
                          const Text(
                            'الصافي هو مجموع المقبوضات المسجّلة. لا تُخصم مصروفات لأن هذه الشاشة لا تسجّلها.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'الجلسات حسب النوع — هذا الشهر',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          if (s.types.isEmpty)
                            const Text(
                              'لا جلسات بتاريخ داخل هذا الشهر.',
                              style: TextStyle(color: AppColors.textSecondary),
                            )
                          else
                            for (final t in s.types)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  '${t.name}: ${t.count} جلسة • المدفوع ${fmtMoney(t.paid)}',
                                ),
                              ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              );
            },
          ),
          _paymentsToolbar(),
          const SizedBox(height: 4),
          const Text(
            'الدفعات القديمة لا تُعتبر تلقائياً سداداً كاملاً. تسجيل الدفع منفصل عن انتهاء الزيارة أو تنفيذ الجلسة.',
            style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: FutureBuilder<List<Map<String, Object?>>>(
              future: rows,
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
                    // العدد والإجمالي يميناً، وزر التصدير يساراً على نفس خط
                    // أزرار شريط الدفعات أعلاه، مع مسافة واضحة عن القائمة.
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'عدد الدفعات: ${data.length} — الإجمالي: ${fmtMoney(data.fold<double>(0, (v, r) => v + (r['amount'] as num).toDouble()))}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          SizedBox(
                            height: AppSizes.control,
                            child: OutlinedButton.icon(
                              key: const Key('financeExport'),
                              icon: const Icon(
                                Icons.file_download_outlined,
                                size: 18,
                              ),
                              onPressed: () async {
                                try {
                                  await CsvExporter.save(
                                    suggestedName: 'finance.csv',
                                    headers: [
                                      'المريض',
                                      'التاريخ',
                                      'الخدمة',
                                      'المبلغ',
                                      'النوع',
                                    ],
                                    rows: [
                                      for (final r in data)
                                        [
                                          r['full_name'],
                                          r['paid_at'],
                                          r['service_label'] ?? r['note'] ?? '',
                                          r['amount'],
                                          category,
                                        ],
                                    ],
                                  );
                                } catch (e) {
                                  if (ctx.mounted) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(content: Text(e.toString())),
                                    );
                                  }
                                }
                              },
                              label: const Text('تصدير CSV'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        children: [
                          for (final r in data)
                            Card(
                              child: ListTile(
                                dense: true,
                                mouseCursor: SystemMouseCursors.click,
                                title: PatientLink(
                                  patientId: r['patient_id'] as int,
                                  name: r['full_name'] as String,
                                ),
                                subtitle: Text(
                                  '${DateFmt.parse(r['paid_at'] as String?) == null ? 'دون تاريخ' : DateFmt.dateTime(DateFmt.parse(r['paid_at'] as String?)!)} • ${r['service_label'] ?? r['note'] ?? 'دفعة يدوية'}',
                                ),
                                trailing: Text(
                                  fmtMoney(r['amount']),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
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

  /// شريط سجل الدفعات: البحث في مكان واضح ومميّز، ومعه القسم والفترة.
  Widget _paymentsToolbar() => Container(
    key: const Key('financeToolbar'),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: AppColors.headerTint,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.frame),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(
              Icons.receipt_long_outlined,
              size: 20,
              color: AppColors.navy,
            ),
            const SizedBox(width: 6),
            const Text(
              'سجل الدفعات',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: AppSearchField(
                fieldKey: const Key('financeSearch'),
                controller: _search,
                onChanged: (v) {
                  query = v.trim();
                  refresh();
                },
                hint: 'ابحث باسم المريض في الدفعات…',
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'مسح البحث',
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          _search.clear();
                          query = '';
                          refresh();
                        },
                      ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: AppSizes.control,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final picked = await pickDateRange(
                    context,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                    initial: range,
                  );
                  if (picked != null) {
                    range = picked;
                    refresh();
                  }
                },
                icon: const Icon(Icons.date_range_outlined, size: 18),
                label: Text(
                  range == null
                      ? 'كل التواريخ'
                      : '${DateFmt.date(range!.start)} ← ${DateFmt.date(range!.end)}',
                ),
              ),
            ),
            if (range != null)
              IconButton(
                tooltip: 'إلغاء الفترة (كل التواريخ)',
                onPressed: () {
                  range = null;
                  refresh();
                },
                icon: const Icon(Icons.filter_alt_off_outlined),
              ),
            if (widget.embedded) ...[
              const SizedBox(width: 8),
              IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.navy,
                  foregroundColor: Colors.white,
                  fixedSize: const Size.square(AppSizes.control),
                ),
                tooltip: 'تحديث',
                onPressed: refresh,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        // أقسام الدفعات يساراً، بعرض متساوٍ وعلى خط أزرار الشريط.
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: SegmentedButton<String>(
            key: const Key('financeCategory'),
            showSelectedIcon: false,
            style: const ButtonStyle(
              minimumSize: WidgetStatePropertyAll(Size(150, AppSizes.control)),
              visualDensity: VisualDensity.standard,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            segments: [
              for (final e in _categories.entries)
                ButtonSegment(
                  value: e.key,
                  label: Text(e.value),
                  icon: Icon(switch (e.key) {
                    'consultation' => Icons.medical_services_outlined,
                    'session' => Icons.bolt_outlined,
                    _ => Icons.history,
                  }, size: 17),
                ),
            ],
            selected: {category},
            onSelectionChanged: (v) {
              category = v.first;
              refresh();
            },
          ),
        ),
      ],
    ),
  );

  Widget _split(
    String title,
    IconData icon,
    Color color,
    double today,
    double month,
  ) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withValues(alpha: 0.25)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 17, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                title,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w700, color: color),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'اليوم: ${fmtMoney(today)}  •  الشهر: ${fmtMoney(month)}',
          style: const TextStyle(fontSize: 12.5),
        ),
      ],
    ),
  );

  Widget _mini(String label, String value) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: AppColors.headerTint,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text('$label: $value', style: const TextStyle(fontSize: 12.5)),
  );
}
