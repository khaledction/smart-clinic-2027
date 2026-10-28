import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:neuro_clinic/core/services/password_recovery.dart';
import 'package:neuro_clinic/core/theme/app_theme.dart';
import 'package:neuro_clinic/core/widgets/patient_autocomplete.dart';
import 'package:neuro_clinic/data/models/patient.dart';
import 'package:neuro_clinic/features/settings/about_card.dart';

import 'package:neuro_clinic/core/services/app_folders.dart';
import 'package:neuro_clinic/core/services/developer_mode.dart';
import 'package:neuro_clinic/data/providers/session_provider.dart';
import 'package:neuro_clinic/data/repositories/auth_repository.dart';
import 'package:neuro_clinic/features/patients/patient_form_screen.dart';
import 'package:neuro_clinic/features/sessions/sessions_screen.dart';

void main() {
  group('حساب المبرمج من شاشة الدخول', () {
    tearDown(DeveloperMode.lock);

    test(
      'الدخول باسم khaled.a.f يفتح بيانات العيادة، والخروج يقفلها',
      () async {
        final session = SessionProvider(AuthRepository());
        expect(await session.login(' khaled.a.f ', '@kh@12345678'), isTrue);
        expect(session.user!.isAdmin, isTrue);
        expect(session.user!.id, isNull); // غير مخزَّن في قاعدة البيانات
        expect(DeveloperMode.unlocked.value, isTrue);
        session.logout();
        expect(DeveloperMode.unlocked.value, isFalse);
      },
    );

    test('كلمة مرور خاطئة للمبرمج ترفض دون فتح الوضع', () async {
      final session = SessionProvider(AuthRepository());
      expect(await session.login('khaled.a.f', 'Loranem@0933'), isFalse);
      expect(session.error, isNotNull);
      expect(DeveloperMode.unlocked.value, isFalse);
    });

    test('الاسم محجوز (لا يُنشأ مستخدم عادي بنفس الاسم)', () {
      expect(DeveloperMode.isReserved('KHALED.A.F'), isTrue);
      expect(DeveloperMode.isReserved('admin'), isFalse);
    });
  });

  group('الإدخال الإلزامي الوحيد: اسم المريض الثلاثي', () {
    test('فارغ أو أقل من ثلاث كلمات يرفض، والثلاثي يقبل', () {
      expect(tripleNameError(''), isNotNull);
      expect(tripleNameError('   '), isNotNull);
      expect(tripleNameError('أحمد'), isNotNull);
      expect(tripleNameError('أحمد محمد'), isNotNull);
      expect(tripleNameError('أحمد محمد الخطيب'), isNull);
      expect(tripleNameError('  أحمد   محمد   الخطيب  '), isNull);
    });

    test('الاسم القديم غير المعدَّل يقبل كما هو', () {
      expect(tripleNameError('أحمد محمد', original: 'أحمد محمد'), isNull);
      expect(tripleNameError('أحمد', original: 'أحمد محمد'), isNotNull);
    });

    test('السعر الفارغ في الجلسة مقبول', () {
      expect(validMoney(''), isNull);
      expect(validMoney('-5'), isNotNull);
      expect(validMoney('2500'), isNull);
    });
  });

  testWidgets('حول البرنامج: الميزات وروابط التواصل مع المبرمج', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1300, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final opened = <Uri>[];
    final old = PasswordRecovery.openUri;
    PasswordRecovery.openUri = (u) async => opened.add(u);
    addTearDown(() => PasswordRecovery.openUri = old);

    await tester.pumpWidget(
      const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: SingleChildScrollView(child: AboutCard())),
        ),
      ),
    );
    expect(find.text('برنامج عيادتي الذكي'), findsOneWidget);
    expect(kAboutFeatures.length, 10);
    for (final f in kAboutFeatures) {
      expect(find.text(f), findsOneWidget);
    }
    expect(find.byKey(const Key('aboutDevLogo')), findsOneWidget);
    expect(find.textContaining('Flutter'), findsNothing);
    expect(
      find.textContaining(
        'حقوق النشر والتوزيع لصالح فريق Loraneem Tech',
        findRichText: true,
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'هذه النسخة حصرية لصالح عيادة الدكتور طارق مقلد',
        findRichText: true,
      ),
      findsOneWidget,
    );
    expect(find.textContaining('اختصاصي جراحة عصبية'), findsOneWidget);

    await tester.tap(find.byKey(const Key('aboutEmail')));
    await tester.tap(find.byKey(const Key('aboutWhatsapp')));
    await tester.pump();
    expect(opened.map((u) => u.toString()), [
      'mailto:loraneemtech@gmail.com',
      'https://wa.me/963933713023',
    ]);
  });

  test('النسخ اليدوية في مجلد منفصل بجانب التلقائية', () async {
    final root = await Directory.systemTemp.createTemp('v20b-root-');
    AppFolders.overrideRoot = root.path;
    addTearDown(() => AppFolders.overrideRoot = null);
    expect(AppFolders.windowsRootC, r'C:\myclinic');
    final manual = await AppFolders.manualBackups();
    expect(
      manual.path,
      '${root.path}${Platform.pathSeparator}backups'
      '${Platform.pathSeparator}manual',
    );
    expect(manual.existsSync(), isTrue);
    await AppFolders.ensure();
    expect(Directory('${root.path}/backups/manual').existsSync(), isTrue);
  });

  testWidgets('بحث الزيارات: إكمال تلقائي أثناء الكتابة في مربع الشريط', (
    tester,
  ) async {
    const patients = [
      Patient(id: 1, fileNo: 'A-1', fullName: 'أحمد سالم الخطيب'),
      Patient(id: 2, fileNo: 'B-2', fullName: 'منى خالد العلي'),
    ];
    int? filter = -1;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: 240,
                height: 40,
                child: PatientAutocomplete(
                  fieldKey: const Key('visitsSearch'),
                  patients: patients,
                  autofocus: false,
                  compact: true,
                  hint: 'ابحث عن مريض…',
                  onSelected: (p) => filter = p?.id,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('patientAutocomplete')), findsNothing);
    await tester.enterText(find.byKey(const Key('visitsSearch')), 'من');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('patientOption:2')), findsOneWidget);
    expect(find.byKey(const Key('patientOption:1')), findsNothing);
    await tester.tap(find.byKey(const Key('patientOption:2')));
    await tester.pumpAndSettle();
    expect(filter, 2);
    // تعديل النص بعد الاختيار يعيد عرض كل الزيارات.
    await tester.enterText(find.byKey(const Key('visitsSearch')), 'م');
    await tester.pumpAndSettle();
    expect(filter, isNull);
    expect(tester.takeException(), isNull);
  });
}

