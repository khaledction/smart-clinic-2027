import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_sizes.dart';
import '../../core/utils/age_input.dart';
import '../../core/utils/date_fmt.dart';
import '../../core/utils/neuro_constants.dart';
import '../../core/widgets/date_input.dart';
import '../../core/widgets/day_groups.dart';
import '../../core/widgets/hover_card.dart';
import '../../core/widgets/paid_widgets.dart';
import '../../core/widgets/patient_link.dart';
import '../../core/widgets/search_field.dart';
import '../../data/repositories/treatment_repository.dart';
import '../patients/patient_header.dart';
import '../visits/visit_detail_screen.dart';
import '../../core/widgets/clinic_brand.dart';

String fmtMoney(Object? v) {
  final n = (v as num?)?.toDouble() ?? 0;
  return n == n.roundToDouble() ? n.toInt().toString() : n.toString();
}

const sessionStatuses = {
  'requested': 'مطلوبة',
  'scheduled': 'مجدولة',
  'in_progress': 'قيد التنفيذ',
  'completed': 'نُفذت',
  'cancelled': 'ملغاة',
};
double? money(String text) => double.tryParse(
  normalizeDigits(text).replaceAll('٫', '.').replaceAll(',', '.'),
);
String? validMoney(String? text) {
  // فارغ مسموح (يُعتبر صفراً) — لا إدخال إلزامي.
  if ((text ?? '').trim().isEmpty) return null;
  final n = money(text ?? '');
  return n == null || !n.isFinite || n < 0 ? 'أدخل رقماً غير سالب' : null;
}

Future<void> requestTreatment(
  BuildContext context,
  int patientId,
  int visitId,
) async {
  final repo = TreatmentRepository();
  // نوعا الجلسات المعتمدان فقط؛ السعر من الإعدادات ← الزيارة والمعاينة.
  final services = (await repo.services())
      .where((s) => NeuroConstants.sessionOptions.contains(s['name']))
      .toList();
  if (!context.mounted) return;
  final name = TextEditingController(),
      count = TextEditingController(text: '1'),
      price = TextEditingController(text: '0'),
      indication = TextEditingController();
  final form = GlobalKey<FormState>();
  int? selected;
  bool busy = false;
  String? error;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, update) => PopScope(
        canPop: !busy,
        child: AlertDialog(
          title: const Text('طلب جلسات مرتبط بهذه الزيارة'),
          content: SizedBox(
            width: 550,
            child: SingleChildScrollView(
              child: Form(
                key: form,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 6),
                    DropdownButtonFormField<int>(
                      decoration: const InputDecoration(labelText: 'الخدمة'),
                      items: [
                        for (final s in services)
                          DropdownMenuItem(
                            value: s['id'] as int,
                            child: Text(s['name'] as String),
                          ),
                      ],
                      onChanged: busy
                          ? null
                          : (v) => update(() {
                              selected = v;
                              final s = services.firstWhere(
                                (s) => s['id'] == v,
                              );
                              name.text = s['name'] as String;
                              price.text = fmtMoney(s['price']);
                            }),
                      validator: (v) => v == null ? 'اختر الخدمة' : null,
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: count,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'عدد الجلسات المخططة (1–100)',
                      ),
                      validator: (v) {
                        // فارغ = جلسة واحدة.
                        if ((v ?? '').trim().isEmpty) return null;
                        final n = int.tryParse(normalizeDigits(v ?? ''));
                        return n == null || n < 1 || n > 100
                            ? 'عدد صحيح بين 1 و100'
                            : null;
                      },
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: price,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'سعر الجلسة الواحدة — عملة العيادة',
                        helperText:
                            'السعر ثابت من الإعدادات ← الزيارة والمعاينة',
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: indication,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'سبب الطلب / التقييم في الزيارة الأصلية',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.cardTint,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 18,
                            color: AppColors.navy,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'ينشأ سجل مستقل لكل جلسة. التشخيص والنتيجة والتنفيذ والدفع لا تُملأ تلقائياً.',
                              style: TextStyle(
                                fontSize: 12.5,
                                height: 1.6,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          error!,
                          style: const TextStyle(color: AppColors.danger),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (!form.currentState!.validate()) return;
                      update(() => busy = true);
                      try {
                        await repo.request(
                          patientId: patientId,
                          sourceVisitId: visitId,
                          name: name.text,
                          count: int.tryParse(normalizeDigits(count.text)) ?? 1,
                          price: money(price.text) ?? 0,
                          indication: indication.text.trim(),
                          serviceId: selected,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (e) {
                        if (ctx.mounted) {
                          update(() {
                            busy = false;
                            error = e.toString();
                          });
                        }
                      }
                    },
              child: Text(busy ? 'جارٍ الحفظ…' : 'إنشاء الطلب'),
            ),
          ],
        ),
      ),
    ),
  );
  // Controllers are released after the route transition has removed its fields.
  await Future<void>.delayed(const Duration(milliseconds: 300));
  for (final c in [name, count, price, indication]) {
    c.dispose();
  }
}

class SessionsScreen extends StatefulWidget {
  const SessionsScreen({
    super.key,
    this.patientId,
    this.title = 'الجلسات والإجراءات',
    this.serviceFilter,
    this.embedded = false,
  });
  final int? patientId;
  final String title;

  /// داخل الإطار الرئيسي يظهر العنوان في الشريط العلوي للبرنامج،
  /// فلا نكرره بشريط عنوان ثانٍ.
  final bool embedded;

  /// `ems` أو `traction`. لا يغيّر أسماء الخدمات المسجّلة.
  final String? serviceFilter;
  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  final repo = TreatmentRepository();
  late Future<List<Map<String, Object?>>> _rows = repo.sessions(
    patientId: widget.patientId,
  );
  String _query = '';
  void refresh() {
    setState(() {
      _rows = repo.sessions(patientId: widget.patientId);
    });
  }

  Future<void> _edit(Map<String, Object?> r) async {
    var status = r['status'] as String;
    DateTime? planned = DateFmt.parse(r['scheduled_on'] as String?),
        done = DateFmt.parse(r['performed_on'] as String?);
    final diagnosis = TextEditingController(text: r['diagnosis'] as String?),
        result = TextEditingController(text: r['result'] as String?),
        notes = TextEditingController(text: r['notes'] as String?),
        price = TextEditingController(text: fmtMoney(r['price']));
    final approved = NeuroConstants.sessionOptions.contains(r['service_name']);
    final key = GlobalKey<FormState>();
    bool busy = false;
    String? error;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, up) {
          // عرض يتسع للأزرار الخمسة بمقاس واحد جنباً إلى جنب.
          final width = (MediaQuery.sizeOf(ctx).width - 128).clamp(
            560.0,
            1120.0,
          );
          final isDone = status == 'completed';
          Future<DateTime?> pickDate(
            DateTime? initial,
            String help, {
            DateTime? last,
          }) => showAppDatePicker(
            ctx,
            initialDate: initial ?? DateTime.now(),
            firstDate: DateTime(2000),
            lastDate: last ?? DateTime(2100),
            helpText: help,
          );
          Widget field(TextEditingController c, String label, int lines) =>
              TextFormField(
                controller: c,
                maxLines: lines,
                decoration: InputDecoration(labelText: label),
              );
          return PopScope(
            canPop: !busy,
            child: AlertDialog(
              key: const Key('sessionDialog'),
              title: Row(
                children: [
                  const Icon(Icons.healing_outlined, color: AppColors.navy),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'تفاصيل ونتائج الجلسة — ${r['service_name']} • جلسة ${r['sequence_no']}',
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: width,
                child: SingleChildScrollView(
                  child: Form(
                    key: key,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // أهم بيانات المريض للتأكد من الملف الصحيح.
                        PatientSummaryLoader(patientId: r['patient_id'] as int),
                        const SizedBox(height: 18),
                        Wrap(
                          spacing: 20,
                          runSpacing: 8,
                          children: [
                            _info(
                              Icons.assignment_outlined,
                              'سبب الطلب: ${r['indication'] ?? 'غير محدد'}',
                            ),
                            _info(
                              Icons.event_outlined,
                              'موعد الجلسة: ${planned == null ? 'غير محدد' : DateFmt.date(planned!)}',
                              key: const Key('sessPlannedText'),
                            ),
                            _info(
                              Icons.task_alt,
                              'تاريخ التنفيذ: ${done == null ? 'غير محدد' : DateFmt.date(done!)}',
                              key: const Key('sessDoneText'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                key: ValueKey('status-$status'),
                                initialValue: status,
                                decoration: const InputDecoration(
                                  labelText: 'حالة الجلسة',
                                ),
                                items: sessionStatuses.entries
                                    .map(
                                      (e) => DropdownMenuItem(
                                        value: e.key,
                                        child: Text(e.value),
                                      ),
                                    )
                                    .toList(),
                                onChanged: busy
                                    ? null
                                    : (v) => up(() => status = v!),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: price,
                                readOnly: r['payment_id'] != null || approved,
                                decoration: InputDecoration(
                                  labelText: 'السعر — مستقل لهذه الجلسة',
                                  helperText: r['payment_id'] != null
                                      ? 'تم الدفع — السعر المالي مقفل'
                                      : approved
                                      ? 'السعر من الإعدادات ← الزيارة والمعاينة ويُعتمد عند الدفع'
                                      : 'لم يُسجل دفع؛ حفظ الجلسة لا يسجل دفعة',
                                ),
                                validator: validMoney,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: field(
                                diagnosis,
                                'تشخيص / تقييم هذه الجلسة',
                                3,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: field(
                                result,
                                'النتيجة والاستجابة للجلسة',
                                3,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        field(notes, 'ملاحظات الجلسة', 2),
                        if (error != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                // كل الأزرار في الأسفل: مقاس وشكل واحد جنباً إلى جنب.
                SizedBox(
                  width: width,
                  child: Row(
                    // مجمّعة إلى اليسار بعرض واحد لكل زر.
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      for (final (i, b) in [
                        _barButton(
                          key: const Key('sessOpenVisit'),
                          icon: Icons.open_in_new,
                          label: 'فتح الزيارة التي طلبت الجلسة',
                          onPressed: busy || r['source_visit_id'] == null
                              ? null
                              : () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => VisitDetailScreen(
                                      visitId: r['source_visit_id'] as int,
                                    ),
                                  ),
                                ),
                        ),
                        _barButton(
                          key: const Key('sessSchedule'),
                          icon: Icons.edit_calendar_outlined,
                          label: 'تحديد موعد الجلسة الجديد',
                          onPressed: busy
                              ? null
                              : () async {
                                  final d = await pickDate(
                                    planned,
                                    'موعد الجلسة الجديد',
                                  );
                                  if (d == null || !ctx.mounted) return;
                                  up(() {
                                    planned = d;
                                    if (status == 'requested') {
                                      status = 'scheduled';
                                    }
                                  });
                                },
                        ),
                        _barButton(
                          key: const Key('sessDone'),
                          icon: isDone
                              ? Icons.check_circle
                              : Icons.play_circle_outline,
                          label: isDone ? 'تمت الجلسة' : 'تنفيذ الجلسة',
                          color: isDone ? AppColors.paid : null,
                          tooltip: isDone ? 'تعديل تاريخ التنفيذ' : 'تسجيل الجلسة كمنفذة اليوم (تُحفظ عند «حفظ الجلسة»)',
                          onPressed: busy
                              ? null
                              : () async {
                                  if (!isDone) {
                                    up(() {
                                      status = 'completed';
                                      done ??= DateTime.now();
                                    });
                                    return;
                                  }
                                  final d = await pickDate(
                                    done,
                                    'تاريخ تنفيذ الجلسة',
                                    last: DateTime.now(),
                                  );
                                  if (d != null && ctx.mounted) {
                                    up(() => done = d);
                                  }
                                },
                        ),
                        _barButton(
                          key: const Key('sessSave'),
                          icon: Icons.save_outlined,
                          label: busy ? 'جارٍ الحفظ…' : 'حفظ الجلسة',
                          onPressed: busy
                              ? null
                              : () async {
                                  if (!key.currentState!.validate()) return;
                                  up(() => busy = true);
                                  try {
                                    await repo.saveSession(
                                      r['id'] as int,
                                      status: status,
                                      price: money(price.text) ?? 0,
                                      scheduledOn: planned?.toIso8601String(),
                                      performedOn: done?.toIso8601String(),
                                      diagnosis: diagnosis.text.trim(),
                                      result: result.text.trim(),
                                      notes: notes.text.trim(),
                                    );
                                    if (ctx.mounted) Navigator.pop(ctx);
                                  } catch (e) {
                                    if (ctx.mounted) {
                                      up(() {
                                        busy = false;
                                        error = e is ArgumentError
                                            ? '${e.message}'
                                            : e.toString();
                                      });
                                    }
                                  }
                                },
                        ),
                        _barButton(
                          key: const Key('sessCancel'),
                          icon: Icons.close,
                          label: 'إلغاء',
                          onPressed: busy ? null : () => Navigator.pop(ctx),
                        ),
                      ].indexed) ...[
                        if (i > 0) const SizedBox(width: 8),
                        SizedBox(
                          width: ((width - 32) / 5).clamp(0.0, 216.0),
                          child: b,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    for (final c in [diagnosis, result, notes, price]) {
      c.dispose();
    }
    if (mounted) refresh();
  }

  static Widget _info(IconData icon, String text, {Key? key}) => Row(
    key: key,
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 17, color: AppColors.accent),
      const SizedBox(width: 6),
      Text(text, style: const TextStyle(fontSize: 13.5)),
    ],
  );

  /// زر شريط النافذة: كحلي بخط أبيض، ارتفاع وعرض موحدان؛ الأخضر لـ«تمت الجلسة».
  static Widget _barButton({
    required Key key,
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    Color? color,
    String? tooltip,
  }) {
    final button = FilledButton(
      key: key,
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: color,
        minimumSize: const Size(0, AppSizes.button),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        animationDuration: Duration.zero,
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 8),
            Text(label, maxLines: 1),
          ],
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip, child: button);
  }

  /// يسجّل دفع الجلسة مباشرة بسعر نوعها في الإعدادات. التكرار ممنوع.
  Future<bool> _pay(Map<String, Object?> r) async {
    try {
      await repo.paySession(r['id'] as int);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('سُجّل دفع ${r['service_name']} في مالية الجلسات'),
            backgroundColor: AppColors.success,
          ),
        );
        refresh();
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

  bool _matchesService(Map<String, Object?> row) {
    final filter = widget.serviceFilter;
    if (filter == null || filter.isEmpty) return true;
    final name = '${row['service_name'] ?? ''}'.toLowerCase();
    switch (filter) {
      case 'ems':
        return name.contains('ems');
      case 'traction':
        return name.contains('سحب') || name.contains('فقر');
      default:
        return name.contains(filter.toLowerCase());
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: widget.embedded
        ? null
        : BrandedAppBar(
            title: Text(widget.title),
            actions: [
              IconButton(onPressed: refresh, icon: const Icon(Icons.refresh)),
            ],
          ),
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ترويسة ملف المريض نفسها للتأكد أننا في الملف الصحيح.
        if (widget.patientId != null)
          PatientChartHeaderLoader(patientId: widget.patientId!),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'أنشئ طلب الجلسات من تفاصيل الزيارة التي اتُّخذ فيها القرار. لكل جلسة سجل ونتيجة ودفع مستقل.',
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: AppSearchField(
                        hint: 'بحث باسم المريض أو الخدمة أو التشخيص',
                        onChanged: (v) => setState(() => _query = v.trim()),
                      ),
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
                const SizedBox(height: 12),
                Expanded(
                  child: FutureBuilder<List<Map<String, Object?>>>(
                    future: _rows,
                    builder: (context, s) {
                      if (s.hasError) {
                        return Center(child: Text('تعذّر التحميل: ${s.error}'));
                      }
                      if (!s.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final rows = s.data!
                          .where(_matchesService)
                          .where(
                            (r) =>
                                '${r['full_name']} ${r['service_name']} ${r['diagnosis']} ${r['result']}'
                                    .contains(_query),
                          )
                          .toList();
                      if (rows.isEmpty) {
                        final hint = widget.serviceFilter == 'ems'
                            ? 'لا جلسات باسم خدمة يحتوي على EMS. السجلات القديمة لم تُعاد تسميتها.'
                            : widget.serviceFilter == 'traction'
                            ? 'لا جلسات باسم خدمة يحتوي على سحب أو فقر. السجلات القديمة لم تُعاد تسميتها.'
                            : 'لا توجد جلسات مستقلة مطابقة. الزيارات والسجلات القديمة محفوظة في الملف.';
                        return Center(child: Text(hint));
                      }
                      return SingleChildScrollView(
                        child: DayGroups<Map<String, Object?>>(
                          items: rows,
                          dateOf: (r) => DateFmt.parse(
                            (r['performed_on'] ??
                                    r['scheduled_on'] ??
                                    r['ordered_at'])
                                as String?,
                          ),
                          searching: _query.isNotEmpty,
                          noun: 'جلسة',
                          groupBuilder: (group) => Column(
                            children: [
                              for (final r in group)
                                HoverCard(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        PatientLink(
                                          patientId: r['patient_id'] as int,
                                          name: r['full_name'] as String,
                                        ),
                                        Text(
                                          '${r['service_name']} • ${r['sequence_no']} / ${r['planned_count']}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 17,
                                          ),
                                        ),
                                        Text(
                                          '${sessionStatuses[r['status']]} • المنفذ من الطلب: ${r['completed_count']} / ${r['planned_count']}',
                                        ),
                                        if ((r['diagnosis'] as String?)
                                                ?.isNotEmpty ==
                                            true)
                                          Text('التشخيص: ${r['diagnosis']}'),
                                        if ((r['result'] as String?)
                                                ?.isNotEmpty ==
                                            true)
                                          Text('النتيجة: ${r['result']}'),
                                        Align(
                                          alignment:
                                              AlignmentDirectional.centerEnd,
                                          child: Wrap(
                                            alignment: WrapAlignment.end,
                                            spacing: 10,
                                            children: [
                                              OutlinedButton(
                                                onPressed: () => _edit(r),
                                                child: const Text(
                                                  'تفاصيل ونتائج الجلسة',
                                                ),
                                              ),
                                              TextButton(
                                                onPressed: () => Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        VisitDetailScreen(
                                                          visitId:
                                                              r['source_visit_id']
                                                                  as int,
                                                        ),
                                                  ),
                                                ),
                                                child: const Text(
                                                  'زيارة الطلب',
                                                ),
                                              ),
                                              PayToggle(
                                                key: ValueKey(
                                                  'pay-s${r['id']}',
                                                ),
                                                paid: r['payment_id'] != null,
                                                enabled:
                                                    r['status'] != 'cancelled',
                                                tooltip:
                                                    'دفع أجر الجلسة (${fmtMoney(r['price'])})',
                                                onPay: () => _pay(r),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
