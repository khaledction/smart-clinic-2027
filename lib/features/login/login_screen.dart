import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/form_fields.dart';
import '../../data/providers/session_provider.dart';
import '../../core/widgets/clinic_brand.dart';
import '../../core/widgets/window_controls.dart';
import 'forgot_password_dialog.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _user = TextEditingController(text: 'admin');
  final _pass = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final session = context.read<SessionProvider>();
    final ok = await session.login(_user.text, _pass.text);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(session.error ?? 'تعذّر تسجيل الدخول'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();

    return Scaffold(
      // شريط ويندوز الأصلي مخفي ← شريط كحلي رفيع للسحب وأزرار النافذة.
      appBar: const PreferredSize(
        preferredSize: Size.fromHeight(48),
        child: LoginWindowStrip(),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // صورة الطبيب/الشعار دائرية + عبارة الترويسة من الإعدادات.
                    const Center(
                      child: ClinicLogo(
                        size: 136,
                        ringColor: AppColors.navy,
                        ringWidth: 4,
                        shadow: true,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Smart Clinic',
                      key: Key('loginAppName'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.navy,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // سطر واحد تحت الصورة
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 1.5),
                      child: FittedBox(
                        key: Key('loginClinicLines'),
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'برنامج إدارة وتنظيم عمل العيادات الطبية',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    AppTextField(
                      controller: _user,
                      label: 'اسم المستخدم',
                      textInputAction: TextInputAction.next,
                      suffix: const Icon(Icons.person_outline, size: 18),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _pass,
                      obscureText: _obscure,
                      onFieldSubmitted: (_) => _submit(),
                      style: Theme.of(context).textTheme.bodyLarge,
                      decoration: InputDecoration(
                        labelText: 'كلمة المرور',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 18,
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'مطلوب' : null,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 58,
                      child: FilledButton(
                        onPressed: session.isLoading ? null : _submit,
                        child: session.isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('دخول'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: TextButton.icon(
                        key: const Key('forgotPassword'),
                        onPressed: session.isLoading
                            ? null
                            : () async {
                                final user = await ForgotPasswordDialog.show(
                                  context,
                                  username: _user.text,
                                );
                                if (user == null || !context.mounted) return;
                                _user.text = user;
                                _pass.clear();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'تم تغيير كلمة المرور — سجّل الدخول بها الآن',
                                    ),
                                    backgroundColor: AppColors.success,
                                  ),
                                );
                              },
                        icon: const Icon(Icons.lock_reset, size: 18),
                        label: const Text('نسيت كلمة المرور؟'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
