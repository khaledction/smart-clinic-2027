import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:neuro_clinic/core/database/app_database.dart';
import 'package:neuro_clinic/core/database/schema.dart';
import 'package:neuro_clinic/core/database/seed.dart';
import 'package:neuro_clinic/core/theme/app_theme.dart';
import 'package:neuro_clinic/core/widgets/clinic_brand.dart';
import 'package:neuro_clinic/data/providers/settings_provider.dart';
import 'package:neuro_clinic/data/repositories/logo_repository.dart';
import 'package:neuro_clinic/data/repositories/settings_repository.dart';
import 'package:neuro_clinic/features/login/login_screen.dart';
import 'package:neuro_clinic/features/settings/settings_screen.dart';
import 'package:neuro_clinic/data/providers/session_provider.dart';
import 'package:neuro_clinic/data/repositories/auth_repository.dart';
import 'package:neuro_clinic/features/investigations/investigations_screen.dart';

/// صورة PNG صغيرة (1×1) صالحة.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

Widget _app(
  Widget home, {
  required SettingsProvider settings,
  SessionProvider? session,
}) => MultiProvider(
  providers: [
    ChangeNotifierProvider.value(value: settings),
    if (session != null) ChangeNotifierProvider.value(value: session),
  ],
  child: MaterialApp(
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
  ),
);

Future<(Database, SettingsProvider, Directory)> _setup(
  WidgetTester tester,
) async {
  late Database db;
  late SettingsProvider settings;
  late Directory logoDir;
  await tester.runAsync(() async {
    sqfliteFfiInit();
    final dir = await Directory.systemTemp.createTemp('v12-');
    logoDir = await Directory.systemTemp.createTemp('v12-logo-');
    LogoRepository.directory = () async => logoDir;
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
    await settings.loadLogo();
  });
  return (db, settings, logoDir);
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(() async {
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
  }
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('نافذة الدخول: صورة دائرية + عبارة الترويسة من الإعدادات', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    final (_, settings, _) = await _setup(tester);
    final session = SessionProvider(AuthRepository());
    await tester.pumpWidget(
      _app(const LoginScreen(), settings: settings, session: session),
    );
    await _settle(tester);
    final logo = find.byKey(const Key('clinicLogo'));
    expect(logo, findsOneWidget);
    final box = tester.widget<Container>(logo).decoration! as BoxDecoration;
    expect(box.shape, BoxShape.circle);
    expect(box.image!.image, isA<AssetImage>());
    expect(tester.getSize(logo), const Size(136, 136));
    // V19: ثلاثة أسطر في المنتصف: «عيادة» / اسم الطبيب / الاختصاص.
    expect(find.text('عيادة'), findsOneWidget);
    expect(find.text('الدكتور مقلد للأعصاب'), findsOneWidget);
    expect(find.text(kClinicSpecialtyLine), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => AppDatabase.instance.close());
  });

  testWidgets('كل نافذة مستقلة: الشعار واسم العيادة يميناً + الأزرار يساراً', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    final (db, settings, _) = await _setup(tester);
    late int patientId;
    await tester.runAsync(() async {
      patientId = await db.insert('patients', {'full_name': 'مريض'});
      await db.insert('investigations', {
        'patient_id': patientId,
        'kind': 'رنين',
        'performed_on': DateTime.now().toIso8601String().substring(0, 10),
        'workflow_status': 'received',
      });
    });
    await tester.pumpWidget(
      _app(InvestigationsScreen(patientId: patientId), settings: settings),
    );
    await _settle(tester);
    // V13: في الشريط الكحلي الصورة الدائرية فقط (بدون تكرار اسم العيادة).
    final band = find.byKey(const Key('brandedBand'));
    final brand = find.descendant(
      of: band,
      matching: find.byKey(const Key('clinicLogo')),
    );
    expect(brand, findsOneWidget);
    expect(
      find.descendant(
        of: band,
        matching: find.text('عيادة الدكتور مقلد للأعصاب'),
      ),
      findsNothing,
    );
    // الشعار على يمين عنوان النافذة (واجهة عربية).
    expect(
      tester.getCenter(brand).dx,
      greaterThan(tester.getCenter(find.text('الفحوص والنتائج')).dx),
    );
    expect(tester.getCenter(brand).dx, greaterThan(1440 / 2));
    // أزرار بطاقة الفحص إلى اليسار.
    final edit = find.text('فتح / تعديل');
    expect(tester.getCenter(edit).dx, lessThan(1440 / 2));
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => AppDatabase.instance.close());
  });

  testWidgets('الإعدادات: رفع صورة جديدة مع معاينة وتأكيد ثم الاستعادة', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    final (_, settings, logoDir) = await _setup(tester);
    var picked = _png;
    ClinicLogoSettings.pickImage = () async => picked;
    await tester.pumpWidget(
      _app(
        const Scaffold(body: Center(child: ClinicLogoSettings())),
        settings: settings,
      ),
    );
    await _settle(tester);
    expect(find.text('الصورة الافتراضية'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('logoReset'))).onPressed,
      isNull,
    );

    Future<void> realTap(Key k) => tester.runAsync(() async {
      await tester.tap(find.byKey(k));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    });

    // إلغاء المعاينة: لا يتغير شيء.
    await realTap(const Key('logoUpload'));
    expect(find.byKey(const Key('logoConfirm')), findsOneWidget);
    await realTap(const Key('logoConfirmCancel'));
    await _settle(tester);
    expect(settings.logo, isNull);
    final file = File('${logoDir.path}/${LogoRepository.fileName}');
    expect(await tester.runAsync(file.exists), isFalse);

    // اعتماد الصورة: تُحفظ وتظهر في كل النوافذ.
    await realTap(const Key('logoUpload'));
    await realTap(const Key('logoConfirmOk'));
    await _settle(tester);
    expect(settings.logo, _png);
    expect(await tester.runAsync(file.exists), isTrue);
    expect(find.text('صورة مخصصة'), findsOneWidget);
    expect(find.textContaining('تم اعتماد الصورة'), findsOneWidget);
    final box =
        tester
                .widget<Container>(find.byKey(const Key('clinicLogo')))
                .decoration!
            as BoxDecoration;
    expect(box.image!.image, isA<MemoryImage>());

    // ملف ليس صورة: رسالة خطأ دون حفظ.
    picked = Uint8List.fromList(utf8.encode('not an image'));
    await realTap(const Key('logoUpload'));
    await _settle(tester);
    expect(find.byKey(const Key('logoConfirm')), findsNothing);
    expect(find.text('الملف المختار ليس صورة صالحة'), findsOneWidget);
    expect(settings.logo, _png);

    // استعادة الافتراضية.
    await realTap(const Key('logoReset'));
    await _settle(tester);
    expect(settings.logo, isNull);
    expect(await tester.runAsync(file.exists), isFalse);
    expect(find.text('الصورة الافتراضية'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => AppDatabase.instance.close());
  });
}

