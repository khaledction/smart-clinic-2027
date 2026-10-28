import 'package:flutter/material.dart';

import '../../core/services/password_recovery.dart';
import '../../core/theme/app_colors.dart';
import '../../data/repositories/app_prefs_repository.dart';

/// نافذة «نسيت كلمة المرور»: خطوة 1 إرسال الرمز، خطوة 2 إدخاله مع كلمة جديدة.
/// تعيد اسم المستخدم عند النجاح.
class ForgotPasswordDialog extends StatefulWidget {
  const ForgotPasswordDialog({super.key, this.username = ''});

  final String username;

  static Future<String?> show(BuildContext context, {String username = ''}) =>
      showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (_) => ForgotPasswordDialog(username: username),
      );

  @override
  State<ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<ForgotPasswordDialog> {
  final _recovery = PasswordRecovery();
  late final _user = TextEditingController(
    text: widget.username.trim().isEmpty ? 'admin' : widget.username.trim(),
  );
  final _code = TextEditingController();
  final _pass = TextEditingController();
  final _pass2 = TextEditingController();
  AppPrefs? _prefs;
  bool _codeSent = false;
  bool _busy = false;
  String? _error;
  String? _info;

  @override
  void initState() {
    super.initState();
    _recovery.prefs().then((p) {
      if (mounted) setState(() => _prefs = p);
    });
  }

  @override
  void dispose() {
    for (final c in [_user, _code, _pass, _pass2]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _send(RecoveryChannel channel) async {
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      await _recovery.sendCode(_user.text, channel);
      if (!mounted) return;
      setState(() {
        _codeSent = true;
        _info = channel == RecoveryChannel.email
            ? 'فُتح برنامج البريد برسالة الرمز إلى ${PasswordRecovery.maskEmail(_prefs!.recoveryEmail)} — اضغط إرسال فيه.'
            : 'فُتح واتساب برسالة الرمز إلى ${PasswordRecovery.maskPhone(_prefs!.recoveryWhatsapp)} — اضغط إرسال فيه.';
      });
    } on StateError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'تعذّر الإرسال: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    if (_pass.text != _pass2.text) {
      setState(() => _error = 'كلمتا المرور غير متطابقتين.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _recovery.reset(_user.text, _code.text, _pass.text);
      if (mounted) Navigator.pop(context, _user.text.trim());
    } on StateError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _prefs;
    final none = p != null && !p.canEmail && !p.canWhatsapp;
    return AlertDialog(
      title: const Text('نسيت كلمة المرور'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 6),
              TextField(
                key: const Key('forgotUser'),
                controller: _user,
                enabled: !_codeSent && !_busy,
                decoration: const InputDecoration(
                  labelText: 'اسم المستخدم',
                  suffixIcon: Icon(Icons.person_outline, size: 18),
                ),
              ),
              const SizedBox(height: 18),
              if (p == null)
                const Center(child: CircularProgressIndicator())
              else if (none)
                const _Note(
                  icon: Icons.info_outline,
                  color: AppColors.warning,
                  text:
                      'لم يُضبط بريد أو رقم واتساب للاستعادة. يضبطهما المدير من '
                      'الإعدادات ← استعادة كلمة المرور.',
                )
              else if (!_codeSent) ...[
                const Text(
                  'اختر طريقة إرسال رمز الاستعادة:',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      key: const Key('forgotByEmail'),
                      onPressed: _busy || !p.canEmail
                          ? null
                          : () => _send(RecoveryChannel.email),
                      icon: const Icon(Icons.email_outlined, size: 18),
                      label: Text(
                        p.canEmail
                            ? 'إرسال إلى البريد ${PasswordRecovery.maskEmail(p.recoveryEmail)}'
                            : 'البريد غير مضبوط',
                      ),
                    ),
                    FilledButton.icon(
                      key: const Key('forgotByWhatsapp'),
                      onPressed: _busy || !p.canWhatsapp
                          ? null
                          : () => _send(RecoveryChannel.whatsapp),
                      icon: const Icon(Icons.chat_outlined, size: 18),
                      label: Text(
                        p.canWhatsapp
                            ? 'إرسال تنبيه واتساب ${PasswordRecovery.maskPhone(p.recoveryWhatsapp)}'
                            : 'واتساب غير مضبوط',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(),
                const SizedBox(height: 6),
                Center(
                  child: TextButton.icon(
                    key: const Key('enterMasterPinBtn'),
                    onPressed: _busy ? null : () => setState(() => _codeSent = true),
                    icon: const Icon(Icons.pin_outlined, size: 18),
                    label: const Text('أو الاستعادة المباشرة برمز PIN الرئيسي للعيادة'),
                  ),
                ),
              ] else ...[
                TextField(
                  key: const Key('forgotCode'),
                  controller: _code,
                  keyboardType: TextInputType.text,
                  maxLength: 16,
                  decoration: const InputDecoration(
                    labelText: 'رمز الاستعادة أو رمز PIN الرئيسي للعيادة',
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 18),
                TextField(
                  key: const Key('forgotPass'),
                  controller: _pass,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'كلمة المرور الجديدة',
                  ),
                ),
                const SizedBox(height: 18),
                TextField(
                  key: const Key('forgotPass2'),
                  controller: _pass2,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'تأكيد كلمة المرور الجديدة',
                  ),
                ),
              ],
              if (_info != null) ...[
                const SizedBox(height: 14),
                _Note(
                  icon: Icons.check_circle_outline,
                  color: AppColors.success,
                  text: _info!,
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 14),
                _Note(
                  icon: Icons.error_outline,
                  color: AppColors.danger,
                  text: _error!,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        if (_codeSent) ...[
          TextButton(
            onPressed: _busy
                ? null
                : () => setState(() {
                    _codeSent = false;
                    _info = null;
                    _error = null;
                  }),
            child: const Text('إعادة الإرسال'),
          ),
          FilledButton(
            key: const Key('forgotReset'),
            onPressed: _busy ? null : _reset,
            child: const Text('تغيير كلمة المرور'),
          ),
        ],
      ],
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.color, required this.text});
  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withValues(alpha: 0.35)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 12.5, height: 1.6, color: color),
          ),
        ),
      ],
    ),
  );
}

