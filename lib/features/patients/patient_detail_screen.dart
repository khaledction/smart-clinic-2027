import '../../core/widgets/section_navigator.dart';
import '../sessions/sessions_screen.dart';
import '../investigations/investigations_screen.dart';
import '../../core/widgets/day_groups.dart';

import 'package:flutter/material.dart';

import 'patient_header.dart';

import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/date_fmt.dart';
import '../../core/widgets/date_input.dart';
import '../../core/utils/neuro_constants.dart';
import '../../data/models/patient.dart';
import '../../data/models/visit.dart';
import '../../data/models/appointment.dart';
import '../../data/providers/session_provider.dart';
import '../../data/repositories/patient_repository.dart';
import '../../data/repositories/visit_repository.dart';
import '../../data/repositories/appointment_repository.dart';
import '../visits/visit_form_screen.dart';
import '../visits/visit_detail_screen.dart';
import 'patient_form_screen.dart';
import 'patient_payments_screen.dart';
import '../../core/widgets/clinic_brand.dart';
import '../../core/widgets/search_field.dart';

/// A longitudinal chart: patient identity, concise context, then dated records.
/// No clinical content is generated or copied into the current examination.
class PatientDetailScreen extends StatefulWidget {
  const PatientDetailScreen({
    super.key,
    required this.patientId,
    required this.name,
  });
  final int patientId;
  final String name;
  @override
  State<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends State<PatientDetailScreen> {
  final _repo = PatientRepository();
  final _visitsRepo = VisitRepository();
  final _search = TextEditingController();
  final _sections = GlobalKey<SectionNavigatorState>();
  Patient? _patient;
  List<Visit> _visits = [];
  List<MedicalHistoryItem> _history = [];
  List<Medication> _medications = [];
  List<Investigation> _investigations = [];
  List<Appointment> _appointments = [];
  String? _error;
  bool _loading = true;
  bool _oldestFirst = false;
  bool get _canRead => context.read<SessionProvider>().user?.isDoctor == true;

  @override
  void initState() {
    super.initState();
    if (_canRead) {
      _load();
    } else {
      _loading = false;
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!_canRead) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<Object?>([
        _repo.byId(widget.patientId),
        _visitsRepo.forPatient(widget.patientId),
        _repo.history(widget.patientId),
        _repo.medications(widget.patientId),
        _repo.investigations(widget.patientId),
        AppointmentRepository().forPatient(widget.patientId),
      ]);
      if (!mounted) return;
      setState(() {
        _patient = results[0] as Patient?;
        _visits = results[1] as List<Visit>;
        _history = results[2] as List<MedicalHistoryItem>;
        _medications = results[3] as List<Medication>;
        _investigations = results[4] as List<Investigation>;
        _appointments = results[5] as List<Appointment>;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'تعذّر تحميل الملف. حاول مرة أخرى.';
        });
      }
    }
  }

  Future<void> _newVisit() async {
    if (_patient == null || !_patient!.isActive || !_canRead) return;
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => VisitFormScreen(
          patientId: widget.patientId,
          patientName: _patient!.fullName,
        ),
      ),
    );
    if (saved == true && mounted) await _load();
  }

  Future<void> _editPatient() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => PatientFormScreen(patient: _patient)),
    );
    if (saved == true && mounted) await _load();
  }

  void _openVisit(Visit v) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => VisitDetailScreen(visitId: v.id!)),
    );
  }

  /// Manual-only clinical entry. Avoid deletes from the longitudinal summary.
  Future<void> _addClinical(String kind) async {
    final title = kind == 'history'
        ? 'إضافة سابقة مرضية'
        : kind == 'medication'
        ? 'إضافة دواء حالي'
        : 'إضافة فحص / تقرير';
    final labels = kind == 'history'
        ? ['الحالة المرضية', 'ملاحظات']
        : kind == 'medication'
        ? ['اسم الدواء', 'الجرعة', 'التكرار']
        : ['اسم الفحص', 'المنطقة / نوع التصوير', 'نتيجة / تقرير الفحص'];
    final controllers = List.generate(
      labels.length,
      (_) => TextEditingController(),
    );
    final key = GlobalKey<FormState>();
    var busy = false;
    String? error;
    DateTime performed = DateTime.now();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, update) => PopScope(
          canPop: !busy,
          child: AlertDialog(
            title: Text(title),
            content: SizedBox(
              width: 460,
              child: SingleChildScrollView(
                child: Form(
                  key: key,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (int i = 0; i < labels.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: TextFormField(
                            controller: controllers[i],
                            enabled: !busy,
                            maxLines:
                                (kind != 'medication' && i == labels.length - 1)
                                ? 4
                                : 1,
                            // لا إدخال إلزامي: كل الحقول اختيارية.
                            decoration: InputDecoration(labelText: labels[i]),
                          ),
                        ),
                      if (kind == 'investigation')
                        OutlinedButton.icon(
                          onPressed: busy
                              ? null
                              : () async {
                                  final date = await showAppDatePicker(
                                    dialogContext,
                                    helpText: 'تاريخ إجراء الفحص',
                                    initialDate: performed,
                                    firstDate: DateTime(1900),
                                    lastDate: DateTime.now(),
                                  );
                                  if (date != null && dialogContext.mounted) {
                                    update(() => performed = date);
                                  }
                                },
                          icon: const Icon(Icons.event_outlined),
                          label: Text(
                            'تاريخ الفحص: ${DateFmt.date(performed)}',
                          ),
                        ),
                      if (kind == 'investigation')
                        const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Text(
                            'توثيق تقرير يدوياً. السجلات السابقة محفوظة كما أُدخلت.',
                          ),
                        ),
                      if (error != null)
                        Text(
                          error!,
                          style: const TextStyle(color: AppColors.danger),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: busy ? null : () => Navigator.pop(dialogContext),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: busy
                    ? null
                    : () async {
                        if (!key.currentState!.validate()) return;
                        // لا شيء مكتوب ← لا يُحفظ سجل فارغ، تُغلق النافذة فقط.
                        if (controllers.every((c) => c.text.trim().isEmpty)) {
                          Navigator.pop(dialogContext);
                          return;
                        }
                        update(() {
                          busy = true;
                          error = null;
                        });
                        try {
                          if (kind == 'history') {
                            await _repo.addHistory(
                              MedicalHistoryItem(
                                patientId: widget.patientId,
                                condition: controllers[0].text.trim(),
                                notes: controllers[1].text.trim(),
                              ),
                            );
                          } else if (kind == 'medication') {
                            await _repo.addMedication(
                              Medication(
                                patientId: widget.patientId,
                                drug: controllers[0].text.trim(),
                                dose: controllers[1].text.trim(),
                                frequency: controllers[2].text.trim(),
                              ),
                            );
                          } else {
                            await _repo.addInvestigation(
                              Investigation(
                                patientId: widget.patientId,
                                kind: controllers[0].text.trim(),
                                bodySite: controllers[1].text.trim(),
                                report: controllers[2].text.trim(),
                                performedOn: performed,
                              ),
                            );
                          }
                          if (dialogContext.mounted) {
                            update(() => busy = false);
                            Navigator.pop(dialogContext);
                          }
                          if (mounted) await _load();
                        } catch (_) {
                          if (dialogContext.mounted) {
                            update(() {
                              busy = false;
                              error = 'تعذّر الحفظ. لم يتم إغلاق الاستمارة.';
                            });
                          }
                        }
                      },
                child: Text(busy ? 'جارٍ الحفظ…' : 'حفظ'),
              ),
            ],
          ),
        ),
      ),
    );
    // Let the dialog's closing transition finish before disposing its fields.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    for (final controller in controllers) {
      controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final allowed = context.watch<SessionProvider>().user?.isDoctor == true;
    return Scaffold(
      backgroundColor: const Color(0xFFF2F6F9),
      appBar: BrandedAppBar(
        title: const Text('الملف الطبي للمريض'),
        actions: [
          if (allowed)
            IconButton(
              tooltip: 'تحديث الملف',
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh),
            ),
          if (allowed)
            PopupMenuButton<String>(
              tooltip: 'خيارات الملف',
              onSelected: (_) => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      PatientPaymentsScreen(patientId: widget.patientId),
                ),
              ),
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'payments',
                  child: Text('دفعات المريض'),
                ),
              ],
            ),
          const SizedBox(width: 12),
        ],
      ),
      body: !allowed
          ? const Center(child: Text('السجل السريري متاح للطبيب فقط'))
          : _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!),
                  TextButton(
                    onPressed: _load,
                    child: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            )
          : _patient == null
          ? const Center(child: Text('لم يُعثر على المريض'))
          : Column(
              children: [
                _identity(),
                Expanded(
                  child: SectionNavigator(
                    key: _sections,
                    sections: [
                      ChartSection(
                        'نظرة عامة',
                        Icons.dashboard_outlined,
                        _overview(),
                      ),
                      ChartSection('سجل الزيارات', Icons.history, _timeline()),
                      ChartSection(
                        'السوابق والأدوية',
                        Icons.medical_information_outlined,
                        Column(
                          children: [
                            _historyCard(),
                            const SizedBox(height: 16),
                            _medicationCard(),
                          ],
                        ),
                      ),
                      ChartSection(
                        'الفحوص والنتائج',
                        Icons.biotech,
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'التحاليل والأشعة والتقارير مستقلة عن الجلسات. السجلات السابقة محفوظة كما أُدخلت.',
                            ),
                            OutlinedButton.icon(
                              onPressed: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => InvestigationsScreen(
                                      patientId: widget.patientId,
                                    ),
                                  ),
                                );
                                if (mounted) _load();
                              },
                              icon: const Icon(Icons.folder_open),
                              label: const Text(
                                'إدارة الفحوص والتقارير والمرفقات',
                              ),
                            ),
                            _investigationCard(),
                          ],
                        ),
                      ),
                      ChartSection(
                        'الجلسات والإجراءات',
                        Icons.spa_outlined,
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'طلبات مرتبطة بزيارة القرار، ثم سجل مستقل لكل جلسة. افتح تفاصيل الزيارة لإنشاء طلب جديد.',
                            ),
                            FilledButton.icon(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SessionsScreen(
                                    patientId: widget.patientId,
                                  ),
                                ),
                              ),
                              icon: const Icon(Icons.open_in_new),
                              label: const Text('فتح قسم جلسات المريض'),
                            ),
                          ],
                        ),
                      ),
                      ChartSection(
                        'المواعيد',
                        Icons.calendar_month,
                        _appointmentCard(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _identity() {
    final p = _patient!;
    return PatientChartHeader(
      patient: p,
      visits: _visits,
      actions: [
        OutlinedButton.icon(
          onPressed: _editPatient,
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: const Text('تعديل البيانات'),
        ),
        FilledButton.icon(
          key: const Key('start-patient-visit'),
          onPressed: p.isActive ? _newVisit : null,
          icon: const Icon(Icons.add),
          label: const Text('بدء زيارة جديدة'),
        ),
      ],
    );
  }

  Widget _overview() => LayoutBuilder(
    builder: (context, bounds) {
      final summary = Column(
        children: [
          _lastVisit(),
          const SizedBox(height: 16),
          _timeline(compact: true),
        ],
      );
      final contextCards = Column(
        children: [
          _historyCard(compact: true),
          const SizedBox(height: 16),
          _medicationCard(compact: true),
          const SizedBox(height: 16),
          _card('ملاحظات الملف', Icons.notes_outlined, _body(_patient!.notes)),
        ],
      );
      if (bounds.maxWidth < 1050) {
        return Column(
          children: [summary, const SizedBox(height: 16), contextCards],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 7, child: summary),
          const SizedBox(width: 18),
          Expanded(flex: 4, child: contextCards),
        ],
      );
    },
  );
  Widget _lastVisit() {
    if (_visits.isEmpty) {
      return _card(
        'ابدأ السجل الطبي',
        Icons.medical_information_outlined,
        const Text('لا توجد زيارات. ابدأ الزيارة الأولى من الزر أعلى الملف.'),
      );
    }
    final v = _visits.first;
    return _card(
      'ملخص آخر زيارة • ${DateFmt.date(v.visitDate)}',
      Icons.medical_information_outlined,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _labeled('الشكوى', v.chiefComplaint),
          _labeled('التشخيص', v.diagnosis),
          _labeled('الخطة السابقة', v.plan),
          if (v.followUpDate != null)
            _labeled(
              'المراجعة الموصى بها في تلك الزيارة',
              DateFmt.date(v.followUpDate!),
            ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              onPressed: () => _openVisit(v),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('قراءة الزيارة كاملة'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _timeline({bool compact = false}) {
    final q = _search.text.trim().toLowerCase();
    final filtered = _visits
        .where(
          (v) =>
              '${DateFmt.date(v.visitDate)} ${v.chiefComplaint ?? ""} ${v.diagnosis ?? ""} ${v.icd10 ?? ""} ${v.plan ?? ""} ${v.notes ?? ""}'
                  .toLowerCase()
                  .contains(q),
        )
        .toList();
    final ordered = _oldestFirst ? filtered.reversed.toList() : filtered;
    final displayed = compact ? ordered.take(3).toList() : ordered;
    return _card(
      compact ? 'آخر أحداث السجل' : 'سجل الزيارات • ${filtered.length}',
      Icons.timeline,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!compact) ...[
            AppSearchField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              hint: 'بحث بالتاريخ أو الشكوى أو التشخيص أو الخطة',
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 10,
              children: [
                FilterChip(
                  label: const Text('من الزيارة الأولى'),
                  selected: _oldestFirst,
                  onSelected: (v) => setState(() => _oldestFirst = v),
                ),
                if (_visits.isNotEmpty)
                  TextButton(
                    onPressed: () => _openVisit(_visits.last),
                    child: const Text('فتح الزيارة الأولى'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          if (displayed.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('لا توجد زيارات مطابقة'),
            ),
          DayGroups<Visit>(
            items: displayed,
            dateOf: (v) => v.visitDate,
            noun: 'زيارة',
            searching: q.isNotEmpty,
            oldestFirst: _oldestFirst,
            groupBuilder: (dayVisits) => Column(
              children: [
                for (final v in dayVisits)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFDEE7EE)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _openVisit(v),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                Text(
                                  DateFmt.date(v.visitDate),
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  (v.visitType == 'session'
                                          ? v.sessionName
                                          : null) ??
                                      NeuroConstants.visitTypes[v.visitType] ??
                                      v.visitType,
                                  style: const TextStyle(
                                    color: AppColors.accent,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _labeled('الشكوى', v.chiefComplaint),
                            _labeled('التشخيص', v.diagnosis),
                            const Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: Text(
                                'عرض التفاصيل ←',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (compact)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: () => setState(() {
                  _sections.currentState?.go(1);
                  _search.clear();
                }),
                child: const Text('عرض سجل الزيارات بالكامل'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _historyCard({bool compact = false}) => _card(
    'السوابق المرضية',
    Icons.history_edu_outlined,
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_history.isEmpty) _body(null),
        for (final (i, h) in (compact ? _history.take(4) : _history).indexed)
          _row(
            h.condition.trim().isEmpty ? 'سابقة بدون عنوان' : h.condition,
            h.notes?.isNotEmpty == true
                ? h.notes
                : h.sinceYear == null
                ? null
                : 'منذ ${h.sinceYear}',
            last:
                i ==
                (compact ? _history.take(4).length - 1 : _history.length - 1),
          ),
        if (compact && _history.length > 4)
          TextButton(
            onPressed: () => _sections.currentState?.go(2),
            child: const Text('عرض جميع السوابق'),
          ),
      ],
    ),
    action: _addButton('أضف سابقة', () => _addClinical('history')),
  );
  Widget _medicationCard({bool compact = false}) {
    final active = compact
        ? _medications.where((m) => m.isActive).take(4)
        : _medications;
    return _card(
      compact ? 'الأدوية الحالية' : 'سجل الأدوية',
      Icons.medication_outlined,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (active.isEmpty) _body(null),
          for (final (i, m) in active.indexed)
            _row(
              '${m.drug.trim().isEmpty ? 'دواء بدون اسم' : m.drug}${m.isActive ? "" : " • موقوف"}',
              [
                m.dose,
                m.frequency,
                m.indication,
              ].whereType<String>().where((s) => s.isNotEmpty).join(' • '),
              last: i == active.length - 1,
            ),
          if (compact && _medications.where((m) => m.isActive).length > 4)
            TextButton(
              onPressed: () => _sections.currentState?.go(2),
              child: const Text('عرض جميع الأدوية'),
            ),
        ],
      ),
      action: _addButton('أضف دواء', () => _addClinical('medication')),
    );
  }

  Widget _investigationCard() => _card(
    'الفحوص • إدخال يدوي',
    Icons.biotech_outlined,
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_investigations.isEmpty) const Text('لا توجد فحوص'),
        DayGroups<Investigation>(
          items: _investigations,
          dateOf: (i) => i.performedOn,
          noun: 'فحص',
          groupBuilder: (daySessions) => Column(
            children: [
              for (final i in daySessions)
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text(i.kind.trim().isEmpty ? 'فحص بدون اسم' : i.kind),
                  subtitle: Text(
                    i.performedOn == null
                        ? 'التاريخ غير محدد'
                        : DateFmt.date(i.performedOn!),
                  ),
                  children: [
                    _labeled('المنطقة', i.bodySite),
                    _labeled('الملاحظات', i.report),
                    if (i.attachmentPath?.isNotEmpty == true)
                      _labeled('مسار مرفق سابق', i.attachmentPath),
                  ],
                ),
            ],
          ),
        ),
      ],
    ),
    action: _addButton('أضف فحص', () async {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => InvestigationsScreen(patientId: widget.patientId),
        ),
      );
      if (mounted) _load();
    }),
  );
  Widget _appointmentCard() => _card(
    'مواعيد المريض',
    Icons.calendar_month_outlined,
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_appointments.isEmpty) const Text('لا توجد مواعيد'),
        DayGroups<Appointment>(
          items: _appointments,
          dateOf: (a) => a.startAt,
          noun: 'موعد',
          groupBuilder: (dayAppointments) => Column(
            children: [
              for (final a in dayAppointments)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(DateFmt.dateTime(a.startAt)),
                  subtitle: Text(
                    [
                      a.kindLabel,
                      if (a.reason?.trim().isNotEmpty == true) a.reason!.trim(),
                    ].join(' • '),
                  ),
                  trailing: Text(a.statusLabel),
                ),
            ],
          ),
        ),
      ],
    ),
  );
  Widget _addButton(String label, VoidCallback onPressed) =>
      FilledButton(onPressed: onPressed, child: Text(label));

  Widget _card(String title, IconData icon, Widget child, {Widget? action}) =>
      Card(
        color: AppColors.cardTint,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: AppColors.headerTint,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(icon, size: 20, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (action != null) ...[const SizedBox(width: 8), action],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              child,
            ],
          ),
        ),
      );

  /// Organized divider-separated row for history and medication lists.
  Widget _row(String title, String? subtitle, {bool last = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        if (subtitle?.trim().isNotEmpty == true)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              subtitle!,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.6,
              ),
            ),
          ),
        if (!last) const Divider(height: 18),
      ],
    ),
  );
  Widget _body(String? value) => SelectableText(
    value?.trim().isNotEmpty == true ? value! : 'غير محدد',
    style: const TextStyle(height: 1.7, fontSize: 14),
  );
  Widget _labeled(String label, String? value) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 3),
        _body(value),
      ],
    ),
  );
}
