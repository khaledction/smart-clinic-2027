import 'package:flutter/material.dart';

/// مسار النوافذ المفتوحة (Breadcrumb) للشريط الكحلي العلوي.
///
/// يراقب النوافذ المفتوحة فوق بعضها، وكل نافذة تسجّل اسمها هنا:
/// الشاشة الرئيسية تسجّل اسم الصفحة الحالية (مثل «المرضى والمواعيد»)،
/// وكل نافذة مستقلة تسجّل عنوانها. فيظهر في النافذة المفتوحة:
///   المرضى والمواعيد ‹ الملف الطبي للمريض ‹ زيارة جديدة
class FrameTrail extends NavigatorObserver {
  /// مراقب جديد لكل Navigator (الرئيسي، ونافذة الإطار داخل الشاشة الرئيسية).
  FrameTrail();

  /// مراقب الـ Navigator الرئيسي للبرنامج (يُضاف في main.dart).
  static final FrameTrail instance = FrameTrail();

  static final Set<FrameTrail> _all = {};
  static final Map<Route<dynamic>, String> _labels = {};

  final List<Route<dynamic>> _stack = [];

  /// تسجيل اسم نافذة (يُستدعى أثناء بناء الشريط).
  static void label(Route<dynamic>? route, String? text) {
    if (route == null) return;
    final t = text?.trim() ?? '';
    if (t.isEmpty) {
      _labels.remove(route);
    } else {
      _labels[route] = t;
    }
  }

  /// الاسم المسجّل لنافذة (أو null).
  static String? labelOf(Route<dynamic> route) => _labels[route];

  /// النوافذ السابقة للنافذة الحالية (بالترتيب)، مع أسمائها.
  static List<({Route<dynamic> route, String label})> before(
    Route<dynamic>? current,
  ) {
    if (current == null) return const [];
    for (final o in _all) {
      final i = o._stack.indexOf(current);
      if (i < 0) continue;
      return [
        for (final r in o._stack.take(i))
          if (r is PageRoute && _labels[r] != null)
            (route: r, label: _labels[r]!),
      ];
    }
    return const [];
  }

  /// اسم أعلى نافذة مفتوحة في هذا الـ Navigator.
  String? get topLabel {
    for (final r in _stack.reversed) {
      if (r is PageRoute && _labels[r] != null) return _labels[r];
    }
    return null;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _all.add(this);
    _stack.add(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _forget(route);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _forget(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final i = oldRoute == null ? -1 : _stack.indexOf(oldRoute);
    if (oldRoute != null) _labels.remove(oldRoute);
    if (newRoute == null) {
      if (i >= 0) _stack.removeAt(i);
    } else if (i >= 0) {
      _stack[i] = newRoute;
    } else {
      _stack.add(newRoute);
    }
  }

  void _forget(Route<dynamic> route) {
    _stack.remove(route);
    _labels.remove(route);
  }

  /// يُستدعى عند التخلص من Navigator داخلي (تبديل القسم).
  void dispose() {
    for (final r in _stack) {
      _labels.remove(r);
    }
    _stack.clear();
    _all.remove(this);
  }
}

/// يوضع حول الـ Navigator الداخلي للشاشة الرئيسية: أي نافذة تُفتح تحته
/// تظهر داخل الإطار (القائمة الجانبية والشريط الكحلي ثابتان).
class ShellFrameScope extends InheritedWidget {
  const ShellFrameScope({super.key, required super.child});

  static bool inFrame(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ShellFrameScope>() != null;

  @override
  bool updateShouldNotify(ShellFrameScope oldWidget) => false;
}

/// اسم النافذة الحالية بخط واضح، وتحته سطر صغير فيه المسار:
///   زيارة جديدة — أحمد سالم
///   لوحة اليوم ‹ الملف الطبي للمريض ‹ زيارة جديدة
/// الأجزاء السابقة في المسار قابلة للنقر (ترجع إليها مباشرة).
class FrameTrailBar extends StatelessWidget {
  const FrameTrailBar({super.key, required this.title, this.style});

  final Widget title;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final route = ModalRoute.of(context);
    final crumbs = FrameTrail.before(route);
    final current = route == null ? null : FrameTrail.labelOf(route);
    final base = style ?? DefaultTextStyle.of(context).style;
    final titleStyle = crumbs.isEmpty
        ? base
        : base.copyWith(fontSize: (base.fontSize ?? 16) - 1, height: 1.3);
    final crumbStyle = base.copyWith(
      color: Colors.white.withValues(alpha: 0.62),
      fontWeight: FontWeight.w600,
      fontSize: 12,
      height: 1.3,
    );
    final titleLine = DefaultTextStyle(
      style: titleStyle,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      child: title,
    );
    if (crumbs.isEmpty) {
      return KeyedSubtree(key: const Key('frameTrail'), child: titleLine);
    }
    Widget chevron() => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      // في العربية يشير السهم لليسار (باتجاه النافذة الحالية).
      child: Icon(
        Icons.chevron_left_rounded,
        textDirection: TextDirection.ltr,
        size: 16,
        color: Colors.white.withValues(alpha: 0.45),
      ),
    );
    return Column(
      key: const Key('frameTrail'),
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        titleLine,
        const SizedBox(height: 2),
        Row(
          key: const Key('frameTrailPath'),
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final c in crumbs) ...[
              Flexible(
                child: _Crumb(
                  label: c.label,
                  style: crumbStyle,
                  onTap: () =>
                      Navigator.of(context).popUntil((r) => r == c.route),
                ),
              ),
              chevron(),
            ],
            if (current != null)
              Flexible(
                child: Text(
                  current,
                  key: const Key('crumbCurrent'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: crumbStyle.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _Crumb extends StatefulWidget {
  const _Crumb({required this.label, required this.style, required this.onTap});

  final String label;
  final TextStyle style;
  final VoidCallback onTap;

  @override
  State<_Crumb> createState() => _CrumbState();
}

class _CrumbState extends State<_Crumb> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    onEnter: (_) => setState(() => _hover = true),
    onExit: (_) => setState(() => _hover = false),
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: Tooltip(
        message: 'الرجوع إلى «${widget.label}»',
        waitDuration: const Duration(milliseconds: 600),
        child: Text(
          widget.label,
          key: Key('crumb:${widget.label}'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: widget.style.copyWith(
            color: _hover ? Colors.white : widget.style.color,
            decoration: _hover ? TextDecoration.underline : null,
            decorationColor: Colors.white70,
          ),
        ),
      ),
    ),
  );
}
