import '../../core/widgets/patient_link.dart';
import '../../core/widgets/day_groups.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/date_fmt.dart';
import '../../core/utils/neuro_constants.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/form_fields.dart';
import '../../core/widgets/section_card.dart';
import '../../core/widgets/status_chip.dart';
import '../../data/models/appointment.dart';
import '../../data/models/patient.dart';
import '../../data/providers/appointments_provider.dart';
import '../../data/repositories/patient_repository.dart';

/// شاشة المواعيد: يوم محدد + جدول زمني + إضافة موعد.
class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AppointmentsProvider>().load();
    });
  }

  Future<void> _openForm({Appointment? appointment}) async {
    final day = context.read<AppointmentsProvider>().day;
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AppointmentDialog(appointment: appointment, day: day),
    );
    if (!mounted || result != true) return;
    await context.read<AppointmentsProvider>().load();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppointmentsProvider>();

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: SectionCard(
          padding: const EdgeInsets.all(0),
          title: 'مواعيد ${DateFmt.describe(provider.day)}',
          icon: Icons.calendar_month_outlined,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'اليوم السابق',
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: () => provider.goToDay(
                  provider.day.subtract(const Duration(days: 1)),
                ),
              ),
              OutlinedButton(
                onPressed: () => provider.goToToday(),
                child: const Text('اليوم'),
              ),
              IconButton(
                tooltip: 'اليوم التالي',
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: () =>
                    provider.goToDay(provider.day.add(const Duration(days: 1))),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => _openForm(),
                icon: const Icon(Icons.add, size: 17),
                label: const Text('موعد جديد'),
              ),
            ],
          ),
          child: provider.loading
              ? const SizedBox(
                  height: 260,
                  child: Center(child: CircularProgressIndicator()),
                )
              : provider.items.isEmpty
              ? const EmptyState(
                  message: 'لا توجد مواعيد في هذا اليوم',
                  icon: Icons.event_busy_outlined,
                )
              : DayGroups<Appointment>(
                  items: provider.items,
                  dateOf: (a) => a.startAt,
                  noun: 'موعد',
                  groupBuilder: (dayAppointments) => ListView.separated(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    itemCount: dayAppointments.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final a = dayAppointments[i];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 4,
                        ),
                        leading: SizedBox(
                          width: 96,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                DateFmt.time(a.startAt),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                '${a.durationMin} دقيقة',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        title: PatientLink(
                          patientId: a.patientId,
                          name: a.patientName ?? '—',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          [a.reason, a.patientPhone]
                              .whereType<String>()
                              .where((e) => e.isNotEmpty)
                              .join('  •  '),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            StatusChip(
                              label:
                                  NeuroConstants.appointmentStatuses[a
                                      .status] ??
                                  a.status,
                              color: AppColors.forAppointmentStatus(a.status),
                            ),
                            const SizedBox(width: 6),
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert, size: 19),
                              onSelected: (value) async {
                                if (value == 'edit') {
                                  _openForm(appointment: a);
                                } else if (value == 'delete') {
                                  final ok = await ConfirmDialog.show(
                                    context,
                                    title: 'حذف الموعد',
                                    message:
                                        'هل تريد حذف موعد ${a.patientName}؟',
                                    confirmLabel: 'حذف',
                                    destructive: true,
                                  );
                                  if (ok && context.mounted) {
                                    await context
                                        .read<AppointmentsProvider>()
                                        .remove(a.id!);
                                  }
                                } else {
                                  await context
                                      .read<AppointmentsProvider>()
                                      .setStatus(a.id!, value);
                                }
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Text('تعديل'),
                                ),
                                ...NeuroConstants.appointmentStatuses.entries
                                    .map(
                                      (e) => PopupMenuItem(
                                        value: e.key,
                                        child: Text('تغيير الحالة: ${e.value}'),
                                      ),
                                    ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text('حذف'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
        ),
      ),
    );
  }
}

class AppointmentDialog extends StatefulWidget {
  const AppointmentDialog({super.key, this.appointment, required this.day});

  final Appointment? appointment;
  final DateTime day;

  @override
  State<AppointmentDialog> createState() => _AppointmentDialogState();
}

class _AppointmentDialogState extends State<AppointmentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _patientRepo = PatientRepository();

  List<Patient> _patients = [];
  int? _patientId;
  DateTime? _date;
  TimeOfDay? _time;
  int _duration = 20;
  String _status = 'scheduled';
  final _reason = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _date = widget.appointment?.startAt ?? widget.day;
    _time = widget.appointment == null
        ? const TimeOfDay(hour: 9, minute: 0)
        : TimeOfDay.fromDateTime(widget.appointment!.startAt);
    _patientId = widget.appointment?.patientId;
    _duration = widget.appointment?.durationMin ?? 20;
    _status = widget.appointment?.status ?? 'scheduled';
    _reason.text = widget.appointment?.reason ?? '';
    _loadPatients();
  }

  Future<void> _loadPatients() async {
    final list = await _patientRepo.search(query: '', limit: 500);
    if (!mounted || !context.mounted) return;
    setState(() => _patients = list);
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_patientId == null) {
      setState(() => _error = 'اختر المريض');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });

    final start = DateTime(
      _date!.year,
      _date!.month,
      _date!.day,
      _time!.hour,
      _time!.minute,
    );

    final appointment = Appointment(
      id: widget.appointment?.id,
      patientId: _patientId!,
      startAt: start,
      durationMin: _duration,
      status: _status,
      reason: _reason.text.trim().isEmpty ? null : _reason.text.trim(),
      createdAt: widget.appointment?.createdAt,
    );

    final provider = context.read<AppointmentsProvider>();
    String? error;
    try {
      if (widget.appointment == null) {
        error = await provider.add(appointment);
      } else {
        await provider.update(appointment);
      }
    } catch (e) {
      error = e.toString();
    }
    if (!mounted || !context.mounted) return;

    if (error != null) {
      setState(() {
        _saving = false;
        _error = error;
      });
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.appointment == null ? 'موعد جديد' : 'تعديل الموعد'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: _patientId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'المريض *'),
                  items: _patients
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
                  onChanged: (v) => setState(() => _patientId = v),
                  validator: (v) => v == null ? 'مطلوب' : null,
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: AppDateField(
                        label: 'التاريخ',
                        value: _date,
                        onChanged: (d) => setState(() => _date = d ?? _date),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppTimeField(
                        label: 'الوقت',
                        value: _time,
                        onChanged: (t) => setState(() => _time = t ?? _time),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: AppDropdownField<int>(
                        label: 'المدة (دقيقة)',
                        value: _duration,
                        items: const [10, 15, 20, 30, 45, 60]
                            .map(
                              (e) =>
                                  DropdownMenuItem(value: e, child: Text('$e')),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _duration = v ?? 20),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppDropdownField<String>(
                        label: 'الحالة',
                        value: _status,
                        items: NeuroConstants.appointmentStatuses.entries
                            .map(
                              (e) => DropdownMenuItem(
                                value: e.key,
                                child: Text(e.value),
                              ),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _status = v ?? 'scheduled'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                AppTextField(
                  controller: _reason,
                  label: 'سبب الزيارة',
                  maxLines: 2,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 18),
                  Text(
                    _error!,
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
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'جارٍ الحفظ…' : 'حفظ'),
        ),
      ],
    );
  }
}
