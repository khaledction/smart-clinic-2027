import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../theme/app_colors.dart';

/// اسم البرنامج الظاهر بجوار أزرار النافذة.
const kAppProductName = 'Smart Clinic — برنامج إدارة العيادات الطبية';

/// ارتفاع الشريط الكحلي العلوي (الإطار الموحد).
const kFrameBandHeight = 60.0;

/// ارتفاع سطر أزرار النافذة داخل الإطار (فوق المساحة البيضاء المنحنية).
const kFrameStripHeight = 56.0;

/// هل أوامر النافذة متاحة؟ (سطح مكتب حقيقي، وليس داخل الاختبارات).
bool get windowApiAvailable {
  if (kIsWeb) return false;
  if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    return false;
  }
  return !Platform.environment.containsKey('FLUTTER_TEST');
}

/// ينفّذ أمر نافذة بأمان (لا ينهار البرنامج لو لم تتوفر الإضافة).
Future<void> _safe(Future<void> Function() action) async {
  if (!windowApiAvailable) return;
  try {
    await action();
  } catch (_) {}
}

Future<void> _toggleMaximize() => _safe(() async {
  if (await windowManager.isMaximized()) {
    await windowManager.unmaximize();
  } else {
    await windowManager.maximize();
  }
});

/// مساحة سحب: اسحب لتحريك النافذة، ونقرتان للتكبير/الاستعادة.
/// تُلفّ حول المساحات الفارغة والعناوين فقط، لا حول الأزرار.
class WindowDragArea extends StatelessWidget {
  const WindowDragArea({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.translucent,
    onPanStart: (_) => _safe(windowManager.startDragging),
    onDoubleTap: _toggleMaximize,
    child: child,
  );
}

/// اسم البرنامج + فاصل + أزرار (تصغير، تكبير/استعادة، إغلاق).
/// في الواجهة العربية يكون زر الإغلاق في أقصى اليسار.
class WindowControls extends StatefulWidget {
  const WindowControls({super.key, this.showName = true});

  final bool showName;

  @override
  State<WindowControls> createState() => _WindowControlsState();
}

class _WindowControlsState extends State<WindowControls> with WindowListener {
  bool _maximized = false;

  @override
  void initState() {
    super.initState();
    if (windowApiAvailable) {
      windowManager.addListener(this);
      _safe(() async {
        final m = await windowManager.isMaximized();
        if (mounted) setState(() => _maximized = m);
      });
    }
  }

  @override
  void dispose() {
    if (windowApiAvailable) windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowMaximize() => setState(() => _maximized = true);

  @override
  void onWindowUnmaximize() => setState(() => _maximized = false);

  @override
  Widget build(BuildContext context) => Row(
    key: const Key('windowControls'),
    mainAxisSize: MainAxisSize.min,
    children: [
      if (widget.showName) ...[
        const WindowDragArea(child: WindowAppName()),
        Container(
          width: 1,
          height: 22,
          margin: const EdgeInsets.symmetric(horizontal: 12),
          color: Colors.white24,
        ),
      ],
      _CaptionButton(
        key: const Key('winMinimize'),
        icon: Icons.remove_rounded,
        tooltip: 'تصغير',
        onTap: () => _safe(windowManager.minimize),
      ),
      const SizedBox(width: 6),
      _CaptionButton(
        key: const Key('winMaximize'),
        icon: _maximized
            ? Icons.filter_none_rounded
            : Icons.crop_square_rounded,
        iconSize: _maximized ? 14 : 17,
        tooltip: _maximized ? 'استعادة الحجم' : 'تكبير',
        onTap: _toggleMaximize,
      ),
      const SizedBox(width: 6),
      _CaptionButton(
        key: const Key('winClose'),
        icon: Icons.close_rounded,
        tooltip: 'إغلاق البرنامج',
        danger: true,
        onTap: () => _safe(windowManager.close),
      ),
    ],
  );
}

/// اسم البرنامج مع شعار البرنامج (Smart Clinic).
class WindowAppName extends StatelessWidget {
  const WindowAppName({super.key});

  @override
  Widget build(BuildContext context) => Row(
    key: const Key('windowAppName'),
    mainAxisSize: MainAxisSize.min,
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: Image.asset(
          'assets/images/smart-clinic.png',
          width: 18,
          height: 18,
          fit: BoxFit.cover,
        ),
      ),
      const SizedBox(width: 8),
      Text(
        kAppProductName,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.9),
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

class _CaptionButton extends StatefulWidget {
  const _CaptionButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.danger = false,
    this.iconSize = 18,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool danger;
  final double iconSize;

  @override
  State<_CaptionButton> createState() => _CaptionButtonState();
}

class _CaptionButtonState extends State<_CaptionButton> {
  bool _hover = false;

  static const _closeRed = Color(0xFFE5484D);

  @override
  Widget build(BuildContext context) {
    final Color bg = _hover
        ? (widget.danger ? _closeRed : Colors.white.withValues(alpha: 0.20))
        : Colors.white.withValues(alpha: 0.08);
    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 500),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 44,
            height: 34,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              widget.icon,
              size: widget.iconSize,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

/// شريط رفيع أعلى النافذة لتغيير ارتفاعها من الحافة العليا
/// (بعد إخفاء شريط ويندوز الأصلي). يختفي عند التكبير.
class WindowTopResizeEdge extends StatefulWidget {
  const WindowTopResizeEdge({super.key, required this.child});

  final Widget child;

  @override
  State<WindowTopResizeEdge> createState() => _WindowTopResizeEdgeState();
}

class _WindowTopResizeEdgeState extends State<WindowTopResizeEdge>
    with WindowListener {
  bool _maximized = false;

  @override
  void initState() {
    super.initState();
    if (windowApiAvailable) {
      windowManager.addListener(this);
      _safe(() async {
        final m = await windowManager.isMaximized();
        if (mounted) setState(() => _maximized = m);
      });
    }
  }

  @override
  void dispose() {
    if (windowApiAvailable) windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowMaximize() => setState(() => _maximized = true);

  @override
  void onWindowUnmaximize() => setState(() => _maximized = false);

  @override
  Widget build(BuildContext context) {
    if (!windowApiAvailable || _maximized) return widget.child;
    return Stack(
      children: [
        Positioned.fill(child: widget.child),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 5,
          child: MouseRegion(
            cursor: SystemMouseCursors.resizeUpDown,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (_) =>
                  _safe(() => windowManager.startResizing(ResizeEdge.top)),
            ),
          ),
        ),
      ],
    );
  }
}

/// شريط كحلي رفيع لشاشة الدخول: سحب + أيقونة واسم Smart Clinic + أزرار النافذة.
class LoginWindowStrip extends StatelessWidget {
  const LoginWindowStrip({super.key});

  @override
  Widget build(BuildContext context) => Container(
    height: 48,
    color: AppColors.sidebar,
    padding: const EdgeInsetsDirectional.only(start: 16, end: 8),
    child: Row(
      children: [
        WindowDragArea(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset(
                  'assets/images/smart-clinic.png',
                  width: 22,
                  height: 22,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Smart Clinic',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
        const Expanded(child: WindowDragArea(child: SizedBox.expand())),
        const WindowControls(showName: false),
      ],
    ),
  );
}
