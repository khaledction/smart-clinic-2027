import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/services/developer_mode.dart';
import '../../core/services/device_activation.dart';
import '../../core/services/password_recovery.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/window_controls.dart';
import '../settings/about_card.dart';

/// شاشة تفعيل ترخيص برنامج Smart Clinic لإدارة العيادات الطبية
/// - تعرض باقات ومدد الترخيص المعتمدة (شهرية، 3 أشهر، 6 أشهر، 9 أشهر، سنة، سنتان)
/// - تقفل مربع الإدخال بعد محاولتين فاشلتين وتظهر رسالة التحذير المعتمدة
/// - تتيح التجديد بكود جديد حصراً من المطور
class ActivationScreen extends StatefulWidget {
  const ActivationScreen({super.key});

  @override
  State<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends State<ActivationScreen> {
  final _codeCtrl = TextEditingController();
  final _devUser = TextEditingController(text: 'khaled.a.f');
  final _devPass = TextEditingController();
  final _unlockCtrl = TextEditingController();

  LicenseDuration? _selectedDuration;
  bool _showDev = false;
  bool _showUnlockDialog = false;
  String? _error;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _codeCtrl.addListener(_onCodeChanged);
  }

  @override
  void dispose() {
    _codeCtrl.removeListener(_onCodeChanged);
    _codeCtrl.dispose();
    _devUser.dispose();
    _devPass.dispose();
    _unlockCtrl.dispose();
    super.dispose();
  }

  /// يكتشف الباقة تلقائياً عند لصق أو كتابة الكود
  void _onCodeChanged() {
    final text = _codeCtrl.text.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    if ((text.startsWith('DA') || text.startsWith('SC')) && text.length >= 4) {
      final codePart = text.substring(2, 4);
      final dur = LicenseDuration.fromCode(codePart);
      if (dur != null && dur != _selectedDuration) {
        setState(() => _selectedDuration = dur);
      }
    }
  }

  void _activateWithCode() {
    final input = _codeCtrl.text.trim();
    if (input.isEmpty) {
      setState(() => _error = 'يرجى إدخال كود التفعيل.');
      return;
    }

    final res = DeviceActivation.activateWithCode(input);
    setState(() {
      if (res.success) {
        _error = null;
        _successMessage = res.message;
      } else {
        _error = res.message;
      }
    });

    if (res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _recover() {
    final ok = DeviceActivation.recover();
    if (!ok) {
      setState(() => _error = 'تعذّرت استعادة التفعيل السابق.');
    }
  }

  void _devActivate() {
    final dev = DeveloperMode.tryLogin(_devUser.text, _devPass.text);
    if (dev == null) {
      setState(() => _error = 'اسم المبرمج أو كلمة المرور غير صحيحة.');
      return;
    }
    // وضع المبرمج يفك القفل ويفعّل البرنامج
    DeviceActivation.developerActivate(
      duration: _selectedDuration ?? LicenseDuration.oneYear,
    );
  }

  void _devResetLockoutOnly() {
    final dev = DeveloperMode.tryLogin(_devUser.text, _devPass.text);
    if (dev == null) {
      setState(() => _error = 'اسم المبرمج أو كلمة المرور غير صحيحة.');
      return;
    }
    DeviceActivation.resetLockout();
    setState(() {
      _error = null;
      _showDev = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم إلغاء القفل وتصفير عدد المحاولات بنجاح.'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _submitUnlockCode() {
    final ok = DeviceActivation.unlockWithCode(_unlockCtrl.text);
    if (ok) {
      setState(() {
        _error = null;
        _showUnlockDialog = false;
      });
      _unlockCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم فك القفل بنجاح، يمكنك الآن إدخال كود التفعيل.'),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      setState(() {
        _error = 'كود فك القفل غير صحيح أو لا يطابق هذا الجهاز.';
      });
    }
  }

  void _copyDeviceId() {
    Clipboard.setData(ClipboardData(text: DeviceActivation.deviceId));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم نسخ رمز الجهاز إلى الحافظة بنجاح'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLocked = DeviceActivation.isLocked;
    final isExpired = DeviceActivation.isExpired;
    final isTampered = DeviceActivation.isClockTampered;
    final failedCount = DeviceActivation.failedAttempts;
    final remainingAttempts = DeviceActivation.maxFailedAttempts - failedCount;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: const PreferredSize(
        preferredSize: Size.fromHeight(48),
        child: LoginWindowStrip(),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isLocked
                      ? AppColors.danger.withValues(alpha: 0.5)
                      : AppColors.navy.withValues(alpha: 0.15),
                  width: isLocked ? 2 : 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ========================================================
                    // 1) الترويسة والشعار
                    // ========================================================
                    Center(
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: AppColors.navy.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isLocked ? Icons.lock_outline_rounded : Icons.verified_user_outlined,
                          size: 40,
                          color: isLocked ? AppColors.danger : AppColors.navy,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'تفعيل ترخيص برنامج Smart Clinic',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'نظام إدارة وتنظيم عمل العيادات الطبية — ترخيص محدد المدة',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: AppColors.textSecondary,
                      ),
                    ),

                    // ========================================================
                    // 2) تنبيهات الحالة (انتهاء اشتراك / تلاعب وقت)
                    // ========================================================
                    if (isExpired && !isTampered) ...[
                      const SizedBox(height: 16),
                      _AlertBanner(
                        color: AppColors.danger,
                        icon: Icons.timer_off_outlined,
                        title: 'انتهت مدة الترخيص السابقة لهذا الجهاز',
                        message: 'لتجديد الاشتراك ومتابعة العمل، يرجى تزويد المطور برمز الجهاز للحصول على كود تجديد جديد حصراً. بيانات العيادة ومرضاها محفوظة بأمان تام.',
                      ),
                    ],

                    if (isTampered) ...[
                      const SizedBox(height: 16),
                      const _AlertBanner(
                        color: AppColors.danger,
                        icon: Icons.access_time_filled_rounded,
                        title: 'تنبيه: اختلاف في توقيت النظام',
                        message: 'تم رصد اختلاف غير متطابق في تاريخ وساعة الجهاز. يرجى ضبط الوقت والتاريخ بدقة لتفعيل الترخيص.',
                      ),
                    ],

                    // ========================================================
                    // 3) رمز الجهاز (مع زر النسخ)
                    // ========================================================
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.navy.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.navy.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.computer_rounded, color: AppColors.navy, size: 22),
                          const SizedBox(width: 12),
                          const Text(
                            'رمز الجهاز: ',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.navy,
                            ),
                          ),
                          SelectableText(
                            DeviceActivation.deviceId,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                              color: AppColors.navy,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const Spacer(),
                          IconButton.filledTonal(
                            tooltip: 'نسخ رمز الجهاز لإرساله للمطور',
                            icon: const Icon(Icons.copy_rounded, size: 18),
                            onPressed: _copyDeviceId,
                          ),
                        ],
                      ),
                    ),

                    // ========================================================
                    // 4) عرض المدد المرخص لها أثناء أول تشغيل (وفق المتطلبات)
                    // ========================================================
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        const Icon(Icons.calendar_month_outlined, size: 18, color: AppColors.navy),
                        const SizedBox(width: 8),
                        const Text(
                          'المدد المتاحة للترخيص:',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.navy,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'تتحدد وفق الكود الممنوح من المطور',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildDurationsGrid(),

                    // ========================================================
                    // 5) استعادة التفعيل (إن وُجد سجل متوافق)
                    // ========================================================
                    if (DeviceActivation.recoveryAvailable) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.restore_rounded, color: AppColors.success),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'عُثر على تفعيل سابق محفوظ على القرص.',
                                style: TextStyle(fontSize: 13),
                              ),
                            ),
                            FilledButton.tonal(
                              onPressed: _recover,
                              child: const Text('استعادة التفعيل'),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // ========================================================
                    // 6) منطقة إدخال الكود أو رسالة القفل بعد محاولتين فاشلتين
                    // ========================================================
                    if (isLocked) ...[
                      // ----------------- القفل بعد محاولتين فاشلتين -----------------
                      _buildLockedWarning(),
                    ] else ...[
                      // ----------------- مربع إدخال الكود متاح -----------------
                      _buildCodeInputSection(remainingAttempts),
                    ],

                    // ========================================================
                    // 7) رسائل الخطأ والنجاح
                    // ========================================================
                    if (_error != null && !isLocked) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error!,
                                style: const TextStyle(
                                  color: AppColors.danger,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    if (_successMessage != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_outline, color: AppColors.success, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _successMessage!,
                                style: const TextStyle(
                                  color: AppColors.success,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // ========================================================
                    // 8) خيارات المطور / فك القفل
                    // ========================================================
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton.icon(
                          onPressed: () => setState(() {
                            _showDev = !_showDev;
                            _showUnlockDialog = false;
                          }),
                          icon: const Icon(Icons.admin_panel_settings_outlined, size: 17),
                          label: Text(_showDev ? 'إخفاء خيارات المطور' : 'دخول المبرمج'),
                        ),
                        if (isLocked) ...[
                          const SizedBox(width: 12),
                          TextButton.icon(
                            onPressed: () => setState(() {
                              _showUnlockDialog = !_showUnlockDialog;
                              _showDev = false;
                            }),
                            icon: const Icon(Icons.vpn_key_outlined, size: 17),
                            label: const Text('إدخال كود فك القفل'),
                          ),
                        ],
                      ],
                    ),

                    if (_showDev) ...[
                      const SizedBox(height: 12),
                      _buildDevSection(isLocked),
                    ],

                    if (_showUnlockDialog && isLocked) ...[
                      const SizedBox(height: 12),
                      _buildUnlockCodeSection(),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// شبكة عرض المدد المرخص لها الستة (شهرية، 3 أشهر، 6 أشهر، 9 أشهر، سنة، سنتان)
  Widget _buildDurationsGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final colCount = constraints.maxWidth > 500 ? 3 : 2;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: colCount,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 2.3,
          children: LicenseDuration.values.map((dur) {
            final isSelected = dur == _selectedDuration;
            return InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                setState(() => _selectedDuration = dur);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.navy.withValues(alpha: 0.08)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? AppColors.navy : AppColors.divider,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                      size: 18,
                      color: isSelected ? AppColors.navy : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dur.label,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                              color: isSelected ? AppColors.navy : AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            dur.description,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  /// الرسالة التنبيهية الإلزامية عند استنفاد محاولتين فاشلتين (يختفي مربع الإدخال تماماً)
  Widget _buildLockedWarning() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.danger.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.shield_outlined,
            size: 46,
            color: AppColors.danger,
          ),
          const SizedBox(height: 12),
          const Text(
            'لا تحاول أكثر كي لا تخسر البيانات، اتصل بالمطور',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16.5,
              fontWeight: FontWeight.w800,
              color: AppColors.danger,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'تم قفل مربع إدخال كود التفعيل لحماية المنظومة بعد تسجيل محاولتين غير صحيحتين.\n'
            'بيانات العيادة وملفات المرضى محفوظة بأمان تام على D:\\myclinic.\n'
            'يرجى التواصل مع المطور لإعادة فتح المنظومة بكود التفعيل المعتمد.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.6,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          // أزرار التواصل المباشر مع المطور
          Wrap(
            spacing: 12,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                ),
                onPressed: () => PasswordRecovery.openUri(Uri.parse(kDevWhatsappUrl)),
                icon: const Icon(Icons.chat_bubble_outline, size: 17),
                label: const Text('واتساب المطور'),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.navy,
                ),
                onPressed: () => PasswordRecovery.openUri(Uri.parse('tel:$kDevPhone')),
                icon: const Icon(Icons.phone_outlined, size: 17),
                label: const Text(kDevPhone),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.navy,
                ),
                onPressed: () => PasswordRecovery.openUri(Uri.parse('mailto:$kDevEmail')),
                icon: const Icon(Icons.email_outlined, size: 17),
                label: const Text('إيميل المطور'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// قسم إدخال كود التفعيل (يظهر فقط طالما لم يتم استنفاد المحاولتين)
  Widget _buildCodeInputSection(int remainingAttempts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Text(
              'كود التفعيل المرخص:',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: remainingAttempts == 1
                    ? AppColors.danger.withValues(alpha: 0.1)
                    : AppColors.navy.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'المحاولات المتبقية: $remainingAttempts من 2',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: remainingAttempts == 1 ? AppColors.danger : AppColors.navy,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _codeCtrl,
          textCapitalization: TextCapitalization.characters,
          autocorrect: false,
          style: const TextStyle(
            letterSpacing: 1.5,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            fontFamily: 'monospace',
          ),
          decoration: InputDecoration(
            hintText: 'مثال: DA-6M-K3R8-24AB-53DA-7D02',
            hintStyle: TextStyle(
              letterSpacing: 1,
              fontSize: 13,
              fontFamily: 'monospace',
              color: AppColors.textSecondary.withValues(alpha: 0.5),
            ),
            suffixIcon: IconButton(
              tooltip: 'لصق الكود من الحافظة',
              icon: const Icon(Icons.paste_rounded, size: 19),
              onPressed: () async {
                final data = await Clipboard.getData(Clipboard.kTextPlain);
                if (data?.text != null) {
                  _codeCtrl.text = data!.text!.trim();
                }
              },
            ),
          ),
          onSubmitted: (_) => _activateWithCode(),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 50,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.navy,
            ),
            onPressed: _activateWithCode,
            icon: const Icon(Icons.check_circle_outline, size: 20),
            label: const Text(
              'تفعيل الترخيص بالمدة المرخصة',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  /// قسم دخول المبرمج المباشر
  Widget _buildDevSection(bool isLocked) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.navy.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.navy.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'تسجيل دخول المبرمج (Loraneem Tech)',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _devUser,
            decoration: const InputDecoration(
              labelText: 'اسم مستخدم المبرمج',
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _devPass,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'كلمة المرور',
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (isLocked)
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.navy,
                    ),
                    onPressed: _devResetLockoutOnly,
                    icon: const Icon(Icons.lock_open_rounded, size: 18),
                    label: const Text('فك القفل وتصفير المحاولات'),
                  ),
                ),
              if (isLocked) const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.navy,
                  ),
                  onPressed: _devActivate,
                  icon: const Icon(Icons.vpn_key_rounded, size: 18),
                  label: const Text('تفعيل مباشر للجهاز'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// قسم إدخال كود فك القفل الممنوح من المطور
  Widget _buildUnlockCodeSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.navy.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.navy.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'إدخال كود فك القفل الممنوح من المطور',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'إذا زودك المطور بكود فك القفل، أدخله هنا لإعادة إتاحة مربع إدخال كود التفعيل.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _unlockCtrl,
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(
              fontFamily: 'monospace',
              letterSpacing: 1.5,
              fontWeight: FontWeight.w700,
            ),
            decoration: const InputDecoration(
              hintText: 'DA-UNLOCK-XXXX-XXXX-XXXX-XXXX',
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.navy,
            ),
            onPressed: _submitUnlockCode,
            icon: const Icon(Icons.lock_open_rounded, size: 18),
            label: const Text('إلغاء قفل مربع الإدخال'),
          ),
        ],
      ),
    );
  }
}

/// شريط تنبيه بصري عريض
class _AlertBanner extends StatelessWidget {
  const _AlertBanner({
    required this.color,
    required this.icon,
    required this.title,
    required this.message,
  });

  final Color color;
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.6,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


