import '../../core/widgets/section_navigator.dart';
import '../../core/widgets/patient_link.dart';

import 'package:flutter/material.dart';

import '../../data/repositories/treatment_repository.dart';
import '../../core/widgets/paid_widgets.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/date_fmt.dart';
import '../../core/utils/neuro_constants.dart';
import '../../core/widgets/form_fields.dart';
import '../../data/models/visit.dart';
import '../../data/repositories/appointment_repository.dart';
import '../../data/repositories/clinic_flow_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/visit_repository.dart';
import '../../data/repositories/plan_repository.dart';
import 'previous_visit_panel.dart';
import '../../core/widgets/clinic_brand.dart';

/// نموذج زيارة كامل: الشكوى + الفحص العصبي + المقاييس + التشخيص + الوصفة.
class VisitFormScreen extends StatefulWidget {
  const VisitFormScreen({
    super.key,
    required this.patientId,
    required this.patientName,
  });

  final int patientId;
  final String patientName;

  @override
  State<VisitFormScreen> createState() => _VisitFormScreenState();
}

class _VisitFormScreenState extends State<VisitFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repo = VisitRepository();
  final _sections = GlobalKey<SectionNavigatorState>();

  // ---- معلومات الزيارة
  DateTime _date = DateTime.now();
  String _type = 'new';

  /// زر «دفع» في النموذج: يُسجَّل الدفع في المالية لحظة حفظ الزيارة
  /// (أجر المعاينة، أو أجر الجلسة إذا كان نوع الزيارة «جلسة»).
  bool _payOnSave = false;
  String? _payAmount;
  String? _sessionChoice;
  final _sessionOther = TextEditingController();
  final _complaint = TextEditingController();
  final _onset = TextEditingController();
  final _notes = TextEditingController();

  // ---- الفحص العصبي
  String? _consciousness;
  final _gcs = TextEditingController();
  final _orientation = TextEditingController();
  final _speech = TextEditingController();
  String? _speechChoice;
  String? _sensationChoice;
  final _cranial = TextEditingController();
  String? _motor;
  String? _tone;
  String? _reflexes;
  final _sensation = TextEditingController();
  final _coordination = TextEditingController();
  final _gait = TextEditingController();
  final _meningeal = TextEditingController();
  final _findings = TextEditingController();

  // ---- المقاييس
  final List<_ScaleRow> _scales = [];

  // ---- التشخيص والخطة
  String? _icd10;
  final _diagnosis = TextEditingController();
  final _plan = TextEditingController();
  final _followup = TextEditingController(text: '30');

  // ---- تبويب «جلسة»: جلسة لاحقة تظهر في مواعيد الجلسات تلقائياً
  String? _planSession;
  final _planSessionOther = TextEditingController();
  DateTime _sessionDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _sessionTime = const TimeOfDay(hour: 9, minute: 0);
  int _sessionDuration = 20;

  // ---- إجراءات الخطة: تُنشأ عند الحفظ فقط عند اختيارها
  String? _planImaging;
  final _planImagingOther = TextEditingController();
  String? _planConsult;
  final _consultDoctor = TextEditingController();
  final _consultReason = TextEditingController();
  String? _planTransfer;
  final _transferDestination = TextEditingController();
  final _transferReason = TextEditingController();

  // ---- الوصفة
  final List<_PrescriptionRow> _prescriptions = [];

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    SettingsRepository()
        .load()
        .then((s) {
          if (mounted && s.visitDuration > 0) {
            setState(() => _sessionDuration = s.visitDuration);
          }
        })
        .catchError((Object _) {});
  }

  DateTime get _sessionStart => DateTime(
    _sessionDate.year,
    _sessionDate.month,
    _sessionDate.day,
    _sessionTime.hour,
    _sessionTime.minute,
  );

  @override
  void dispose() {
    for (final c in [
      _sessionOther,
      _complaint,
      _onset,
      _notes,
      _gcs,
      _orientation,
      _speech,
      _cranial,
      _sensation,
      _coordination,
      _gait,
      _meningeal,
      _findings,
      _diagnosis,
      _plan,
      _followup,
      _planSessionOther,
      _planImagingOther,
      _consultDoctor,
      _consultReason,
      _transferDestination,
      _transferReason,
    ]) {
      c.dispose();
    }
    for (final s in _scales) {
      s.dispose();
    }
    for (final p in _prescriptions) {
      p.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      _sections.currentState?.openAll();
      return;
    }
    final gcs = int.tryParse(_gcs.text.trim());
    final invalidGcs =
        _gcs.text.trim().isNotEmpty && (gcs == null || gcs < 3 || gcs > 15);
    final invalidScore = _scales.any((s) {
      final value = double.tryParse(s.score.text.trim());
      return s.scale == null ||
          value == null ||
          !value.isFinite ||
          value < 0 ||
          value > NeuroConstants.neuroScales[s.scale]!;
    });
    if (invalidGcs || invalidScore) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تحقق من GCS (3–15) ونتائج المقاييس وحدودها'),
        ),
      );
      return;
    }
    // موعد الجلسة الجديدة يجب ألا يتعارض مع موعد قائم (قبل حفظ أي شيء).
    if (_planSession != null) {
      final conflict = await AppointmentRepository().findConflict(
        _sessionStart,
        _sessionDuration,
      );
      if (conflict != null) {
        if (mounted) {
          _sections.currentState?.openAll();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'موعد الجلسة يتعارض مع موعد ${conflict.patientName ?? ''} '
                'الساعة ${DateFmt.time(conflict.startAt)} — غيّر الوقت في تبويب «جلسة»',
              ),
            ),
          );
        }
        return;
      }
    }
    setState(() => _saving = true);

    try {
      final visit = Visit(
        patientId: widget.patientId,
        visitDate: _date,
        visitType: _type,
        sessionName: _type != 'session' ? null : _sessionChoice,
        chiefComplaint: _complaint.text.trim().isEmpty
            ? null
            : _complaint.text.trim(),
        onsetDuration: _onset.text.trim().isEmpty ? null : _onset.text.trim(),
        diagnosis: _diagnosis.text.trim().isEmpty
            ? null
            : _diagnosis.text.trim(),
        icd10: _icd10,
        plan: _plan.text.trim().isEmpty ? null : _plan.text.trim(),
        followupInDays: int.tryParse(_followup.text.trim()),
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      );

      final exam = NeuroExam(
        consciousness: _consciousness,
        gcs: int.tryParse(_gcs.text.trim()),
        orientation: _orientation.text.trim().isEmpty
            ? null
            : _orientation.text.trim(),
        speech: _speechChoice == 'آخر' && _speech.text.trim().isNotEmpty
            ? 'آخر: ${_speech.text.trim()}'
            : _speechChoice,
        cranialNerves: _cranial.text.trim().isEmpty
            ? null
            : _cranial.text.trim(),
        motorPower: _motor,
        tone: _tone,
        reflexes: _reflexes,
        sensation: _sensation.text.trim().isEmpty
            ? null
            : _sensation.text.trim(),
        coordination: _coordination.text.trim().isEmpty
            ? null
            : _coordination.text.trim(),
        gait: _gait.text.trim().isEmpty ? null : _gait.text.trim(),
        meningeal: _meningeal.text.trim().isEmpty
            ? null
            : _meningeal.text.trim(),
        findings: _findings.text.trim().isEmpty ? null : _findings.text.trim(),
      );

      final scales = _scales
          .where((s) => s.scale != null)
          .map(
            (s) => NeuroScale(
              visitId: 0,
              scale: s.scale!,
              score: double.tryParse(s.score.text.trim()) ?? 0,
              maxScore: NeuroConstants.neuroScales[s.scale],
              recordedAt: DateTime.now(),
            ),
          )
          .toList();

      final prescriptions = _prescriptions
          .where((p) => p.drug.text.trim().isNotEmpty)
          .map(
            (p) => Prescription(
              visitId: 0,
              drug: p.drug.text.trim(),
              dose: p.dose.text.trim().isEmpty ? null : p.dose.text.trim(),
              frequency: p.frequency.text.trim().isEmpty
                  ? null
                  : p.frequency.text.trim(),
              durationDays: int.tryParse(p.duration.text.trim()),
            ),
          )
          .toList();

      final visitId = await _repo.saveFull(
        visit,
        exam: exam,
        scales: scales,
        prescriptions: prescriptions,
      );
      final flow = ClinicFlowRepository();
      int? sessionId;
      // زيارة من نوع «جلسة» = جلسة منفّذة تظهر في الجلسات المنجزة.
      if (_type == 'session' && _sessionChoice != null) {
        sessionId = await flow.recordSessionVisit(
          patientId: widget.patientId,
          visitId: visitId,
          sessionName: _sessionChoice!,
          day: _date,
        );
      }
      // تبويب «جلسة»: جلسة مجدولة + موعد في «مواعيد الجلسات».
      if (_planSession != null) {
        await flow.scheduleSessionFromVisit(
          patientId: widget.patientId,
          visitId: visitId,
          sessionName: _planSession!,
          startAt: _sessionStart,
          durationMin: _sessionDuration,
        );
      }
      await PlanRepository().save(
        patientId: widget.patientId,
        visitId: visitId,
        imagingKind:
            _planImaging == 'آخر' && _planImagingOther.text.trim().isNotEmpty
            ? _planImagingOther.text.trim()
            : _planImaging,
        consultationDoctor: _planConsult == null
            ? null
            : _consultDoctor.text.trim(),
        consultationReason: _planConsult == null
            ? null
            : _consultReason.text.trim(),
        transferTarget: _planTransfer,
        transferDestination: _transferDestination.text.trim(),
        transferReason: _transferReason.text.trim(),
      );
      String? payError;
      if (_payOnSave) {
        try {
          if (_type == 'session') {
            if (sessionId == null) {
              throw StateError('لم تُسجَّل جلسة لهذه الزيارة');
            }
            await TreatmentRepository().paySession(sessionId);
          } else {
            await TreatmentRepository().payVisit(visitId);
          }
        } on StateError catch (e) {
          payError = e.message;
        }
      }
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        if (payError != null) {
          messenger.showSnackBar(
            SnackBar(
              content: Text('حُفظت الزيارة، لكن لم يُسجَّل الدفع: $payError'),
              backgroundColor: AppColors.danger,
            ),
          );
        } else if (_payOnSave) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('حُفظت الزيارة وسُجّل الدفع في المالية'),
              backgroundColor: AppColors.success,
            ),
          );
        }
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذّر حفظ الزيارة: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  /// يتحقق من وجود سعر في الإعدادات ثم يحدد الدفع ليُسجَّل مع الحفظ.
  Future<bool> _markPay() async {
    final messenger = ScaffoldMessenger.of(context);
    if (_type == 'session' && _sessionChoice == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('اختر نوع الجلسة أولاً ثم اضغط «دفع»')),
      );
      return false;
    }
    final prices = await ClinicFlowRepository().prices();
    final price = _type == 'session'
        ? (prices[_sessionChoice] ?? 0)
        : (prices['checkup'] ?? 0);
    if (price <= 0) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _type == 'session'
                ? 'حدّد سعر «$_sessionChoice» في الإعدادات ← الزيارة والمعاينة أولاً'
                : 'حدّد سعر المعاينة في الإعدادات ← الزيارة والمعاينة أولاً',
          ),
        ),
      );
      return false;
    }
    // ملاحظة بجانب الزر بدل رسالة عائمة تغطي أزرار الشريط السفلي.
    setState(() {
      _payOnSave = true;
      _payAmount = price == price.roundToDouble()
          ? price.toStringAsFixed(0)
          : price.toString();
    });
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BrandedAppBar(
        crumb: 'زيارة جديدة',
        title: Row(
          children: [
            const Text('زيارة جديدة — '),
            Flexible(
              child: PatientLink(
                patientId: widget.patientId,
                name: widget.patientName,
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_forward_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: SectionNavigator(
                key: _sections,
                expandAll: true,
                sections: [
                  ChartSection(
                    'مرجع المريض',
                    Icons.history,
                    PreviousVisitPanel(patientId: widget.patientId),
                  ),
                  ChartSection(
                    'الشكوى ومعلومات الزيارة',
                    Icons.assignment_outlined,
                    _buildVisitInfo(),
                  ),
                  ChartSection(
                    'الفحص العصبي',
                    Icons.psychology_outlined,
                    _buildNeuroExam(),
                  ),
                  ChartSection('المقاييس', Icons.straighten, _buildScales()),
                  ChartSection(
                    'التشخيص والخطة',
                    Icons.fact_check_outlined,
                    _buildDiagnosis(),
                  ),
                  ChartSection('جلسة', Icons.bolt_outlined, _buildSession()),
                  ChartSection(
                    'الوصفة الطبية',
                    Icons.medication_outlined,
                    _buildPrescription(),
                  ),
                ],
              ),
            ),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(_saving ? 'جارٍ الحفظ…' : 'حفظ الزيارة'),
                  ),
                  const SizedBox(width: 12),
                  PayToggle(
                    key: const Key('visitFormPay'),
                    paid: false,
                    enabled: !_saving,
                    paidLabel: 'تم الدفع',
                    tooltip: _type == 'session'
                        ? 'دفع أجر الجلسة — يُسجَّل عند حفظ الزيارة'
                        : 'دفع أجر المعاينة — يُسجَّل عند حفظ الزيارة',
                    repeatMessage:
                        'الدفع محدد مسبقاً لهذه الزيارة، وسيُسجَّل مرة واحدة فقط عند «حفظ الزيارة». '
                        'لإلغائه اضغط «إلغاء» واخرج من النموذج دون حفظ.',
                    onPay: _markPay,
                  ),
                  if (_payOnSave) ...[
                    const SizedBox(width: 8),
                    Text(
                      'المبلغ $_payAmount — يُسجَّل في المالية عند «حفظ الزيارة»',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.paid,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(width: 12),
                  TextButton.icon(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('إلغاء'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// تبويب «جلسة»: نوع الجلسة وتاريخها. عند الحفظ تُنشأ جلسة مجدولة
  /// وموعد في «مواعيد الجلسات»، وتنتقل إلى «الجلسات المنجزة» عند تنفيذها
  /// وإلى مالية الجلسات عند الدفع — منفصلة عن المعاينة.
  Widget _buildSession() {
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: [
        const SizedBox(
          width: 620,
          child: Text(
            'اختر الجلسة المطلوبة وموعدها — تظهر تلقائياً في مواعيد الجلسات',
            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
          ),
        ),
        SizedBox(
          width: 300,
          child: AppDropdownField<String>(
            label: 'جلسة مطلوبة',
            value: _planSession,
            items: NeuroConstants.sessionOptions
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) => setState(() => _planSession = v),
          ),
        ),
        if (_planSession != null) ...[
          SizedBox(
            width: 300,
            child: AppDateField(
              label: 'تاريخ الجلسة',
              value: _sessionDate,
              firstDate: DateTime(2020),
              lastDate: DateTime(2100),
              onChanged: (d) =>
                  setState(() => _sessionDate = d ?? _sessionDate),
            ),
          ),
          SizedBox(
            width: 300,
            child: AppTimeField(
              label: 'وقت الجلسة',
              value: _sessionTime,
              onChanged: (t) =>
                  setState(() => _sessionTime = t ?? _sessionTime),
            ),
          ),
          SizedBox(
            width: 300,
            child: AppDropdownField<int>(
              label: 'المدة (دقيقة)',
              value: _sessionDuration,
              items: {10, 15, 20, 30, 45, 60, _sessionDuration}
                  .map((e) => DropdownMenuItem(value: e, child: Text('$e')))
                  .toList(),
              onChanged: (v) =>
                  setState(() => _sessionDuration = v ?? _sessionDuration),
            ),
          ),
          SizedBox(
            width: 300,
            child: TextButton.icon(
              onPressed: () => setState(() => _planSession = null),
              icon: const Icon(Icons.close, size: 17),
              label: const Text('بدون جلسة'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildVisitInfo() {
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: [
        SizedBox(
          width: 300,
          child: AppDateField(
            label: 'تاريخ الزيارة',
            value: _date,
            lastDate: DateTime.now().add(const Duration(days: 1)),
            onChanged: (d) => setState(() => _date = d ?? _date),
          ),
        ),
        SizedBox(
          width: 300,
          child: AppDropdownField<String>(
            label: 'نوع الزيارة',
            value: _type,
            items: NeuroConstants.visitTypes.entries
                .map(
                  (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                )
                .toList(),
            onChanged: (v) => setState(() => _type = v ?? 'new'),
          ),
        ),
        if (_type == 'session')
          SizedBox(
            width: 300,
            child: AppDropdownField<String>(
              label: 'نوع الجلسة',
              value: _sessionChoice,
              items: NeuroConstants.sessionOptions
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => setState(() => _sessionChoice = v),
            ),
          ),
        SizedBox(
          width: 620,
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final symptom in [
                'صداع',
                'دوار',
                'خدر',
                'ضعف',
                'ألم ظهر',
                'اضطراب مشي',
                'اختلاجات',
              ])
                ActionChip(
                  label: Text(symptom),
                  onPressed: () {
                    _complaint.text = [
                      _complaint.text.trim(),
                      symptom,
                    ].where((s) => s.isNotEmpty).join('، ');
                  },
                ),
            ],
          ),
        ),
        SizedBox(
          width: 620,
          child: AppTextField(
            controller: _complaint,
            label: 'الشكوى الرئيسية',
            maxLines: 2,
          ),
        ),
        SizedBox(
          width: 300,
          child: AppTextField(
            controller: _onset,
            label: 'مدة الأعراض / البداية',
          ),
        ),
        SizedBox(
          width: 300,
          child: AppTextField(
            controller: _notes,
            label: 'ملاحظات',
            maxLines: 1,
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------------------- الفحص العصبي
  Widget _buildNeuroExam() {
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: [
        SizedBox(
          width: 300,
          child: AppDropdownField<String>(
            label: 'مستوى الوعي',
            value: _consciousness,
            items: NeuroConstants.consciousnessOptions
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) => setState(() => _consciousness = v),
          ),
        ),
        SizedBox(
          width: 300,
          child: AppNumberField(controller: _gcs, label: 'GCS (3 - 15)'),
        ),
        SizedBox(
          width: 300,
          child: AppTextField(
            controller: _orientation,
            label: 'التوجّه (زمان/مكان/أشخاص)',
          ),
        ),
        SizedBox(
          width: 300,
          child: Column(
            children: [
              AppDropdownField<String>(
                label: 'الكلام واللغة',
                value: _speechChoice,
                items: NeuroConstants.speechOptions
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setState(() => _speechChoice = v),
              ),
              if (_speechChoice == 'آخر') ...[
                const SizedBox(height: 10),
                AppTextField(
                  controller: _speech,
                  label: 'تفاصيل أخرى للكلام واللغة',
                ),
              ],
            ],
          ),
        ),
        SizedBox(
          width: 620,
          child: AppTextField(
            controller: _cranial,
            label: 'الأعصاب القحفية',
            maxLines: 3,
            hint: NeuroConstants.cranialNerveLabels.entries
                .map((e) => '${e.key}: ${e.value}')
                .join('\n'),
          ),
        ),
        SizedBox(
          width: 300,
          child: AppDropdownField<String>(
            label: 'القوة المحركة',
            value: _motor,
            items: NeuroConstants.motorOptions
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) => setState(() => _motor = v),
          ),
        ),
        SizedBox(
          width: 300,
          child: AppDropdownField<String>(
            label: 'التوتر العضلي',
            value: _tone,
            items: NeuroConstants.toneOptions
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) => setState(() => _tone = v),
          ),
        ),
        SizedBox(
          width: 300,
          child: AppDropdownField<String>(
            label: 'المنعكسات',
            value: _reflexes,
            items: NeuroConstants.reflexOptions
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) => setState(() => _reflexes = v),
          ),
        ),
        SizedBox(
          width: 300,
          child: AppDropdownField<String>(
            label: 'الإحساس',
            value: _sensationChoice,
            items: NeuroConstants.sensationOptions
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) => setState(() {
              _sensationChoice = v;
              _sensation.text = v ?? '';
            }),
          ),
        ),
        SizedBox(
          width: 300,
          child: AppTextField(
            controller: _coordination,
            label: 'التناسق الحركي',
          ),
        ),
        SizedBox(
          width: 300,
          child: AppTextField(controller: _gait, label: 'المشية'),
        ),
        SizedBox(
          width: 300,
          child: AppTextField(controller: _meningeal, label: 'علامات سحائية'),
        ),
        SizedBox(
          width: 620,
          child: AppTextField(
            controller: _findings,
            label: 'موجودات أخرى',
            maxLines: 3,
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------- المقاييس
  Widget _buildScales() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton.icon(
            onPressed: () => setState(() => _scales.add(_ScaleRow())),
            icon: const Icon(Icons.add, size: 17),
            label: const Text('إضافة مقياس'),
          ),
        ),
        _scales.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  'أضف مقياساً مثل MMSE أو EDSS لتتبّع تطوّر الحالة عبر الزيارات.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              )
            : Column(
                children: _scales.asMap().entries.map((entry) {
                  final i = entry.key;
                  final row = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: AppDropdownField<String>(
                            label: 'المقياس',
                            value: row.scale,
                            items: NeuroConstants.neuroScales.keys
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(e),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) => setState(() => row.scale = v),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: AppTextField(
                            controller: row.score,
                            label: 'النتيجة',
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 150,
                          child: Text(
                            row.scale == null
                                ? ''
                                : 'من ${NeuroConstants.neuroScales[row.scale]}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.remove_circle_outline,
                            size: 19,
                            color: AppColors.danger,
                          ),
                          onPressed: () => setState(() {
                            row.dispose();
                            _scales.removeAt(i);
                          }),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
      ],
    );
  }

  // ---------------------------------------------------------------- التشخيص
  Widget _buildDiagnosis() {
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: [
        SizedBox(
          width: 400,
          child: DropdownButtonFormField<String>(
            initialValue: _icd10,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'تشخيص شائع (ICD-10)'),
            items: NeuroConstants.commonDiagnoses.entries
                .map(
                  (e) => DropdownMenuItem(
                    value: e.key,
                    child: Text(
                      '${e.key} — ${e.value}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() {
              _icd10 = v;
              if (v != null) {
                _diagnosis.text = NeuroConstants.commonDiagnoses[v]!;
              }
            }),
          ),
        ),
        SizedBox(
          width: 200,
          child: AppTextField(controller: _followup, label: 'مراجعة بعد (يوم)'),
        ),
        SizedBox(
          width: 620,
          child: AppTextField(
            controller: _diagnosis,
            label: 'التشخيص',
            maxLines: 2,
          ),
        ),
        SizedBox(
          width: 620,
          child: AppTextField(
            controller: _plan,
            label: 'الخطة العلاجية',
            maxLines: 3,
          ),
        ),
        const SizedBox(
          width: 620,
          child: Text(
            'طلبات تُنشأ تلقائياً عند حفظ الزيارة — اتركها فارغة إن لم تلزم',
            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
          ),
        ),
        SizedBox(
          width: 300,
          child: AppDropdownField<String>(
            label: 'تصوير مطلوب',
            value: _planImaging,
            items: NeuroConstants.imagingOptions
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) => setState(() => _planImaging = v),
          ),
        ),
        if (_planImaging == 'آخر')
          SizedBox(
            width: 300,
            child: AppTextField(
              controller: _planImagingOther,
              label: 'نوع التصوير الآخر',
            ),
          ),
        SizedBox(
          width: 300,
          child: AppDropdownField<String>(
            label: 'استشارة',
            value: _planConsult,
            items: const [
              DropdownMenuItem(value: 'consult', child: Text('استشارة طبية')),
            ],
            onChanged: (v) => setState(() => _planConsult = v),
          ),
        ),
        if (_planConsult != null)
          SizedBox(
            width: 300,
            child: AppTextField(
              controller: _consultDoctor,
              label: 'اسم الطبيب المستشار',
            ),
          ),
        if (_planConsult != null)
          SizedBox(
            width: 620,
            child: AppTextField(
              controller: _consultReason,
              label: 'سبب الاستشارة',
              maxLines: 2,
            ),
          ),
        SizedBox(
          width: 300,
          child: AppDropdownField<String>(
            label: 'تحويل إلى',
            value: _planTransfer,
            items: NeuroConstants.transferTargets
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) => setState(() => _planTransfer = v),
          ),
        ),
        if (_planTransfer != null)
          SizedBox(
            width: 300,
            child: AppTextField(
              controller: _transferDestination,
              label: 'اسم الجهة المحوَّل إليها',
            ),
          ),
        if (_planTransfer != null)
          SizedBox(
            width: 620,
            child: AppTextField(
              controller: _transferReason,
              label: 'سبب التحويل',
              maxLines: 2,
            ),
          ),
      ],
    );
  }

  // ------------------------------------------------------------------ الوصفة
  Widget _buildPrescription() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton.icon(
            onPressed: () =>
                setState(() => _prescriptions.add(_PrescriptionRow())),
            icon: const Icon(Icons.add, size: 17),
            label: const Text('إضافة دواء'),
          ),
        ),
        _prescriptions.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  'لا توجد أدوية مضافة لهذه الزيارة.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              )
            : Column(
                children: _prescriptions.asMap().entries.map((entry) {
                  final i = entry.key;
                  final row = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: AppTextField(
                            controller: row.drug,
                            label: 'الدواء',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: AppTextField(
                            controller: row.dose,
                            label: 'الجرعة',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: AppTextField(
                            controller: row.frequency,
                            label: 'التكرار',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: AppTextField(
                            controller: row.duration,
                            label: 'المدة (يوم)',
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.remove_circle_outline,
                            size: 19,
                            color: AppColors.danger,
                          ),
                          onPressed: () => setState(() {
                            row.dispose();
                            _prescriptions.removeAt(i);
                          }),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
      ],
    );
  }
}

class _ScaleRow {
  String? scale;
  final score = TextEditingController();

  void dispose() => score.dispose();
}

class _PrescriptionRow {
  final drug = TextEditingController();
  final dose = TextEditingController();
  final frequency = TextEditingController();
  final duration = TextEditingController();

  void dispose() {
    drug.dispose();
    dose.dispose();
    frequency.dispose();
    duration.dispose();
  }
}

