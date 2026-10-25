import 'shell_nav.dart';
import '../../features/sessions/sessions_screen.dart';
import '../../features/finance/finance_screen.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/app_colors.dart';
import '../../data/providers/session_provider.dart';
import '../../data/providers/settings_provider.dart';
import '../../features/hub/patients_appointments_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/reports/reports_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/visits/visits_screen.dart';
import 'clinic_brand.dart';
import 'confirm_dialog.dart';
import 'frame_trail.dart';
import 'window_controls.dart';

/// الهيكل العام للتطبيق: شريط جانبي (يمين لأن الواجهة RTL) + مساحة المحتوى.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  // النوافذ تُفتح داخل الإطار: Navigator داخلي لكل قسم (يُجدَّد عند التبديل).
  GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();
  FrameTrail _trail = FrameTrail();

  @override
  void dispose() {
    ShellNav.goTo = null;
    _trail.dispose();
    super.dispose();
  }

  /// ينتقل إلى قسم (يُغلق نوافذ القسم الحالي).
  void _switchTo(int i) {
    if (i == _index) {
      _navKey.currentState?.popUntil((r) => r.isFirst);
      return;
    }
    final old = _trail;
    setState(() {
      _index = i;
      _navKey = GlobalKey<NavigatorState>();
      _trail = FrameTrail();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
  }

  /// من القائمة الجانبية: إن كانت هناك نافذة مفتوحة نطلب التأكيد أولاً.
  Future<void> _onSidebar(int i) async {
    final nav = _navKey.currentState;
    if (nav != null && nav.canPop()) {
      final open = _trail.topLabel ?? 'نافذة';
      final ok = await ConfirmDialog.show(
        context,
        title: 'توجد نافذة مفتوحة',
        message: i == _index
            ? 'النافذة «$open» ما زالت مفتوحة وقد تحتوي بيانات غير محفوظة.\nهل تريد إغلاقها والرجوع إلى «${_destinations[i].label}»؟'
            : 'النافذة «$open» ما زالت مفتوحة وقد تحتوي بيانات غير محفوظة.\nهل تريد إغلاقها والانتقال إلى «${_destinations[i].label}»؟',
        confirmLabel: 'إغلاق والانتقال',
        cancelLabel: 'البقاء في النافذة',
      );
      if (!ok || !mounted) return;
    } else if (i == _index) {
      return;
    }
    _switchTo(i);
  }

  static const _destinations = [
    (
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
      label: 'لوحة اليوم',
    ),
    (
      icon: Icons.contacts_outlined,
      selectedIcon: Icons.contacts,
      label: 'المرضى والمواعيد',
    ),
    (
      icon: Icons.medical_information_outlined,
      selectedIcon: Icons.medical_information,
      label: 'الزيارات',
    ),
    (
      icon: Icons.spa_outlined,
      selectedIcon: Icons.spa,
      label: 'الجلسات والإجراءات',
    ),
    (
      icon: Icons.payments_outlined,
      selectedIcon: Icons.payments,
      label: 'المالية',
    ),
    (
      icon: Icons.insert_chart_outlined,
      selectedIcon: Icons.insert_chart,
      label: 'التقارير',
    ),
    (
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
      label: 'الإعدادات',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final session = context.watch<SessionProvider>();
    final user = session.user;
    ShellNav.goTo = (i) {
      if (!mounted) return;
      if ((i >= 2 && i <= 5) && user?.isDoctor != true) return;
      if (i == 6 && user?.isAdmin != true) return;
      _switchTo(i);
    };

    // أول جزء في مسار النوافذ المستقلة = اسم الصفحة الحالية.
    FrameTrail.label(ModalRoute.of(context), _destinations[_index].label);

    const denied = Center(child: Text("هذه الشاشة غير متاحة لهذا الدور"));
    final pages = [
      user?.isDoctor == true
          ? const DashboardScreen()
          : const PatientsAppointmentsScreen(),
      const PatientsAppointmentsScreen(),
      user?.isDoctor == true ? const VisitsScreen() : denied,
      user?.isDoctor == true ? const SessionsScreen(embedded: true) : denied,
      user?.isDoctor == true ? const FinanceScreen(embedded: true) : denied,
      user?.isDoctor == true ? const ReportsScreen() : denied,
      user?.isAdmin == true ? const SettingsScreen() : denied,
    ];

    // الإطار الموحد: القائمة الكحلية يميناً تصعد ثم تنعطف يساراً
    // كشريط علوي واحد حتى نهاية النافذة، والمحتوى في «الحضن» بزاوية منحنية.
    return Scaffold(
      backgroundColor: AppColors.sidebar,
      body: Row(
        textDirection: TextDirection.rtl,
        children: [
          // ------------------------------------------- الشريط الجانبي (يمين)
          SizedBox(
            width: 200,
            child: Column(
              children: [
                // ركن الانعطاف: صورة الطبيب/الشعار + عبارة الترويسة.
                WindowDragArea(
                  child: SizedBox(
                    height: 178,
                    width: double.infinity,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const ClinicLogo(size: 92, ringWidth: 3),
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          // سطران في المنتصف: «عيادة» ثم اسم الطبيب؛ كل سطر
                          // يُصغَّر عند الحاجة ليبقى على سطر واحد.
                          child: Column(
                            key: const Key('sidebarClinicName'),
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (final line in clinicNameTwoLines(
                                settings.clinicName,
                              ).split('\n'))
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    line,
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w700,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(
                  color: Colors.white24,
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: NavigationRail(
                    backgroundColor: Colors.transparent,
                    extended: true,
                    minExtendedWidth: 200,
                    labelType: NavigationRailLabelType.none,
                    groupAlignment: -1,
                    selectedIndex: _index,
                    onDestinationSelected: (i) {
                      if ((i >= 2 && i <= 5) && user?.isDoctor != true) return;
                      if (i == 6 && user?.isAdmin != true) return;
                      _onSidebar(i);
                    },
                    selectedIconTheme: const IconThemeData(
                      color: Colors.white,
                      size: 22,
                    ),
                    unselectedIconTheme: IconThemeData(
                      color: Colors.white.withValues(alpha: 0.62),
                      size: 22,
                    ),
                    selectedLabelTextStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                    unselectedLabelTextStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.62),
                      fontSize: 13.5,
                    ),
                    indicatorColor: Colors.white.withValues(alpha: 0.14),
                    destinations: _destinations
                        .map(
                          (d) => NavigationRailDestination(
                            icon: Icon(d.icon),
                            selectedIcon: Icon(d.selectedIcon),
                            label: Text(d.label),
                            padding: const EdgeInsets.symmetric(vertical: 2),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const Divider(color: Colors.white24, height: 1),
                // -------------------------------------------------- المستخدم
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 15,
                        backgroundColor: Colors.white.withValues(alpha: 0.16),
                        child: Text(
                          (user?.fullName.isNotEmpty ?? false)
                              ? user!.fullName[0]
                              : '؟',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              user?.fullName ?? '',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12.5,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              user?.roleLabel ?? '',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'تسجيل الخروج',
                        icon: const Icon(
                          Icons.logout_rounded,
                          color: Colors.white70,
                          size: 19,
                        ),
                        onPressed: () =>
                            context.read<SessionProvider>().logout(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ------------------------------------------------------- المحتوى
          // كل نافذة تُفتح من هنا تبقى داخل الإطار: القائمة الجانبية
          // والشريط الكحلي ثابتان، والنافذة في المساحة البيضاء المنحنية.
          Expanded(
            child: ShellFrameScope(
              child: HeroControllerScope.none(
                child: Theme(
                  data: Theme.of(context).copyWith(
                    pageTransitionsTheme: PageTransitionsTheme(
                      builders: {
                        for (final p in TargetPlatform.values)
                          p: const _FadePageTransitions(),
                      },
                    ),
                  ),
                  child: Navigator(
                    key: _navKey,
                    observers: [_trail],
                    onGenerateRoute: (_) {
                      final label = _destinations[_index].label;
                      final page = pages[_index];
                      return MaterialPageRoute<void>(
                        builder: (_) => _RootPage(label: label, child: page),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// صفحة القسم نفسها داخل الإطار: الشريط الكحلي (عنوان القسم) + المحتوى
/// في المساحة الفاتحة بزاوية منحنية.
class _RootPage extends StatelessWidget {
  const _RootPage({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // أول جزء في مسار النوافذ المفتوحة داخل هذا القسم.
    FrameTrail.label(ModalRoute.of(context), label);
    return Column(
      children: [
        _FrameBand(title: label),
        Expanded(
          child: ClipRRect(
            key: const Key('frameContent'),
            borderRadius: const BorderRadiusDirectional.only(
              topStart: Radius.circular(30),
            ),
            child: ColoredBox(color: AppColors.bg, child: child),
          ),
        ),
      ],
    );
  }
}

/// انتقال هادئ (تلاشٍ) بين النوافذ داخل الإطار، فلا يتحرك الشريط الكحلي.
class _FadePageTransitions extends PageTransitionsBuilder {
  const _FadePageTransitions();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => FadeTransition(
    opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
    child: child,
  );
}

/// الشريط الكحلي العلوي (امتداد القائمة الجانبية): عنوان الصفحة يميناً،
/// واسم البرنامج وأزرار النافذة في أقصى اليسار.
class _FrameBand extends StatelessWidget {
  const _FrameBand({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const Key('frameBand'),
      height: kFrameBandHeight,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: 26, end: 10),
        child: Row(
          children: [
            Expanded(
              child: WindowDragArea(
                child: SizedBox.expand(
                  child: Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const WindowControls(),
          ],
        ),
      ),
    );
  }
}
