import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_sizes.dart';

/// شارة «تم الدفع» خضراء.
class PaidBadge extends StatelessWidget {
  const PaidBadge({super.key, this.label = 'تم الدفع'});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: AppColors.paid.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.paid.withValues(alpha: 0.55)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle, size: 15, color: AppColors.paid),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.paid,
          ),
        ),
      ],
    ),
  );
}

/// زر «دفع»: أبيض بإطار أخضر، ويصبح أخضر بالكامل بعد تسجيل الدفع.
/// أي نقرة ثانية (نقر مزدوج بالخطأ أو نقرة بعد الدفع) تُظهر تنبيهاً
/// ولا تسجّل دفعة جديدة، فلا يتكرر المبلغ في المالية.
class PayToggle extends StatefulWidget {
  const PayToggle({
    super.key,
    required this.paid,
    required this.onPay,
    this.label = 'دفع',
    this.paidLabel = 'تم الدفع',
    this.enabled = true,
    this.height = AppSizes.rowAction,
    this.tooltip,
    this.repeatMessage,
  });

  /// هل الدفع مسجّل مسبقاً في قاعدة البيانات.
  final bool paid;

  /// يسجّل الدفع ويعيد true عند النجاح.
  final Future<bool> Function() onPay;
  final String label;
  final String paidLabel;
  final bool enabled;
  final double height;
  final String? tooltip;

  /// نص تنبيه التكرار (مثلاً في نموذج الزيارة: يُسجَّل عند الحفظ).
  final String? repeatMessage;

  @override
  State<PayToggle> createState() => _PayToggleState();
}

class _PayToggleState extends State<PayToggle> {
  bool _busy = false;
  bool _justPaid = false;

  bool get _isPaid => widget.paid || _justPaid;

  Future<void> _warnRepeat() => showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(
        Icons.warning_amber_rounded,
        color: AppColors.warning,
        size: 34,
      ),
      title: const Text('تنبيه: الدفع مسجّل مسبقاً'),
      content: Text(
        widget.repeatMessage ??
            (_busy
                ? 'يجري تسجيل هذا الدفع الآن. النقرة الثانية لم تُسجَّل حتى لا يتكرر المبلغ.'
                : 'تم تسجيل هذا الدفع من قبل. لن يُسجَّل مرة ثانية حتى لا يتكرر المبلغ في المالية.'),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('حسناً'),
        ),
      ],
    ),
  );

  Future<void> _tap() async {
    if (_busy || _isPaid) {
      await _warnRepeat();
      return;
    }
    setState(() => _busy = true);
    var ok = false;
    try {
      ok = await widget.onPay();
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          if (ok) _justPaid = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final paid = _isPaid;
    final button = SizedBox(
      height: widget.height,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          backgroundColor: paid ? AppColors.paid : Colors.white,
          foregroundColor: paid ? Colors.white : AppColors.paid,
          iconColor: paid ? Colors.white : AppColors.paid,
          disabledForegroundColor: AppColors.textSecondary,
          side: BorderSide(
            color: widget.enabled || paid ? AppColors.paid : AppColors.divider,
            width: 1.5,
          ),
          // تبديل فوري للون (دون تلاشٍ أخضر على أخضر).
          animationDuration: Duration.zero,
          minimumSize: Size(0, widget.height),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
          ),
        ),
        onPressed: widget.enabled || paid ? _tap : null,
        icon: _busy
            ? const SizedBox(
                width: 15,
                height: 15,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.paid,
                ),
              )
            : Icon(
                paid ? Icons.check_circle : Icons.payments_outlined,
                size: 17,
              ),
        label: Text(
          paid ? widget.paidLabel : widget.label,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
    final tip = widget.tooltip;
    return tip == null ? button : Tooltip(message: tip, child: button);
  }
}
