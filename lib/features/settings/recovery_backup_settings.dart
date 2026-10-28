import 'dart:io';

import 'package:bcrypt/bcrypt.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/services/auto_backup.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_sizes.dart';
import '../../core/utils/date_fmt.dart';
import '../../data/repositories/app_prefs_repository.dart';

/// الإعدادات ← «استعادة كلمة المرور»: رقم الواتساب والبريد ورمز PIN الأمان الرئيسي
class RecoverySettings extends StatefulWidget {
  const RecoverySettings({super.key});

  @override
  State<RecoverySettings> createState() => _RecoverySettingsState();
}

class _RecoverySettingsState extends State<RecoverySettings> {
  final _repo = AppPrefsRepository();
  final _email = TextEditingController();
  final _whatsapp = TextEditingController();
  final _pin = TextEditingController();
  bool _obscurePin = true;
  bool _hasSavedPin = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _repo.load().then((p) {
      if (!mounted) return;
      setState(() {
        _email.text = p.recoveryEmail;
        _whatsapp.text = p.recoveryWhatsapp;
        _hasSavedPin = p.hasRecoveryPin;
        _loaded = true;
      });
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _whatsapp.dispose();
    _pin.dispose();
    super.dispose();
  }

  void _say(String m, {bool ok = true}) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(m),
          backgroundColor: ok ? AppColors.success : AppColors.danger,
        ),
      );

  Future<void> _save() async {
    final email = _email.text.trim();
    if (email.isNotEmpty && !email.contains('@')) {
      _say('البريد غير صحيح (أو اتركه فارغاً)', ok: false);
      return;
    }
    final pin = _pin.text.trim();
    if (pin.isNotEmpty && pin.length < 6) {
      _say('رمز PIN الرئيسي يجب ألا يقل عن 6 أرقام', ok: false);
      return;
    }

    await _repo.update(
      (p) => p.copyWith(
        recoveryEmail: email,
        recoveryWhatsapp: _whatsapp.text.trim(),
        recoveryPinHash: pin.isNotEmpty
            ? BCrypt.hashpw(pin, BCrypt.gensalt())
            : p.recoveryPinHash,
      ),
    );
    if (pin.isNotEmpty) {
      setState(() {
        _hasSavedPin = true;
        _pin.clear();
      });
    }
    if (mounted) _say('تم حفظ بيانات الاستعادة بنجاح');
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
          'إعدادات استعادة كلمة المرور: رمز PIN الرئيسي للأمان للعيادة، أو الإشعار عبر الواتساب والبريد.',
          style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 14,
          runSpacing: 18,
          children: [
            SizedBox(
              width: 340,
              child: TextField(
                key: const Key('recoveryPin'),
                controller: _pin,
                obscureText: _obscurePin,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: _hasSavedPin
                      ? 'تغيير رمز PIN الرئيسي للأمان (مضبوط مسبقاً)'
                      : 'تعيين رمز PIN الرئيسي للأمان للعيادة',
                  helperText: 'رمز سري للطبيب لاستعادة الوصول الفوري دون شبكة',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePin
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 18,
                    ),
                    onPressed: () => setState(() => _obscurePin = !_obscurePin),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 340,
              child: TextField(
                key: const Key('recoveryWhatsapp'),
                controller: _whatsapp,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'رقم واتساب',
                  helperText: 'مثل 09xxxxxxxx أو 9639xxxxxxxx',
                  suffixIcon: Icon(Icons.chat_outlined, size: 18),
                ),
              ),
            ),
            SizedBox(
              width: 340,
              child: TextField(
                key: const Key('recoveryEmail'),
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'البريد الإلكتروني (اختياري)',
                  helperText: 'يُفتح برنامج البريد برسالة فيها الرمز',
                  suffixIcon: Icon(Icons.email_outlined, size: 18),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: SizedBox(
            height: AppSizes.control,
            child: FilledButton.icon(
              key: const Key('recoverySave'),
              onPressed: _save,
              icon: const Icon(Icons.save_outlined, size: 18),
              label: const Text('حفظ'),
            ),
          ),
        ),
      ],
    );
  }
}

/// الإعدادات ← النسخ الاحتياطي ← «النسخ التلقائي اليومي».
class AutoBackupSettings extends StatefulWidget {
  const AutoBackupSettings({super.key});

  /// اختيار مجلد — قابل للاستبدال في الاختبارات.
  static Future<String?> Function() pickFolder = () => FilePicker.platform
      .getDirectoryPath(dialogTitle: 'اختر مجلداً ثانياً للنسخ');

  @override
  State<AutoBackupSettings> createState() => _AutoBackupSettingsState();
}

class _AutoBackupSettingsState extends State<AutoBackupSettings> {
  final _repo = AppPrefsRepository();
  AppPrefs? _prefs;
  String? _folder;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final p = await _repo.load();
    String? folder;
    try {
      folder = (await AutoBackup.folder()).path;
    } catch (_) {}
    if (mounted) {
      setState(() {
        _prefs = p;
        _folder = folder;
      });
    }
  }

  void _say(String m, {bool ok = true}) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(m),
          backgroundColor: ok ? AppColors.success : AppColors.danger,
        ),
      );

  Future<void> _set(AppPrefs Function(AppPrefs) change) async {
    final p = await _repo.update(change);
    if (mounted) setState(() => _prefs = p);
  }

  Future<void> _backupNow() async {
    setState(() => _busy = true);
    try {
      final r = await AutoBackup.runIfDue(force: true);
      await _reload();
      if (!mounted) return;
      if (r?.secondError != null) {
        _say(r!.secondError!, ok: false);
      } else {
        _say('تم إنشاء نسخة اليوم');
      }
    } catch (e) {
      if (mounted) _say('تعذّر النسخ: $e', ok: false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openFolder() async {
    final f = _folder;
    if (f == null) return;
    await Directory(f).create(recursive: true);
    if (Platform.isWindows) {
      await Process.start('explorer', [f]);
    } else if (Platform.isMacOS) {
      await Process.start('open', [f]);
    } else {
      await Process.start('xdg-open', [f]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _prefs;
    if (p == null) return const SizedBox(height: 40);
    final last = p.lastAutoBackup;
    final stale =
        last == null ||
        DateTime.now().difference(last) > const Duration(days: 2);
    final lastText = last == null
        ? 'لم تُنشأ أي نسخة تلقائية بعد'
        : 'آخر نسخة تلقائية: ${DateFmt.date(last)}  ${DateFmt.time(last)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.schedule, size: 20, color: AppColors.navy),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'نسخ احتياطي تلقائي يومي',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
            ),
            Switch(
              key: const Key('autoBackupSwitch'),
              value: p.autoBackup,
              onChanged: (v) => _set((x) => x.copyWith(autoBackup: v)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'نسخة عند أول تشغيل في اليوم • يُحتفظ بآخر 30 يوماً ونسخة لكل شهر '
          'لآخر 12 شهراً • الأقدم يُحذف تلقائياً.',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Icon(
              stale ? Icons.warning_amber_rounded : Icons.check_circle_outline,
              size: 18,
              color: stale ? AppColors.warning : AppColors.success,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                lastText,
                key: const Key('autoBackupLast'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: stale ? AppColors.warning : AppColors.success,
                ),
              ),
            ),
          ],
        ),
        if (_folder != null) ...[
          const SizedBox(height: 6),
          _PathLine(label: 'المجلد:', path: _folder!),
        ],
        const SizedBox(height: 4),
        _PathLine(
          key: const Key('autoBackupDir2'),
          label: 'المجلد الثاني:',
          path: p.backupDir2,
          empty: 'غير محدد (يُنصح بفلاشة أو قرص آخر)',
        ),
        const SizedBox(height: 12),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (p.backupDir2.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () => _set((x) => x.copyWith(backupDir2: '')),
                  icon: const Icon(Icons.folder_off_outlined, size: 17),
                  label: const Text('إزالة المجلد الثاني'),
                ),
              OutlinedButton.icon(
                key: const Key('autoBackupPickDir2'),
                onPressed: () async {
                  final dir = await AutoBackupSettings.pickFolder();
                  if (dir == null || dir.trim().isEmpty) return;
                  await _set((x) => x.copyWith(backupDir2: dir.trim()));
                },
                icon: const Icon(Icons.create_new_folder_outlined, size: 17),
                label: const Text('اختيار مجلد ثانٍ'),
              ),
              OutlinedButton.icon(
                onPressed: _folder == null ? null : _openFolder,
                icon: const Icon(Icons.folder_open_outlined, size: 17),
                label: const Text('فتح مجلد النسخ'),
              ),
              FilledButton.icon(
                key: const Key('autoBackupNow'),
                onPressed: _busy ? null : _backupNow,
                icon: const Icon(Icons.backup_outlined, size: 17),
                label: Text(_busy ? 'جارٍ النسخ…' : 'نسخ الآن'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// سطر «عنوان: مسار» — المسار يُعرض من اليسار لليمين حتى لا ينقلب.
class _PathLine extends StatelessWidget {
  const _PathLine({
    super.key,
    required this.label,
    required this.path,
    this.empty = '',
  });

  final String label;
  final String path;
  final String empty;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 12, color: AppColors.textSecondary);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: style),
        const SizedBox(width: 6),
        Expanded(
          child: path.isEmpty
              ? Text(empty, style: style)
              : Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: SelectableText(
                    path,
                    textDirection: TextDirection.ltr,
                    style: style,
                  ),
                ),
        ),
      ],
    );
  }
}

