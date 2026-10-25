import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/providers/settings_provider.dart';
import '../theme/app_colors.dart';
import 'frame_trail.dart';
import 'window_controls.dart';

/// Smart Clinic is the app logo; an uploaded clinic logo remains available in its settings preview.
class ClinicLogo extends StatelessWidget {
  const ClinicLogo({
    super.key,
    this.size = 40,
    this.ringColor = Colors.white,
    this.ringWidth = 2,
    this.shadow = false,
    this.useSavedLogo = false,
  });

  final double size;
  final Color ringColor;
  final double ringWidth;
  final bool shadow;
  final bool useSavedLogo;

  @override
  Widget build(BuildContext context) {
    final custom = useSavedLogo
        ? Provider.of<SettingsProvider?>(context)?.logo
        : null;
    final iconFallback = Icon(
      Icons.local_hospital,
      size: size * 0.58,
      color: AppColors.navy,
    );
    final Widget fallback = ClipOval(
      child: Image.asset(
        'assets/images/smart-clinic.png',
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => iconFallback,
      ),
    );

    return Container(
      key: const Key('clinicLogo'),
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF163750),
        border: Border.all(color: ringColor, width: ringWidth),
        boxShadow: shadow
            ? [
                BoxShadow(
                  color: AppColors.navy.withValues(alpha: 0.25),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: custom == null || custom.isEmpty
          ? fallback
          : ClipOval(
              child: Image.memory(
                custom,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => iconFallback,
              ),
            ),
    );
  }
}
/// اسم العيادة المعتمد في الإعدادات.
String clinicTitleOf(BuildContext context) => clinicNameOneLine(
  Provider.of<SettingsProvider?>(context)?.clinicName ?? 'عيادة الأعصاب',
);

/// اسم العيادة على سطرين: يُحترم فاصل السطر إن وُجد، وإلا يُقسم بعد
/// الكلمة الأولى («عيادة» / «الدكتور طارق نجم مقلد»).
String clinicNameTwoLines(String name) {
  final t = name.trim();
  if (t.contains('\n')) {
    return t
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .join('\n');
  }
  final i = t.indexOf(RegExp(r'\s'));
  if (i <= 0) return t;
  return '${t.substring(0, i)}\n${t.substring(i).trim()}';
}

/// السطر الثالث تحت اسم العيادة في نافذة الدخول.
const String kClinicSpecialtyLine = 'اختصاصي جراحة عصبية ومجهرية';

/// اسم العيادة على سطر واحد (للأماكن الضيقة والطباعة).
String clinicNameOneLine(String name) =>
    name.replaceAll(RegExp(r'\s*\n\s*'), ' ').trim();

/// الشعار + عبارة الترويسة (اسم العيادة من الإعدادات) كأنها لوغو.
class ClinicBrand extends StatelessWidget {
  const ClinicBrand({
    super.key,
    this.logoSize = 36,
    this.color = AppColors.navy,
    this.fontSize = 14.5,
    this.maxWidth = 260,
    this.ringColor = AppColors.navy,
  });

  final double logoSize;
  final Color color;
  final Color ringColor;
  final double fontSize;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Row(
    key: const Key('clinicBrand'),
    mainAxisSize: MainAxisSize.min,
    children: [
      ClinicLogo(size: logoSize, ringColor: ringColor, ringWidth: 1.5),
      const SizedBox(width: 10),
      ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Text(
          clinicTitleOf(context),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color,
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ],
  );
}

/// شريط علوي موحد لكل النوافذ المستقلة (نفس الشريط الكحلي للإطار):
/// الصورة الدائرية الصغيرة يميناً ← زر الرجوع ← مسار النوافذ المفتوحة
/// (مثل: المرضى والمواعيد ‹ الملف الطبي للمريض ‹ زيارة جديدة)،
/// ثم أزرار الشاشة، واسم البرنامج وأزرار النافذة في أقصى اليسار.
class BrandedAppBar extends StatelessWidget implements PreferredSizeWidget {
  const BrandedAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.crumb,
  });

  final Widget title;
  final List<Widget>? actions;
  final Widget? leading;

  /// اسم النافذة في المسار. إن لم يُعطَ يؤخذ من العنوان إن كان نصاً.
  final String? crumb;

  // الارتفاع الأقصى (داخل الإطار: الشريط الكحلي + سطر الأزرار الفاتح).
  // الـ Scaffold يسمح بارتفاع أقل، فالنافذة المستقلة تأخذ الشريط فقط.
  @override
  Size get preferredSize =>
      const Size.fromHeight(kFrameBandHeight + kFrameStripHeight);

  /// أزرار الشاشة على الكحلي: أبيض بخط كحلي حتى تبقى ظاهرة.
  static ThemeData _bandTheme(ThemeData base) {
    ButtonStyle? onNavy(ButtonStyle? s) => s?.copyWith(
      backgroundColor: WidgetStateProperty.resolveWith(
        (st) => st.contains(WidgetState.disabled)
            ? Colors.white.withValues(alpha: 0.45)
            : Colors.white,
      ),
      foregroundColor: const WidgetStatePropertyAll(AppColors.navy),
      iconColor: const WidgetStatePropertyAll(AppColors.navy),
      side: const WidgetStatePropertyAll(BorderSide.none),
    );
    return base.copyWith(
      iconTheme: const IconThemeData(color: Colors.white),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white38,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: onNavy(base.textButtonTheme.style),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: onNavy(base.filledButtonTheme.style),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: onNavy(base.outlinedButtonTheme.style),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: onNavy(base.elevatedButtonTheme.style),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final canPop =
        leading == null &&
        (ModalRoute.of(context)?.impliesAppBarDismissal ?? false);
    final lead = leading ?? (canPop ? const BackButton() : null);
    final t = title;
    FrameTrail.label(
      ModalRoute.of(context),
      crumb ?? (t is Text ? t.data : null),
    );
    final titleStyle = (base.textTheme.titleLarge ?? const TextStyle())
        .copyWith(
          color: Colors.white,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          decorationColor: Colors.white70,
        );

    if (ShellFrameScope.inFrame(context)) {
      return _inFrame(context, base, lead, titleStyle);
    }

    return Material(
      key: const Key('brandedBand'),
      color: AppColors.sidebar,
      child: Theme(
        data: _bandTheme(base),
        child: IconTheme(
          data: const IconThemeData(color: Colors.white),
          child: SizedBox(
            height: kFrameBandHeight,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(start: 16, end: 10),
              child: Row(
                children: [
                  const WindowDragArea(
                    child: ClinicLogo(size: 38, ringWidth: 1.5),
                  ),
                  Container(
                    width: 1,
                    height: 26,
                    margin: const EdgeInsets.symmetric(horizontal: 14),
                    color: Colors.white24,
                  ),
                  if (lead != null) ...[lead, const SizedBox(width: 4)],
                  Expanded(
                    child: Stack(
                      children: [
                        // المساحة الفارغة خلف المسار: سحب + نقرتان للتكبير.
                        const Positioned.fill(
                          child: WindowDragArea(child: SizedBox.expand()),
                        ),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: FrameTrailBar(title: title, style: titleStyle),
                        ),
                      ],
                    ),
                  ),
                  ...?actions,
                  const SizedBox(width: 12),
                  const WindowControls(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// داخل الإطار: القائمة الجانبية ظاهرة (فيها الصورة)، فالشريط الكحلي فيه
  /// الرجوع + اسم النافذة وتحته المسار، ثم أزرار ويندوز. أزرار النافذة نفسها
  /// في سطر فاتح أعلى المساحة البيضاء المنحنية، على اليسار.
  Widget _inFrame(
    BuildContext context,
    ThemeData base,
    Widget? lead,
    TextStyle titleStyle,
  ) {
    final bg =
        context.findAncestorWidgetOfExactType<Scaffold>()?.backgroundColor ??
        base.scaffoldBackgroundColor;
    final hasActions = actions != null && actions!.isNotEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          key: const Key('brandedBand'),
          color: AppColors.sidebar,
          child: Theme(
            data: _bandTheme(base),
            child: IconTheme(
              data: const IconThemeData(color: Colors.white),
              child: SizedBox(
                height: kFrameBandHeight,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(start: 14, end: 10),
                  child: Row(
                    children: [
                      if (lead != null) ...[lead, const SizedBox(width: 6)],
                      Expanded(
                        child: Stack(
                          children: [
                            const Positioned.fill(
                              child: WindowDragArea(child: SizedBox.expand()),
                            ),
                            Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: FrameTrailBar(
                                title: title,
                                style: titleStyle,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      const WindowControls(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        ColoredBox(
          color: AppColors.sidebar,
          child: Container(
            key: const Key('frameStrip'),
            height: hasActions ? kFrameStripHeight : 30,
            padding: const EdgeInsetsDirectional.only(start: 20, end: 14),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: const BorderRadiusDirectional.only(
                topStart: Radius.circular(30),
              ),
            ),
            child: hasActions
                ? Row(
                    children: [
                      const Spacer(),
                      for (final a in actions!) ...[
                        a,
                        const SizedBox(width: 6),
                      ],
                    ],
                  )
                : null,
          ),
        ),
      ],
    );
  }
}
