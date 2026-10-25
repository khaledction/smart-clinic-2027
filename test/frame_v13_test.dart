import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:neuro_clinic/core/database/app_database.dart';
import 'package:neuro_clinic/core/database/schema.dart';
import 'package:neuro_clinic/core/database/seed.dart';
import 'package:neuro_clinic/core/theme/app_colors.dart';
import 'package:neuro_clinic/core/theme/app_theme.dart';
import 'package:neuro_clinic/core/widgets/app_shell.dart';
import 'package:neuro_clinic/core/widgets/clinic_brand.dart';
import 'package:neuro_clinic/core/widgets/frame_trail.dart';
import 'package:neuro_clinic/core/widgets/range_picker.dart';
import 'package:neuro_clinic/core/widgets/window_controls.dart';
import 'package:neuro_clinic/data/providers/appointments_provider.dart';
import 'package:neuro_clinic/data/providers/patients_provider.dart';
import 'package:neuro_clinic/data/providers/session_provider.dart';
import 'package:neuro_clinic/data/providers/settings_provider.dart';
import 'package:neuro_clinic/data/repositories/appointment_repository.dart';
import 'package:neuro_clinic/data/repositories/auth_repository.dart';
import 'package:neuro_clinic/data/repositories/patient_repository.dart';
import 'package:neuro_clinic/data/repositories/settings_repository.dart';
import 'package:neuro_clinic/features/login/login_screen.dart';

Widget _material(Widget home) => MaterialApp(
  debugShowCheckedModeBanner: false,
  locale: const Locale('ar'),
  supportedLocales: const [Locale('ar')],
  localizationsDelegates: const [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  theme: AppTheme.light(),
  home: home,
);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
  }
}

void main() {
  test('range picker: navy header and a clear save button', () {
    final t = rangePickerTheme(AppTheme.light());
    expect(
      t.datePickerTheme.rangePickerHeaderBackgroundColor,
      AppColors.sidebar,
    );
    expect(t.datePickerTheme.rangePickerHeaderForegroundColor, Colors.white);
    final st = t.textButtonTheme.style!;
    expect(
      st.backgroundColor!.resolve({}),
      Colors.white.withValues(alpha: 0.18),
    );
    expect(st.side!.resolve({})!.color, Colors.white70);
  });

  testWidgets('breadcrumb path of opened windows, clickable', (tester) async {
    tester.view.physicalSize = const Size(1300, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Route<void> page(String title, {Widget? next}) => MaterialPageRoute(
      builder: (ctx) => Scaffold(
        appBar: BrandedAppBar(title: Text(title)),
        body: next == null
            ? const SizedBox()
            : Center(
                child: FilledButton(
                  onPressed: () => Navigator.push(ctx, page('زيارة جديدة')),
                  child: const Text('التالي'),
                ),
              ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        navigatorObservers: [FrameTrail.instance],
        home: Builder(
          builder: (ctx) {
            FrameTrail.label(ModalRoute.of(ctx), 'المرضى والمواعيد');
            return Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => Navigator.push(
                    ctx,
                    page('الملف الطبي للمريض', next: const SizedBox()),
                  ),
                  child: const Text('افتح الملف'),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('افتح الملف'));
    await tester.pumpAndSettle();
    // النافذة الأولى: الاسم، وتحته المسار: الصفحة الرئيسية ‹ الملف.
    expect(find.byKey(const Key('crumb:المرضى والمواعيد')), findsOneWidget);
    expect(find.text('الملف الطبي للمريض'), findsNWidgets(2));
    await tester.tap(find.text('التالي'));
    await tester.pumpAndSettle();
    final home = find.byKey(const Key('crumb:المرضى والمواعيد'));
    final file = find.byKey(const Key('crumb:الملف الطبي للمريض'));
    expect(home, findsOneWidget);
    expect(file, findsOneWidget);
    // الترتيب من اليمين لليسار: الرئيسية ← الملف ← الزيارة (الحالية).
    final visit = find.byKey(const Key('crumbCurrent'));
    expect(tester.widget<Text>(visit).data, 'زيارة جديدة');
    expect(tester.getCenter(home).dx, greaterThan(tester.getCenter(file).dx));
    expect(tester.getCenter(file).dx, greaterThan(tester.getCenter(visit).dx));
    // المسار في سطر تحت اسم النافذة.
    final titleText = find
        .descendant(
          of: find.byKey(const Key('frameTrail')),
          matching: find.text('زيارة جديدة'),
        )
        .first;
    expect(
      tester.getCenter(find.byKey(const Key('frameTrailPath'))).dy,
      greaterThan(tester.getCenter(titleText).dy),
    );
    expect(
      tester.getRect(find.byKey(const Key('frameTrail'))).height,
      lessThanOrEqualTo(kFrameBandHeight),
    );
    // النقر على «المرضى والمواعيد» يرجع إليها مباشرة.
    await tester.tap(home);
    await tester.pumpAndSettle();
    expect(find.text('افتح الملف'), findsOneWidget);
    expect(find.byType(BrandedAppBar), findsNothing);
  });

  testWidgets('window buttons: order in RTL and safe under test', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _material(
        const Scaffold(
          backgroundColor: AppColors.sidebar,
          body: Align(
            alignment: AlignmentDirectional.topEnd,
            child: WindowControls(),
          ),
        ),
      ),
    );
    expect(windowApiAvailable, isFalse);
    expect(find.text(kAppProductName), findsOneWidget);
    final close = tester.getCenter(find.byKey(const Key('winClose')));
    final max = tester.getCenter(find.byKey(const Key('winMaximize')));
    final min = tester.getCenter(find.byKey(const Key('winMinimize')));
    final name = tester.getCenter(find.text(kAppProductName));
    // الإغلاق أقصى اليسار ← التكبير ← التصغير ← اسم البرنامج.
    expect(close.dx < max.dx, isTrue);
    expect(max.dx < min.dx, isTrue);
    expect(min.dx < name.dx, isTrue);
    // لا شيء ينهار عند الضغط داخل الاختبارات.
    await tester.tap(find.byKey(const Key('winClose')));
    await tester.tap(find.byKey(const Key('winMaximize')));
    await tester.tap(find.byKey(const Key('winMinimize')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
  });

  testWidgets('standalone window: navy band, brand right, controls left', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _material(
        Builder(
          builder: (ctx) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => Navigator.push(
                  ctx,
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      appBar: BrandedAppBar(
                        title: const Text('نافذة تجريبية'),
                        actions: [
                          TextButton(
                            onPressed: () {},
                            child: const Text('إجراء'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                child: const Text('افتح'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('افتح'));
    await tester.pumpAndSettle();

    final band = tester.widget<Material>(find.byKey(const Key('brandedBand')));
    expect(band.color, AppColors.sidebar);
    expect(
      tester.getSize(find.byKey(const Key('brandedBand'))).height,
      kFrameBandHeight,
    );
    expect(find.byType(BackButton), findsOneWidget);
    final brand = tester.getCenter(find.byKey(const Key('clinicLogo')));
    final back = tester.getCenter(find.byType(BackButton));
    final title = tester.getCenter(find.text('نافذة تجريبية'));
    final action = tester.getCenter(find.text('إجراء'));
    final close = tester.getCenter(find.byKey(const Key('winClose')));
    expect(brand.dx > back.dx, isTrue);
    expect(back.dx > title.dx, isTrue);
    expect(title.dx > action.dx, isTrue);
    expect(action.dx > close.dx, isTrue);

    // زر الشاشة على الكحلي: خلفية بيضاء وخط كحلي.
    final btn = tester.widget<TextButton>(find.byType(TextButton));
    final ctx = tester.element(find.byWidget(btn));
    final style = Theme.of(ctx).textButtonTheme.style!;
    expect(style.backgroundColor!.resolve({}), Colors.white);
    expect(style.foregroundColor!.resolve({}), AppColors.navy);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('افتح'), findsOneWidget);
  });

  testWidgets('shell: navy frame band + curved content + login strip', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1300, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late Database db;
    late SettingsProvider settings;
    final session = SessionProvider(AuthRepository());
    await tester.runAsync(() async {
      sqfliteFfiInit();
      final dir = await Directory.systemTemp.createTemp('v13-');
      db = await databaseFactoryFfiNoIsolate.openDatabase('${dir.path}/t.db');
      await enableForeignKeys(db);
      await createSchema(db);
      await seedInitialData(db);
      AppDatabase.instance.useTestDatabase(db);
      await db.update('clinic_settings', {
        'clinic_name': 'عيادة الدكتور مقلد للأعصاب',
      });
      settings = SettingsProvider(SettingsRepository());
      await settings.load();
    });

    Widget app(Widget home) => MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: session),
        ChangeNotifierProvider(
          create: (_) => PatientsProvider(PatientRepository()),
        ),
        ChangeNotifierProvider(
          create: (_) => AppointmentsProvider(AppointmentRepository()),
        ),
      ],
      child: _material(home),
    );

    // شاشة الدخول: شريط كحلي رفيع فيه أزرار النافذة.
    await tester.pumpWidget(app(const LoginScreen()));
    await _settle(tester);
    expect(find.byType(LoginWindowStrip), findsOneWidget);
    expect(find.byKey(const Key('winClose')), findsOneWidget);

    await tester.runAsync(() => session.login('doctor', '1234'));
    await tester.pumpWidget(app(const AppShell()));
    await _settle(tester);

    expect(find.byKey(const Key('frameBand')), findsOneWidget);
    expect(find.byKey(const Key('sidebarClinicName')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('frameBand')),
        matching: find.text('لوحة اليوم'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('frameBand')),
        matching: find.byKey(const Key('winClose')),
      ),
      findsOneWidget,
    );
    final clip = tester.widget<ClipRRect>(
      find.byKey(const Key('frameContent')),
    );
    expect(
      clip.borderRadius,
      const BorderRadiusDirectional.only(topStart: Radius.circular(30)),
    );
    // الشريط العلوي يبدأ بعد القائمة الجانبية (يميناً) وينتهي عند حافة النافذة.
    final bandRect = tester.getRect(find.byKey(const Key('frameBand')));
    expect(bandRect.left, 0);
    expect(bandRect.right, 1300 - 200);
    expect(bandRect.height, kFrameBandHeight);
    final shell = tester.widget<Scaffold>(
      find
          .descendant(
            of: find.byType(AppShell),
            matching: find.byType(Scaffold),
          )
          .first,
    );
    expect(shell.backgroundColor, AppColors.sidebar);

    // ---------------------------------------------------------------- V16
    // النوافذ تُفتح داخل الإطار: القائمة الجانبية والشريط الكحلي ثابتان.
    final inner = tester.state<NavigatorState>(find.byType(Navigator).last);
    inner.push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: BrandedAppBar(
            title: const Text('نافذة تجريبية'),
            actions: [TextButton(onPressed: () {}, child: const Text('إجراء'))],
          ),
          body: const Center(child: Text('محتوى النافذة')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('محتوى النافذة'), findsOneWidget);
    expect(find.byKey(const Key('sidebarClinicName')), findsOneWidget);
    final band = tester.getRect(find.byKey(const Key('brandedBand')));
    expect(band.right, 1300 - 200); // الشريط لا يغطي القائمة الجانبية
    expect(band.height, kFrameBandHeight);
    // الاسم وتحته المسار: «لوحة اليوم ‹ نافذة تجريبية».
    expect(find.byKey(const Key('crumb:لوحة اليوم')), findsOneWidget);
    expect(find.byKey(const Key('crumbCurrent')), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
    // أزرار النافذة في السطر الفاتح، على اليسار.
    final strip = find.byKey(const Key('frameStrip'));
    expect(
      find.descendant(of: strip, matching: find.text('إجراء')),
      findsOneWidget,
    );
    expect(tester.getCenter(find.text('إجراء')).dx, lessThan(1100 / 2));
    expect(tester.getRect(strip).top, band.bottom);

    // التبديل من القائمة الجانبية مع نافذة مفتوحة ← تأكيد.
    await tester.tap(find.byIcon(Icons.contacts_outlined));
    await tester.pumpAndSettle();
    expect(find.text('توجد نافذة مفتوحة'), findsOneWidget);
    await tester.tap(find.text('البقاء في النافذة'));
    await tester.pumpAndSettle();
    expect(find.text('محتوى النافذة'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.contacts_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('إغلاق والانتقال'));
    await _settle(tester);
    expect(find.text('محتوى النافذة'), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const Key('frameBand')),
        matching: find.text('المرضى والمواعيد'),
      ),
      findsOneWidget,
    );

    // النقر على أول جزء في المسار يرجع لصفحة القسم.
    final inner2 = tester.state<NavigatorState>(find.byType(Navigator).last);
    inner2.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(
          appBar: BrandedAppBar(title: Text('نافذة ثانية')),
          body: Text('محتوى ثانٍ'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('crumb:المرضى والمواعيد')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('محتوى ثانٍ'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => db.close());
  });
}
