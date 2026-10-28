import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/date_fmt.dart';
import '../../core/utils/age_input.dart';
import '../../data/models/appointment.dart';
import '../../data/providers/session_provider.dart';
import '../../data/repositories/appointment_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../core/widgets/clinic_brand.dart';

/// Preserve access to the existing manual ledger outside the clinical chart.
/// Automatic service pricing and settlement are intentionally not implied here.
class PatientPaymentsScreen extends StatefulWidget {
  const PatientPaymentsScreen({super.key, required this.patientId});
  final int patientId;
  @override
  State<PatientPaymentsScreen> createState() => _PatientPaymentsScreenState();
}

class _PatientPaymentsScreenState extends State<PatientPaymentsScreen> {
  final _repo = AppointmentRepository();
  late Future<List<Payment>> _payments;
  @override
  void initState() {
    super.initState();
    _payments = _repo.paymentsForPatient(widget.patientId);
  }

  Future<void> _add() async {
    final settings = await SettingsRepository().load();
    if (!mounted) return;
    final controller = TextEditingController(
      text: settings.defaultFee > 0 ? '${settings.defaultFee}' : '',
    );
    final note = TextEditingController();
    final form = GlobalKey<FormState>();
    var busy = false;
    String? error;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => PopScope(
          canPop: !busy,
          child: AlertDialog(
            title: const Text('تسجيل دفعة يدوية'),
            content: SizedBox(
              width: 400,
              child: Form(
                key: form,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'دفعة عامة في حساب المريض. لا تعني تسديد زيارة أو جلسة محددة تلقائياً.',
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: controller,
                      enabled: !busy,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'المبلغ'),
                      validator: (v) {
                        final amount = double.tryParse(
                          normalizeDigits(v ?? ''),
                        );
                        return amount == null || !amount.isFinite || amount <= 0
                            ? 'أدخل مبلغاً موجباً صحيحاً'
                            : null;
                      },
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: note,
                      enabled: !busy,
                      decoration: const InputDecoration(labelText: 'ملاحظة'),
                    ),
                    if (error != null) Text(error!),
                  ],
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
                          await _repo.addPayment(
                            Payment(
                              patientId: widget.patientId,
                              amount: double.parse(
                                normalizeDigits(controller.text),
                              ),
                              note: note.text.trim(),
                            ),
                          );
                          if (ctx.mounted) {
                            update(() => busy = false);
                            Navigator.pop(ctx);
                          }
                          if (mounted) {
                            setState(
                              () => _payments = _repo.paymentsForPatient(
                                widget.patientId,
                              ),
                            );
                          }
                        } catch (_) {
                          if (ctx.mounted) {
                            update(() {
                              busy = false;
                              error = 'تعذّر تسجيل الدفعة';
                            });
                          }
                        }
                      },
                child: Text(busy ? 'جارٍ التسجيل' : 'تأكيد الدفع النقدي'),
              ),
            ],
          ),
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    controller.dispose();
    note.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allowed = context.watch<SessionProvider>().user?.isDoctor == true;
    return Scaffold(
      appBar: BrandedAppBar(
        title: const Text('دفعات المريض'),
        actions: [
          if (allowed)
            TextButton(onPressed: _add, child: const Text('دفعة يدوية')),
        ],
      ),
      body: !allowed
          ? const Center(child: Text('غير متاح لهذا الدور'))
          : FutureBuilder<List<Payment>>(
              future: _payments,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('تعذّر تحميل الدفعات'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.data!.isEmpty) {
                  return const Center(child: Text('لا توجد دفعات'));
                }
                return ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    for (final p in snapshot.data!)
                      Card(
                        child: ListTile(
                          title: Text(
                            '${p.amount} • ${p.paidAt == null ? "تاريخ غير محدد" : DateFmt.dateTime(p.paidAt!)}',
                          ),
                          subtitle: Text(
                            '${p.note ?? ""}\n${p.visitId == null ? "دفعة عامة" : "زيارة رقم ${p.visitId}"}',
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
    );
  }
}

