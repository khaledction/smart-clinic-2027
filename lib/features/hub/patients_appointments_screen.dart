import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_sizes.dart';
import '../../core/utils/date_fmt.dart';
import '../../core/utils/neuro_constants.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/date_input.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/form_fields.dart';
import '../../core/widgets/paid_widgets.dart';
import '../../core/widgets/search_field.dart';
import '../../core/widgets/section_card.dart';
import '../../core/widgets/status_chip.dart';
import '../../data/models/appointment.dart';
import '../../data/models/patient.dart';
import '../../data/providers/appointments_provider.dart';
import '../../data/providers/patients_provider.dart';
import '../../data/providers/session_provider.dart';
import '../../data/repositories/clinic_flow_repository.dart';
import '../../data/repositories/patient_repository.dart';
import '../../data/repositories/treatment_repository.dart';
import '../patients/patient_detail_screen.dart';
import '../visits/visit_detail_screen.dart';
import '../patients/patient_form_screen.dart';
import '../visits/visit_form_screen.dart';

const _checkupColor = AppColors.primary;
const _sessionColor = AppColors.accent;
const _unknownColor = AppColors.warning;

/// باب موحّد: المرضى + المواعيد في شاشة واحدة بنقرات قليلة.
/// النقر على المريض يبدأ زيارة جديدة (للطبيب)؛ زر الملف يفتح السجل.
/// المواعيد والمنجزة مقسومة: معاينات • جلسات • (غير محدد للسجلات القديمة).
class PatientsAppointmentsScreen extends StatefulWidget {
  const PatientsAppointmentsScreen({super.key});

  @override
  State<PatientsAppointmentsScreen> createState() =>
      _PatientsAppointmentsScreenState();
}

class _PatientsAppointmentsScreenState
    extends State<PatientsAppointmentsScreen> {
  final _search = TextEditingController();
  final _apptSearch = TextEditingController();
  final _apptSearchFocus = FocusNode();
  final _patientRepo = PatientRepository();
  String _apptQuery = '';

  // ---- نموذج الموعد المدمج
  List<Patient> _options = [];
  int? _formPatientId;
  String? _formPatientName;
  DateTime? _formDate;
  TimeOfDay _formTime = const TimeOfDay(hour: 9, minute: 0);
  int _formDuration = 20;
  String? _formKind;
  String? _formSessionName;
  bool _formSaving = false;
  String? _formError;

  bool get _isDoctor => context.read<SessionProvider>().user?.isDoctor == true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<PatientsProvider>().load();
      context.read<AppointmentsProvider>().load();
      _loadOptions();
    });
  }

  Future<void> _loadOptions() async {
    final list = await _patientRepo.search(query: '', limit: 500);
    if (mounted) {
      setState(() {
        _options = list;
      });
    }
  }

  @override
  void dispose() {
    _search.dispose();
    _apptSearch.dispose();
    _apptSearchFocus.dispose();
    super.dispose();
  }

  void _snack(String message, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  Future<void> _startVisit(Patient p) async {
    if (!_isDoctor) {
      _snack('بدء الزيارة متاح للطبيب فقط');
      return;
    }
    if (!p.isActive) {
      _snack('الملف مؤرشف — أعد تفعيله أولاً');
      return;
    }
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            VisitFormScreen(patientId: p.id!, patientName: p.fullName),
      ),
    );
    if (saved == true && mounted) {
      await context.read<AppointmentsProvider>().load();
      _snack('حُفظت الزيارة', color: AppColors.success);
    }
  }

  Future<void> _openFile(Patient p) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PatientDetailScreen(patientId: p.id!, name: p.fullName),
      ),
    );
    if (!mounted) return;
    await context.read<PatientsProvider>().load();
    if (!mounted) return;
    await context.read<AppointmentsProvider>().load();
    await _loadOptions();
  }

  Future<void> _patientForm({Patient? patient}) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => PatientFormScreen(patient: patient)),
    );
    if (changed == true && mounted) {
      await context.read<PatientsProvider>().load();
      await _loadOptions();
    }
  }

  void _prefillAppointment(Patient p) {
    setState(() {
      _formPatientId = p.id;
      _formPatientName = p.fullName;
      _formError = null;
    });
  }

  Future<void> _saveAppointment() async {
    if (_formPatientId == null) {
      setState(() => _formError = 'اختر المريض أولاً');
      return;
    }
    // نوع الزيارة ونوع الجلسة اختياريان: بدون نوع يظهر الموعد في «غير محدد»
    // ويمكن تحديده لاحقاً من «تعديل الموعد».
    final day = context.read<AppointmentsProvider>().day;
    final date = _formDate ?? day;
    setState(() {
      _formSaving = true;
      _formError = null;
    });
    final error = await context.read<AppointmentsProvider>().add(
      Appointment(
        patientId: _formPatientId!,
        startAt: DateTime(
          date.year,
          date.month,
          date.day,
          _formTime.hour,
          _formTime.minute,
        ),
        durationMin: _formDuration,
        kind: _formKind,
        sessionName: _formKind == 'session' ? _formSessionName : null,
      ),
    );
    if (!mounted) return;
    setState(() {
      _formSaving = false;
      _formError = error;
      if (error == null) {
        _formPatientId = null;
        _formPatientName = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final patients = context.watch<PatientsProvider>();
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 980;
        final patientsCard = _patientsPanel(patients);
        final appointmentsCard = _appointmentsPanel();
        if (!wide) {
          return SingleChildScrollView(
            key: const Key('hubScroll'),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                patientsCard,
                const SizedBox(height: 16),
                appointmentsCard,
              ],
            ),
          );
        }
        return SingleChildScrollView(
          key: const Key('hubScroll'),
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 5, child: patientsCard),
              const SizedBox(width: 16),
              Expanded(flex: 6, child: appointmentsCard),
            ],
          ),
        );
      },
    );
  }

  // ------------------------------------------------------------------ المرضى
  Widget _patientsPanel(PatientsProvider patients) => SectionCard(
    title: 'المرضى (${patients.total})',
    icon: Icons.people_outline,
    child: Column(
      children: [
        LayoutBuilder(
          builder: (context, c) {
            final field = AppSearchField(
              controller: _search,
              onChanged: patients.setQuery,
              hint: 'بحث بالاسم أو الهاتف أو رقم الملف…',
            );
            // زر كبير بعرض قائمة المرضى نفسها.
            final add = SizedBox(
              height: 50,
              child: FilledButton.icon(
                key: const Key('addPatient'),
                onPressed: () => _patientForm(),
                icon: const Icon(Icons.person_add_alt_1_outlined, size: 22),
                label: const Text(
                  'إضافة مريض جديد',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                add,
                const SizedBox(height: AppSizes.gap),
                field,
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        const Align(
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            'النقر على المريض يبدأ زيارة جديدة • زر الملف يفتح السجل',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 520,
          child: patients.loading && patients.items.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : patients.items.isEmpty
              ? const EmptyState(
                  message: 'لا يوجد مرضى مطابقون',
                  icon: Icons.person_search_outlined,
                )
              : ListView.separated(
                  itemCount: patients.items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final p = patients.items[i];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      hoverColor: AppColors.hoverTint,
                      onTap: () => _startVisit(p),
                      leading: CircleAvatar(
                        radius: 17,
                        backgroundColor: p.isActive
                            ? const Color(0xFFE2F1F4)
                            : Colors.grey.shade300,
                        child: Text(
                          p.fullName.isNotEmpty ? p.fullName[0] : '؟',
                          style: const TextStyle(
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      title: Text(
                        p.fullName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        'ملف ${p.fileNo ?? p.id} • ${p.phone ?? 'بدون هاتف'}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'حجز موعد',
                            icon: const Icon(
                              Icons.event_available_outlined,
                              size: 20,
                            ),
                            onPressed: () => _prefillAppointment(p),
                          ),
                          IconButton(
                            tooltip: 'فتح الملف',
                            mouseCursor: SystemMouseCursors.click,
                            icon: const Icon(
                              Icons.folder_open_outlined,
                              size: 20,
                            ),
                            onPressed: () => _openFile(p),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        if (patients.hasMore)
          TextButton(
            onPressed: patients.loading ? null : patients.loadMore,
            child: const Text('تحميل المزيد'),
          ),
      ],
    ),
  );

  // ----------------------------------------------------------------- المواعيد
  bool _matches(Appointment a) {
    final q = _apptQuery;
    if (q.isEmpty) return true;
    return (a.patientName ?? '').contains(q) ||
        a.kindLabel.contains(q) ||
        (a.reason ?? '').contains(q);
  }

  Widget _dayNavigation(AppointmentsProvider provider) {
    ButtonStyle iconStyle() => IconButton.styleFrom(
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      minimumSize: const Size(32, 32),
      padding: EdgeInsets.zero,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'اليوم السابق',
          iconSize: 20,
          style: iconStyle(),
          icon: const Icon(Icons.chevron_right_rounded),
          onPressed: () =>
              provider.goToDay(provider.day.subtract(const Duration(days: 1))),
        ),
        TextButton(
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: const Size(0, 32),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onPressed: () => provider.goToToday(),
          child: const Text('اليوم'),
        ),
        IconButton(
          tooltip: 'اليوم التالي',
          iconSize: 20,
          style: iconStyle(),
          icon: const Icon(Icons.chevron_left_rounded),
          onPressed: () =>
              provider.goToDay(provider.day.add(const Duration(days: 1))),
        ),
      ],
    );
  }

  Widget _appointmentsPanel() {
    final provider = context.watch<AppointmentsProvider>();
    final checkups = provider.pendingOf('checkup').where(_matches).toList();
    final sessions = provider.pendingOf('session').where(_matches).toList();
    final unknown = provider.pendingOf(null).where(_matches).toList();
    final closed = provider.items
        .where(
          (a) =>
              (a.status == 'cancelled' || a.status == 'no_show') && _matches(a),
        )
        .toList();
    final nothing =
        checkups.isEmpty &&
        sessions.isEmpty &&
        unknown.isEmpty &&
        closed.isEmpty;
    return Column(
      children: [
        SectionCard(
          title: 'مواعيد ${DateFmt.describe(provider.day)}',
          icon: Icons.calendar_month_outlined,
          trailing: _dayNavigation(provider),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: AppSearchField(
                      fieldKey: const Key('apptSearch'),
                      controller: _apptSearch,
                      focusNode: _apptSearchFocus,
                      onChanged: (v) => setState(() => _apptQuery = v.trim()),
                      hint: 'بحث في مواعيد اليوم بالاسم أو النوع…',
                      showIcon: false,
                      suffixIcon: _apptQuery.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'مسح البحث',
                              icon: const Icon(Icons.close, size: 17),
                              onPressed: () => setState(() {
                                _apptSearch.clear();
                                _apptQuery = '';
                              }),
                            ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // زر البحث على اليسار بارتفاع مربع البحث نفسه.
                  SizedBox.square(
                    dimension: AppSizes.control,
                    child: IconButton.filled(
                      tooltip: 'بحث',
                      padding: EdgeInsets.zero,
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.navy,
                        foregroundColor: Colors.white,
                        shape: const CircleBorder(),
                      ),
                      icon: const Icon(Icons.search, size: 20),
                      onPressed: () {
                        setState(() => _apptQuery = _apptSearch.text.trim());
                        _apptSearchFocus.requestFocus();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (provider.loading && provider.items.isEmpty)
                const SizedBox(
                  height: 120,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (nothing && _apptQuery.isNotEmpty)
                const EmptyState(
                  message: 'لا توجد مواعيد مطابقة للبحث',
                  icon: Icons.event_busy_outlined,
                )
              else ...[
                _ApptGroup(
                  title: 'مواعيد المعاينات',
                  icon: Icons.medical_services_outlined,
                  color: _checkupColor,
                  empty: 'لا توجد مواعيد معاينات',
                  children: [for (final a in checkups) _appointmentRow(a)],
                ),
                const SizedBox(height: 12),
                _ApptGroup(
                  title: 'مواعيد الجلسات',
                  icon: Icons.bolt_outlined,
                  color: _sessionColor,
                  empty: 'لا توجد مواعيد جلسات',
                  children: [for (final a in sessions) _appointmentRow(a)],
                ),
                if (unknown.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _ApptGroup(
                    title: 'غير محدد',
                    subtitle: 'مواعيد قديمة — حدّد نوعها من «تعديل الموعد»',
                    icon: Icons.help_outline,
                    color: _unknownColor,
                    empty: '',
                    children: [for (final a in unknown) _appointmentRow(a)],
                  ),
                ],
                if (closed.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _ApptGroup(
                    title: 'ملغاة أو لم يحضر',
                    icon: Icons.event_busy_outlined,
                    color: AppColors.textSecondary,
                    empty: '',
                    children: [for (final a in closed) _appointmentRow(a)],
                  ),
                ],
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        _appointmentForm(provider),
        const SizedBox(height: 16),
        _DoneCard(day: provider.day, revision: provider.revision),
      ],
    );
  }

  Widget _appointmentRow(Appointment a) {
    final pending = a.status == 'scheduled' || a.status == 'arrived';
    final name = InkWell(
      borderRadius: BorderRadius.circular(6),
      hoverColor: AppColors.hoverTint,
      highlightColor: AppColors.hoverTint,
      onTap: a.patientName == null
          ? null
          : () =>
                _startVisit(Patient(id: a.patientId, fullName: a.patientName!)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 6),
        child: Text(
          a.patientName ?? '—',
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        name,
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 6),
          child: Text(
            [
              a.kindLabel,
              if (a.status == 'arrived') 'وصل',
              if (!pending) a.statusLabel,
              if (a.reason?.trim().isNotEmpty == true) a.reason!.trim(),
            ].join(' • '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
    Widget? primary;
    if (pending && a.kind != null) {
      primary = SizedBox(
        height: AppSizes.rowAction,
        child: FilledButton.icon(
          onPressed: () => _markDone(a),
          icon: const Icon(Icons.check_circle_outline, size: 17),
          label: Text(a.isSession ? 'تمت الجلسة' : 'تمت الزيارة'),
        ),
      );
    } else if (pending) {
      primary = SizedBox(
        height: AppSizes.rowAction,
        child: OutlinedButton(
          onPressed: () => _editAppointment(a),
          child: const Text('حدّد النوع'),
        ),
      );
    }
    final menu = PopupMenuButton<String>(
      tooltip: 'خيارات الموعد',
      icon: const Icon(Icons.more_vert, size: 19),
      onSelected: (value) => _appointmentAction(a, value),
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'edit', child: Text('تعديل الموعد')),
        const PopupMenuItem(value: 'move', child: Text('نقل إلى يوم آخر')),
        const PopupMenuItem(value: 'file', child: Text('فتح الملف')),
        ...NeuroConstants.appointmentStatuses.entries
            .where((e) => e.key != 'done' && e.key != a.status)
            .map(
              (e) => PopupMenuItem(
                value: e.key,
                child: Text('الحالة: ${e.value}'),
              ),
            ),
        const PopupMenuItem(value: 'delete', child: Text('حذف الموعد')),
      ],
    );
    return LayoutBuilder(
      builder: (context, c) {
        final time = SizedBox(
          width: 50,
          child: Text(
            DateFmt.time(a.startAt),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
        );
        if (c.maxWidth < 400) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    time,
                    Expanded(child: info),
                    menu,
                  ],
                ),
                if (primary != null)
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: primary,
                  ),
              ],
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              time,
              Expanded(child: info),
              if (primary != null) ...[const SizedBox(width: 8), primary],
              menu,
            ],
          ),
        );
      },
    );
  }

  Future<void> _markDone(Appointment a) async {
    try {
      await context.read<AppointmentsProvider>().markDone(a.id!);
      _snack(
        a.isSession
            ? 'تم وضع علامة «تمت الجلسة» — انتقلت إلى الجلسات المنجزة'
            : 'تم وضع علامة «تمت الزيارة» — انتقلت إلى المعاينات المنجزة',
        color: AppColors.success,
      );
    } on StateError catch (e) {
      _snack(e.message, color: AppColors.danger);
    }
  }

  Future<void> _appointmentAction(Appointment a, String value) async {
    final provider = context.read<AppointmentsProvider>();
    if (value == 'edit') {
      await _editAppointment(a);
    } else if (value == 'move') {
      await _moveAppointment(a, provider);
    } else if (value == 'file') {
      if (a.patientName == null) return;
      await _openFile(Patient(id: a.patientId, fullName: a.patientName!));
    } else if (value == 'delete') {
      final ok = await ConfirmDialog.show(
        context,
        title: 'حذف الموعد',
        message: 'هل تريد حذف موعد ${a.patientName}؟',
        confirmLabel: 'حذف',
        destructive: true,
      );
      if (ok && mounted) await provider.remove(a.id!);
    } else {
      await provider.setStatus(a.id!, value);
    }
  }

  Future<void> _editAppointment(Appointment a) async {
    final provider = context.read<AppointmentsProvider>();
    var day = DateTime(a.startAt.year, a.startAt.month, a.startAt.day);
    var time = TimeOfDay(hour: a.startAt.hour, minute: a.startAt.minute);
    var duration = a.durationMin;
    var kind = a.kind;
    var sessionName = NeuroConstants.sessionOptions.contains(a.sessionName)
        ? a.sessionName
        : null;
    // الموعد المرتبط بجلسة مجدولة لا يغيّر نوعه (يبقى متسقاً مع الجلسة).
    final locked = a.sessionId != null || a.visitId != null;
    String? error;
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text('تعديل موعد ${a.patientName ?? ''}'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _KindPicker(
                    kind: kind,
                    sessionName: sessionName,
                    enabled: !locked,
                    onKind: (k) => setDialog(() {
                      kind = k;
                      error = null;
                    }),
                    onSessionName: (s) => setDialog(() => sessionName = s),
                  ),
                  const SizedBox(height: 12),
                  AppDateField(
                    label: 'التاريخ',
                    value: day,
                    onChanged: (d) => setDialog(() {
                      if (d != null) day = d;
                    }),
                  ),
                  const SizedBox(height: 12),
                  AppTimeField(
                    label: 'الوقت',
                    value: time,
                    onChanged: (t) => setDialog(() {
                      if (t != null) time = t;
                    }),
                  ),
                  const SizedBox(height: 12),
                  AppDropdownField<int>(
                    label: 'المدة (دقيقة)',
                    value: duration,
                    items: _durations(duration),
                    onChanged: (v) => setDialog(() => duration = v ?? duration),
                  ),
                  if (a.reason?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 10),
                    Text(
                      'السبب المسجّل سابقاً: ${a.reason!.trim()}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      error!,
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx, true);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    if (saved != true || !mounted) return;
    try {
      await provider.update(
        Appointment(
          id: a.id,
          patientId: a.patientId,
          startAt: DateTime(
            day.year,
            day.month,
            day.day,
            time.hour,
            time.minute,
          ),
          durationMin: duration,
          status: a.status,
          reason: a.reason,
          createdAt: a.createdAt,
          kind: locked ? a.kind : kind,
          sessionName: locked
              ? a.sessionName
              : (kind == 'session' ? sessionName : null),
          sessionId: a.sessionId,
          visitId: a.visitId,
        ),
      );
    } on StateError catch (e) {
      _snack(e.message);
    }
  }

  Future<void> _moveAppointment(
    Appointment a,
    AppointmentsProvider provider,
  ) async {
    final picked = await showAppDatePicker(
      context,
      initialDate: a.startAt,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'نقل الموعد إلى يوم آخر',
    );
    if (picked == null || !mounted) return;
    try {
      await provider.update(
        a.copyWith(
          startAt: DateTime(
            picked.year,
            picked.month,
            picked.day,
            a.startAt.hour,
            a.startAt.minute,
          ),
        ),
      );
      _snack(
        'تم نقل الموعد إلى ${DateFmt.describe(DateTime(picked.year, picked.month, picked.day))}',
      );
      await provider.goToDay(picked);
    } on StateError catch (e) {
      _snack(e.message);
    }
  }

  static List<DropdownMenuItem<int>> _durations(int current) => {
    10,
    15,
    20,
    30,
    45,
    60,
    current,
  }.map((e) => DropdownMenuItem(value: e, child: Text('$e'))).toList();

  Widget _appointmentForm(AppointmentsProvider provider) => SectionCard(
    title: 'موعد جديد',
    icon: Icons.event_available_outlined,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_formPatientName != null)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Chip(
              label: Text(_formPatientName!),
              deleteIcon: const Icon(Icons.close, size: 17),
              onDeleted: () => setState(() {
                _formPatientId = null;
                _formPatientName = null;
              }),
            ),
          )
        else
          DropdownButtonFormField<int>(
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'المريض *'),
            items: _options
                .map(
                  (p) => DropdownMenuItem(
                    value: p.id,
                    child: Text(
                      '${p.fileNo ?? ''} — ${p.fullName}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() {
              _formPatientId = v;
              _formPatientName = null;
            }),
            validator: (v) => v == null ? 'مطلوب' : null,
          ),
        const SizedBox(height: 12),
        _KindPicker(
          kind: _formKind,
          sessionName: _formSessionName,
          onKind: (k) => setState(() {
            _formKind = k;
            _formError = null;
          }),
          onSessionName: (s) => setState(() => _formSessionName = s),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final dateField = AppDateField(
              label: 'التاريخ',
              value: _formDate ?? provider.day,
              onChanged: (d) =>
                  setState(() => _formDate = d ?? _formDate ?? provider.day),
            );
            final timeField = AppTimeField(
              label: 'الوقت',
              value: _formTime,
              onChanged: (t) => setState(() => _formTime = t ?? _formTime),
            );
            final durationField = AppDropdownField<int>(
              label: 'المدة',
              value: _formDuration,
              items: _durations(_formDuration),
              onChanged: (v) => setState(() => _formDuration = v ?? 20),
            );
            if (constraints.maxWidth < 560) {
              return Column(
                children: [
                  dateField,
                  const SizedBox(height: 12),
                  timeField,
                  const SizedBox(height: 12),
                  durationField,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: dateField),
                const SizedBox(width: 12),
                Expanded(child: timeField),
                const SizedBox(width: 12),
                Expanded(child: durationField),
              ],
            );
          },
        ),
        if (_formError != null) ...[
          const SizedBox(height: 8),
          Text(
            _formError!,
            style: const TextStyle(color: AppColors.danger, fontSize: 12.5),
          ),
        ],
        const SizedBox(height: 12),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: SizedBox(
            height: AppSizes.control,
            child: FilledButton.icon(
              onPressed: _formSaving ? null : _saveAppointment,
              icon: const Icon(Icons.save_outlined, size: 17),
              label: Text(_formSaving ? 'جارٍ الحفظ…' : 'حفظ الموعد'),
            ),
          ),
        ),
      ],
    ),
  );
}

/// اختيار نوع الزيارة (معاينة / جلسة) ونوع الجلسة عند اختيار «جلسة».
class _KindPicker extends StatelessWidget {
  const _KindPicker({
    required this.kind,
    required this.sessionName,
    required this.onKind,
    required this.onSessionName,
    this.enabled = true,
  });

  final String? kind;
  final String? sessionName;
  final ValueChanged<String> onKind;
  final ValueChanged<String?> onSessionName;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final segments = SizedBox(
      height: AppSizes.control,
      child: SegmentedButton<String>(
        key: const Key('apptKind'),
        emptySelectionAllowed: true,
        showSelectedIcon: false,
        segments: [
          for (final e in NeuroConstants.appointmentKinds.entries)
            ButtonSegment(
              value: e.key,
              label: Text(e.value),
              icon: Icon(
                e.key == 'session'
                    ? Icons.bolt_outlined
                    : Icons.medical_services_outlined,
                size: 17,
              ),
            ),
        ],
        selected: {if (kind != null) kind!},
        onSelectionChanged: enabled
            ? (s) {
                if (s.isNotEmpty) onKind(s.first);
              }
            : null,
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'نوع الزيارة',
          style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 6),
        segments,
        if (kind == 'session') ...[
          const SizedBox(height: 12),
          AppDropdownField<String>(
            label: 'نوع الجلسة',
            value: NeuroConstants.sessionOptions.contains(sessionName)
                ? sessionName
                : null,
            enabled: enabled,
            items: NeuroConstants.sessionOptions
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: onSessionName,
          ),
        ],
      ],
    );
  }
}

/// مجموعة مواعيد بعنوان ولون ثابتين (معاينات / جلسات / غير محدد).
class _ApptGroup extends StatelessWidget {
  const _ApptGroup({
    required this.title,
    required this.icon,
    required this.color,
    required this.empty,
    required this.children,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final String empty;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(10),
              ),
              border: BorderDirectional(
                start: BorderSide(color: color, width: 3),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 17, color: color),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                      color: color == AppColors.warning
                          ? const Color(0xFF8A6200)
                          : color,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                StatusChip(label: '${children.length}', color: color),
              ],
            ),
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
              child: Text(
                subtitle!,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: children.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      empty,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < children.length; i++) ...[
                        if (i > 0) const Divider(height: 1),
                        children[i],
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// المنجزة في اليوم المعروض: المعاينات المنجزة + الجلسات المنجزة مع الدفع.
class _DoneCard extends StatefulWidget {
  const _DoneCard({required this.day, required this.revision});

  final DateTime day;
  final int revision;

  @override
  State<_DoneCard> createState() => _DoneCardState();
}

class _DoneCardState extends State<_DoneCard> {
  final _flow = ClinicFlowRepository();
  DoneDay? _data;
  Map<String, double> _prices = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _DoneCard old) {
    super.didUpdateWidget(old);
    if (old.revision != widget.revision || old.day != widget.day) _load();
  }

  Future<void> _load() async {
    final data = await _flow.doneOn(widget.day);
    final prices = await _flow.prices();
    if (!mounted) return;
    setState(() {
      _data = data;
      _prices = prices;
    });
  }

  String _money(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  /// يسجّل الدفع مباشرة بسعر الإعدادات (زر «دفع» يتحول للأخضر).
  /// التكرار ممنوع في الزر نفسه وفي قاعدة البيانات.
  Future<bool> _pay(DoneItem item) async {
    final price = item.isSession
        ? (_prices[item.label] ?? 0)
        : (_prices['checkup'] ?? 0);
    final what = item.isSession ? 'أجر ${item.label}' : 'أجر المعاينة';
    if (price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            item.isSession
                ? 'حدّد سعر «${item.label}» في الإعدادات ← الزيارة والمعاينة أولاً'
                : 'حدّد سعر المعاينة في الإعدادات ← الزيارة والمعاينة أولاً',
          ),
        ),
      );
      return false;
    }
    var ok = false;
    try {
      if (item.isSession) {
        await TreatmentRepository().paySession(item.sessionId!);
      } else {
        await TreatmentRepository().payVisit(item.visitId!);
      }
      ok = true;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'سُجّل $what (${_money(price)}) من ${item.patientName} في المالية',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } on StateError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      await _load();
    }
    return ok;
  }

  Future<void> _open(DoneItem item) async {
    if (item.visitId != null && !item.isSession) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VisitDetailScreen(visitId: item.visitId!),
        ),
      );
    } else {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PatientDetailScreen(
            patientId: item.patientId,
            name: item.patientName,
          ),
        ),
      );
    }
    await _load();
  }

  Widget _row(DoneItem item) {
    Widget action;
    if (!item.isPaid && !item.payable) {
      action = const Text(
        'الدفع من المالية',
        style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
      );
    } else {
      action = PayToggle(
        key: ValueKey(
          'pay-${item.isSession ? 's${item.sessionId}' : 'v${item.visitId}'}',
        ),
        paid: item.isPaid,
        paidLabel: item.isPaid
            ? 'مدفوع ${_money(item.paidAmount!)}'
            : 'تم الدفع',
        tooltip: item.isSession ? 'دفع أجر الجلسة' : 'دفع أجر المعاينة',
        onPay: () => _pay(item),
      );
    }
    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          item.patientName,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        Text(
          [
            item.label,
            if (item.note?.trim().isNotEmpty == true) item.note!.trim(),
          ].join(' • '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
    final open = IconButton(
      tooltip: item.isSession ? 'فتح ملف المريض' : 'فتح الزيارة',
      icon: const Icon(Icons.open_in_new, size: 18),
      onPressed: () => _open(item),
    );
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 400) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: info),
                    open,
                  ],
                ),
                Align(alignment: AlignmentDirectional.centerEnd, child: action),
              ],
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(child: info),
              const SizedBox(width: 8),
              action,
              open,
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return SectionCard(
      title: 'المنجزة ${DateFmt.describe(widget.day)}',
      icon: Icons.task_alt_outlined,
      child: data == null
          ? const SizedBox(
              height: 80,
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ApptGroup(
                  title: 'المعاينات المنجزة',
                  icon: Icons.medical_services_outlined,
                  color: _checkupColor,
                  empty: 'لا توجد معاينات منجزة',
                  children: [for (final i in data.checkups) _row(i)],
                ),
                const SizedBox(height: 12),
                _ApptGroup(
                  title: 'الجلسات المنجزة',
                  icon: Icons.bolt_outlined,
                  color: _sessionColor,
                  empty: 'لا توجد جلسات منجزة',
                  children: [for (final i in data.sessions) _row(i)],
                ),
              ],
            ),
    );
  }
}
