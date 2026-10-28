import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/database/app_database.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_sizes.dart';
import '../../core/utils/age_input.dart';
import '../../core/utils/date_fmt.dart';
import '../../core/utils/neuro_constants.dart';
import '../../core/widgets/clinic_brand.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/form_fields.dart';
import '../../core/widgets/section_card.dart';
import '../../data/models/user.dart';
import '../../data/providers/settings_provider.dart';
import '../../data/providers/session_provider.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/clinic_flow_repository.dart';
import '../../data/repositories/logo_repository.dart';
import '../../data/repositories/settings_repository.dart';
import 'about_card.dart';
import 'recovery_backup_settings.dart';
import '../../core/services/app_folders.dart';
import '../../core/services/developer_mode.dart';

/// الإعدادات: بيانات العيادة، المستخدمون، النسخ الاحتياطي.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _settingsRepo = SettingsRepository();
  final _authRepo = AuthRepository();

  List<User> _users = [];
  Map<String, int> _counts = {};
  bool _loadingUsers = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      _authRepo.all(),
      _settingsRepo.tableCounts(),
    ]);
    if (!mounted || !context.mounted) return;
    setState(() {
      _users = results[0] as List<User>;
      _counts = results[1] as Map<String, int>;
      _loadingUsers = false;
    });
  }

  static String _backupName() {
    final n = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return 'neuro-clinic-backup-${DateFmt.isoDate(n)}_'
        '${two(n.hour)}-${two(n.minute)}-${two(n.second)}.db';
  }

  /// نسخة يدوية مباشرة في مجلد النسخ اليدوية (myclinic\backups\manual).
  Future<void> _backup() async {
    try {
      final dir = await AppFolders.manualBackups();
      final path = '${dir.path}${Platform.pathSeparator}${_backupName()}';
      await AppDatabase.instance.backupTo(path);
      if (!mounted || !context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم إنشاء النسخة الاحتياطية في:\n\u200E$path'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted || !context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل النسخ الاحتياطي: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  /// نسخة إلى مسار آخر يختاره المستخدم (فلاشة أو قرص خارجي).
  Future<void> _backupElsewhere() async {
    String? initial;
    try {
      initial = (await AppFolders.manualBackups()).path;
    } catch (_) {}
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'حفظ نسخة احتياطية',
      initialDirectory: initial,
      fileName: _backupName(),
      type: FileType.custom,
      allowedExtensions: ['db'],
    );
    if (path == null) return;
    if (!mounted || !context.mounted) return;
    try {
      await AppDatabase.instance.backupTo(path);
      if (!mounted || !context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إنشاء النسخة الاحتياطية بنجاح'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted || !context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل النسخ الاحتياطي: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Future<void> _restore() async {
    final ok = await ConfirmDialog.show(
      context,
      title: 'استرجاع نسخة احتياطية',
      message:
          'سيتم استبدال كل البيانات الحالية بالنسخة المختارة. لا يمكن التراجع.',
      confirmLabel: 'استرجاع',
      destructive: true,
    );
    if (!ok) return;

    String? initial;
    try {
      initial = (await AppFolders.backups()).path;
    } catch (_) {}
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'اختر ملف النسخة الاحتياطية',
      initialDirectory: initial,
      type: FileType.custom,
      allowedExtensions: ['db'],
    );
    if (result == null || result.files.single.path == null) return;
    if (!mounted) return;

    try {
      final settingsProvider = context.read<SettingsProvider>();
      await AppDatabase.instance.restoreFrom(result.files.single.path!);
      if (!mounted || !context.mounted) return;
      await settingsProvider.load();
      if (!mounted || !context.mounted) return;
      _load();
      if (!mounted || !context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم الاسترجاع — أعد تشغيل التطبيق'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل الاسترجاع: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _addUser() async {
    final username = TextEditingController();
    final password = TextEditingController();
    final name = TextEditingController();
    String role = 'reception';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('مستخدم جديد'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'الاسم الكامل'),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: username,
                decoration: const InputDecoration(labelText: 'اسم المستخدم'),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: password,
                decoration: const InputDecoration(labelText: 'كلمة المرور'),
              ),
              const SizedBox(height: 18),
              DropdownButtonFormField<String>(
                initialValue: role,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'الدور'),
                items: const [
                  DropdownMenuItem(value: 'doctor', child: Text('طبيب')),
                  DropdownMenuItem(value: 'reception', child: Text('استقبال')),
                  DropdownMenuItem(value: 'admin', child: Text('مدير')),
                ],
                onChanged: (v) => role = v ?? role,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('إنشاء'),
          ),
        ],
      ),
    );

    if (ok == true) {
      if (DeveloperMode.isReserved(username.text)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('هذا الاسم محجوز لحساب المبرمج'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
        return;
      }
      if (username.text.trim().isEmpty || password.text.length < 8) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('اسم المستخدم مطلوب وكلمة المرور 8 أحرف على الأقل'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
        return;
      }
      try {
        await _authRepo.create(
          username: username.text.trim(),
          password: password.text,
          fullName: name.text.trim().isEmpty
              ? username.text.trim()
              : name.text.trim(),
          role: role,
        );
        _load();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('اسم المستخدم مستخدم مسبقاً'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SettingsProvider>();
    final s = provider.settings;
    final number = NumberFormat('#,##0', 'en_US');

    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        // ------------------------------------------------------- بيانات العيادة
        // لا تظهر للطبيب: تظهر فقط عند الدخول بحساب المبرمج من شاشة الدخول.
        ValueListenableBuilder<bool>(
          valueListenable: DeveloperMode.unlocked,
          builder: (context, dev, _) => !dev
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: SectionCard(
                    key: const Key('clinicDataCard'),
                    title: 'بيانات العيادة (حساب المبرمج)',
                    icon: Icons.local_hospital_outlined,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // صورة الشعار وأزرارها ضمن بيانات العيادة.
                        const ClinicLogoSettings(),
                        const Divider(height: 34, color: AppColors.divider),
                        ClinicSettingsForm(
                          initial: s,
                          onSave: (updated) async {
                            await provider.save(updated);
                            if (!mounted || !context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('تم حفظ الإعدادات'),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
        ),
        // ------------------------------------------- الزيارة والمعاينة (الأسعار)
        SectionCard(
          key: const Key('visitSettingsCard'),
          title: 'الزيارة والمعاينة',
          icon: Icons.sell_outlined,
          child: PricesForm(
            onSaved: provider.load,
            settings: s,
            onSaveSettings: provider.save,
          ),
        ),
        const SizedBox(height: 18),

        // ------------------------------------------------------------- المستخدمون
        SectionCard(
          title: 'المستخدمون والصلاحيات',
          icon: Icons.manage_accounts_outlined,
          // زر «مستخدم جديد» في الطرف الأيسر من رأس القسم.
          trailing: FilledButton.icon(
            key: const Key('addUser'),
            onPressed: _addUser,
            icon: const Icon(Icons.person_add_alt_1_outlined, size: 17),
            label: const Text('مستخدم جديد'),
          ),
          child: _loadingUsers
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: _users.map((u) {
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.primary.withValues(
                          alpha: 0.1,
                        ),
                        child: Text(
                          u.fullName.isNotEmpty ? u.fullName[0] : '؟',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      title: Text(
                        '${u.fullName} (${u.username})',
                        style: const TextStyle(fontSize: 13),
                      ),
                      subtitle: Text(
                        u.roleLabel,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'تغيير كلمة المرور',
                            icon: const Icon(Icons.key_outlined, size: 18),
                            onPressed: () => _changePassword(u),
                          ),
                          Switch(
                            value: u.isActive,
                            onChanged:
                                u.id == context.read<SessionProvider>().user?.id
                                ? null
                                : (v) async {
                                    await _authRepo.setActive(u.id!, v);
                                    _load();
                                  },
                          ),
                          IconButton(
                            tooltip: 'حذف',
                            icon: const Icon(
                              Icons.delete_outline,
                              size: 18,
                              color: AppColors.danger,
                            ),
                            onPressed:
                                u.id == context.read<SessionProvider>().user?.id
                                ? null
                                : () async {
                                    final ok = await ConfirmDialog.show(
                                      context,
                                      title: 'حذف المستخدم',
                                      message: 'حذف ${u.fullName}؟',
                                      confirmLabel: 'حذف',
                                      destructive: true,
                                    );
                                    if (ok) {
                                      await _authRepo.delete(u.id!);
                                      _load();
                                    }
                                  },
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ),
        const SizedBox(height: 18),

        // ------------------------------------------------ استعادة كلمة المرور
        const SectionCard(
          key: Key('recoveryCard'),
          title: 'استعادة كلمة المرور',
          icon: Icons.lock_reset,
          child: RecoverySettings(),
        ),
        const SizedBox(height: 18),

        // ---------------------------------------------------- النسخ الاحتياطي
        SectionCard(
          title: 'النسخ الاحتياطي وقاعدة البيانات',
          icon: Icons.backup_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AutoBackupSettings(),
              const Divider(height: 34, color: AppColors.divider),
              const Text(
                'نسخة يدوية / استرجاع',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.icon(
                      key: const Key('manualBackup'),
                      onPressed: _backup,
                      icon: const Icon(Icons.backup_outlined, size: 17),
                      label: const Text('إنشاء نسخة احتياطية'),
                    ),
                    OutlinedButton.icon(
                      key: const Key('manualBackupElsewhere'),
                      onPressed: _backupElsewhere,
                      icon: const Icon(Icons.usb_outlined, size: 17),
                      label: const Text('نسخ إلى فلاشة / قرص خارجي'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _restore,
                      icon: const Icon(Icons.restore_outlined, size: 17),
                      label: const Text('استرجاع نسخة'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final ok = await ConfirmDialog.show(
                          context,
                          title: 'بيانات تجريبية',
                          message:
                              'سيتم إضافة 24 مريضاً مع زيارات ومواعيد لتجربة الواجهة. '
                              'يُنصح بعمل نسخة احتياطية أولاً.',
                          confirmLabel: 'إدراج',
                        );
                        if (ok) {
                          await _settingsRepo.insertDemoData();
                          if (!mounted || !context.mounted) return;
                          _load();
                          if (!mounted || !context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('تم إدراج البيانات التجريبية'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.science_outlined, size: 17),
                      label: const Text('إدراج بيانات تجريبية'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final ok = await ConfirmDialog.show(
                          context,
                          title: 'حذف البيانات السريرية',
                          message:
                              'سيتم حذف كل المرضى والزيارات والمواعيد والمدفوعات نهائياً. '
                              'المستخدمون والإعدادات ستبقى.',
                          confirmLabel: 'حذف الكل',
                          destructive: true,
                        );
                        if (ok) {
                          await _settingsRepo.clearClinicalData();
                          _load();
                        }
                      },
                      icon: const Icon(Icons.delete_forever_outlined, size: 17),
                      label: const Text('حذف البيانات السريرية'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const Divider(height: 1),
              const SizedBox(height: 14),
              _infoRow(
                'مسار ملف قاعدة البيانات',
                AppDatabase.instance.filePath ?? '—',
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 20,
                runSpacing: 8,
                children: [
                  _countChip('المرضى', _counts['patients'] ?? 0, number),
                  _countChip('الزيارات', _counts['visits'] ?? 0, number),
                  _countChip('المواعيد', _counts['appointments'] ?? 0, number),
                  _countChip('الفحوص', _counts['investigations'] ?? 0, number),
                  _countChip('الأدوية', _counts['medications'] ?? 0, number),
                  _countChip('المدفوعات', _counts['payments'] ?? 0, number),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // ------------------------------------------------------------------ حول
        const AboutCard(),
        const SizedBox(height: 30),
      ],
    );
  }

  Future<void> _changePassword(User u) async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('كلمة مرور جديدة — ${u.fullName}'),
        content: SizedBox(
          width: 340,
          child: TextField(
            controller: controller,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'كلمة المرور الجديدة'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تغيير'),
          ),
        ],
      ),
    );
    if (ok == true && controller.text.length >= 8) {
      await _authRepo.changePassword(u.id!, controller.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تغيير كلمة المرور'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  Widget _infoRow(String label, String value) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '$label: ',
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
      Expanded(
        child: SelectableText(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    ],
  );

  Widget _countChip(String label, int value, NumberFormat f) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        '$label: ',
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
      Text(
        f.format(value),
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    ],
  );
}

/// نموذج بيانات العيادة (قابل لإعادة الاستخدام).
class ClinicSettingsForm extends StatefulWidget {
  const ClinicSettingsForm({
    super.key,
    required this.initial,
    required this.onSave,
  });

  final ClinicSettings initial;
  final ValueChanged<ClinicSettings> onSave;

  @override
  State<ClinicSettingsForm> createState() => _ClinicSettingsFormState();
}

class _ClinicSettingsFormState extends State<ClinicSettingsForm> {
  late final TextEditingController _clinicName;
  late final TextEditingController _doctorName;
  late final TextEditingController _specialty;
  late final TextEditingController _phone;
  late final TextEditingController _address;
  @override
  void initState() {
    super.initState();
    _clinicName = TextEditingController(text: widget.initial.clinicName);
    _doctorName = TextEditingController(text: widget.initial.doctorName);
    _specialty = TextEditingController(text: widget.initial.specialty);
    _phone = TextEditingController(text: widget.initial.phone);
    _address = TextEditingController(text: widget.initial.address);
  }

  @override
  void dispose() {
    for (final c in [_clinicName, _doctorName, _specialty, _phone, _address]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Wrap(
          spacing: 14,
          runSpacing: 18,
          children: [
            SizedBox(
              width: 380,
              child: AppTextField(
                controller: _clinicName,
                label: 'اسم العيادة (عبارة الترويسة والشعار)',
              ),
            ),
            SizedBox(
              width: 380,
              child: AppTextField(controller: _doctorName, label: 'اسم الطبيب'),
            ),
            SizedBox(
              width: 380,
              child: AppTextField(controller: _specialty, label: 'الاختصاص'),
            ),
            SizedBox(
              width: 380,
              child: AppTextField(controller: _phone, label: 'هاتف العيادة'),
            ),
            SizedBox(
              width: 380,
              child: AppTextField(controller: _address, label: 'العنوان'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            SizedBox(
              height: AppSizes.control,
              child: FilledButton.icon(
                onPressed: () {
                  widget.onSave(
                    ClinicSettings(
                      clinicName: _clinicName.text.trim(),
                      doctorName: _doctorName.text.trim(),
                      specialty: _specialty.text.trim(),
                      phone: _phone.text.trim(),
                      address: _address.text.trim(),
                      // سعر المعاينة يُعدَّل من بطاقة «الزيارة والمعاينة» فقط.
                      defaultFee: widget.initial.defaultFee,
                      // مدة الموعد والملاحظة تُعدَّلان من «الزيارة والمعاينة».
                      visitDuration: widget.initial.visitDuration,
                      footerNote: widget.initial.footerNote,
                    ),
                  );
                },
                icon: const Icon(Icons.save_outlined, size: 18),
                label: const Text('حفظ'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// أسعار ثابتة: المعاينة وكل نوع جلسة. تُستخدم تلقائياً عند
/// «تم دفع أجر المعاينة» و«تم دفع أجر الجلسة» ولا تُعدَّل في نافذة الدفع.
class PricesForm extends StatefulWidget {
  const PricesForm({
    super.key,
    this.onSaved,
    this.settings,
    this.onSaveSettings,
  });

  final Future<void> Function()? onSaved;

  /// إن مُرِّرت: تظهر «مدة الموعد» و«ملاحظة أسفل الوصفة» وتُحفظ مع الأسعار.
  final ClinicSettings? settings;
  final Future<void> Function(ClinicSettings)? onSaveSettings;

  @override
  State<PricesForm> createState() => _PricesFormState();
}

class _PricesFormState extends State<PricesForm> {
  final _repo = ClinicFlowRepository();
  final _checkup = TextEditingController();
  final _duration = TextEditingController();
  final _footer = TextEditingController();
  final Map<String, TextEditingController> _sessions = {
    for (final name in NeuroConstants.sessionOptions)
      name: TextEditingController(),
  };
  bool _loaded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final s = widget.settings;
    if (s != null) {
      _duration.text = s.visitDuration.toString();
      _footer.text = s.footerNote;
    }
    _load();
  }

  Future<void> _load() async {
    final prices = await _repo.prices();
    if (!mounted) return;
    String fmt(double v) =>
        v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
    setState(() {
      _checkup.text = fmt(prices['checkup'] ?? 0);
      for (final e in _sessions.entries) {
        e.value.text = fmt(prices[e.key] ?? 0);
      }
      _loaded = true;
    });
  }

  @override
  void dispose() {
    _checkup.dispose();
    _duration.dispose();
    _footer.dispose();
    for (final c in _sessions.values) {
      c.dispose();
    }
    super.dispose();
  }

  static double? _parse(String text) {
    final t = normalizeDigits(text.trim()).replaceAll('٫', '.');
    if (t.isEmpty) return 0;
    final v = double.tryParse(t);
    return v == null || !v.isFinite || v < 0 ? null : v;
  }

  Future<void> _save() async {
    final checkup = _parse(_checkup.text);
    final sessions = {
      for (final e in _sessions.entries) e.key: _parse(e.value.text),
    };
    if (checkup == null || sessions.values.any((v) => v == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل أسعاراً رقمية غير سالبة')),
      );
      return;
    }
    final base = widget.settings;
    final duration = int.tryParse(normalizeDigits(_duration.text.trim()));
    if (base != null && (duration == null || duration <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل مدة موعد صحيحة بالدقائق')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      if (base != null) {
        final save = widget.onSaveSettings;
        if (save != null) {
          await save(
            ClinicSettings(
              clinicName: base.clinicName,
              doctorName: base.doctorName,
              specialty: base.specialty,
              phone: base.phone,
              address: base.address,
              defaultFee: base.defaultFee,
              visitDuration: duration!,
              footerNote: _footer.text.trim(),
            ),
          );
        }
      }
      await _repo.savePrices(
        checkup: checkup,
        sessions: {for (final e in sessions.entries) e.key: e.value!},
      );
      await widget.onSaved?.call();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم الحفظ'),
          backgroundColor: AppColors.success,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const SizedBox(
        height: 60,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'تُستخدم تلقائياً عند تسجيل الدفع، وتظهر في مالية المعاينات والجلسات كلٌّ في قسمه',
          style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 14,
          runSpacing: 18,
          children: [
            SizedBox(
              width: 220,
              child: AppNumberField(
                key: const Key('priceCheckup'),
                controller: _checkup,
                label: 'سعر المعاينة',
                isDouble: true,
              ),
            ),
            for (final e in _sessions.entries)
              SizedBox(
                width: 220,
                child: AppNumberField(
                  key: Key('price:${e.key}'),
                  controller: e.value,
                  label: 'سعر ${e.key}',
                  isDouble: true,
                ),
              ),
          ],
        ),
        if (widget.settings != null) ...[
          const SizedBox(height: 18),
          Wrap(
            spacing: 14,
            runSpacing: 18,
            children: [
              SizedBox(
                width: 220,
                child: AppNumberField(
                  key: const Key('visitDuration'),
                  controller: _duration,
                  label: 'مدة الموعد (دقيقة)',
                ),
              ),
              // عرض مربعين تماماً ← يتحاذى الصف مع صف الأسعار أعلاه.
              SizedBox(
                width: 454,
                child: AppTextField(
                  key: const Key('footerNote'),
                  controller: _footer,
                  label: 'ملاحظة أسفل الوصفة',
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 18),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: SizedBox(
            height: AppSizes.control,
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save_outlined, size: 18),
              label: Text(widget.settings == null ? 'حفظ الأسعار' : 'حفظ'),
            ),
          ),
        ),
      ],
    );
  }
}

/// بطاقة «صورة الشعار»: رفع صورة جديدة (مع معاينة وتأكيد قبل الاعتماد)
/// أو استعادة الصورة الافتراضية. تظهر في نافذة الدخول وأعلى كل النوافذ.
class ClinicLogoSettings extends StatefulWidget {
  const ClinicLogoSettings({super.key});

  /// اختيار الصورة. قابل للاستبدال في الاختبارات.
  static Future<Uint8List?> Function() pickImage = () async {
    final pick = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg', 'webp', 'bmp'],
      dialogTitle: 'اختر صورة الشعار',
    );
    final path = pick?.files.single.path;
    if (path == null) return null;
    return File(path).readAsBytes();
  };

  @override
  State<ClinicLogoSettings> createState() => _ClinicLogoSettingsState();
}

class _ClinicLogoSettingsState extends State<ClinicLogoSettings> {
  bool _busy = false;
  String? _message;
  bool _error = false;

  void _say(String m, {bool error = false}) => setState(() {
    _message = m;
    _error = error;
  });

  Future<void> _upload() async {
    final provider = context.read<SettingsProvider>();
    setState(() => _busy = true);
    try {
      final bytes = await ClinicLogoSettings.pickImage();
      if (bytes == null || !mounted) return;
      if (bytes.length > LogoRepository.maxBytes) {
        _say('حجم الصورة يجب ألا يتجاوز 8 ميغابايت', error: true);
        return;
      }
      // تأكد أن الملف صورة صالحة قبل عرضها.
      try {
        final codec = await ui.instantiateImageCodec(bytes);
        (await codec.getNextFrame()).image.dispose();
        codec.dispose();
      } catch (_) {
        if (mounted) _say('الملف المختار ليس صورة صالحة', error: true);
        return;
      }
      if (!mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          key: const Key('logoConfirm'),
          title: const Text('معاينة صورة الشعار'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.navy, width: 4),
                  image: DecorationImage(
                    image: MemoryImage(bytes),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'هكذا ستظهر الصورة (دائرية) في نافذة الدخول وأعلى كل النوافذ.\nهل تريد اعتمادها؟',
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            FilledButton.icon(
              key: const Key('logoConfirmOk'),
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.check, size: 18),
              label: const Text('اعتماد الصورة'),
            ),
            TextButton.icon(
              key: const Key('logoConfirmCancel'),
              onPressed: () => Navigator.pop(ctx, false),
              icon: const Icon(Icons.close, size: 18),
              label: const Text('إلغاء'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
      await provider.setLogo(bytes);
      if (mounted) _say('تم اعتماد الصورة الجديدة في كل النوافذ');
    } catch (e) {
      if (mounted) _say('تعذّر حفظ الصورة: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    setState(() => _busy = true);
    try {
      await context.read<SettingsProvider>().resetLogo();
      if (mounted) _say('أُعيدت الصورة الافتراضية');
    } catch (e) {
      if (mounted) _say('تعذّر استعادة الصورة: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final custom = context.watch<SettingsProvider>().logo != null;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const ClinicLogo(size: 104, ringColor: AppColors.navy, ringWidth: 3, useSavedLogo: true),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                custom ? 'صورة مخصصة' : 'الصورة الافتراضية',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'تظهر دائرية في نافذة الدخول وأعلى كل الأبواب والنوافذ مع اسم العيادة. '
                'الصيغ: PNG أو JPG — ويفضَّل أن يكون الوجه في وسط الصورة.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                ),
              ),
              if (_message != null) ...[
                const SizedBox(height: 8),
                Text(
                  _message!,
                  key: const Key('logoMessage'),
                  style: TextStyle(
                    color: _error ? AppColors.danger : AppColors.paid,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      key: const Key('logoUpload'),
                      onPressed: _busy ? null : _upload,
                      icon: const Icon(Icons.upload_outlined, size: 18),
                      label: const Text('رفع صورة جديدة'),
                    ),
                    FilledButton.icon(
                      key: const Key('logoReset'),
                      onPressed: _busy || !custom ? null : _reset,
                      icon: const Icon(Icons.restore, size: 18),
                      label: const Text('استعادة الصورة الافتراضية'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

