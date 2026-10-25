import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:neuro_clinic/core/database/app_database.dart';
import 'package:neuro_clinic/core/database/schema.dart';
import 'package:neuro_clinic/core/database/seed.dart';
import 'package:neuro_clinic/core/theme/app_theme.dart';
import 'package:neuro_clinic/core/utils/date_fmt.dart';
import 'package:neuro_clinic/data/models/patient.dart';
import 'package:neuro_clinic/data/providers/appointments_provider.dart';
import 'package:neuro_clinic/data/providers/patients_provider.dart';
import 'package:neuro_clinic/data/providers/session_provider.dart';
import 'package:neuro_clinic/data/repositories/appointment_repository.dart';
import 'package:neuro_clinic/data/repositories/auth_repository.dart';
import 'package:neuro_clinic/data/repositories/patient_repository.dart';
import 'package:neuro_clinic/data/repositories/visit_repository.dart';
import 'package:neuro_clinic/features/hub/patients_appointments_screen.dart';

Future<void> _loadFonts(WidgetTester tester) => tester.runAsync(() async {
  await (FontLoader(
    'Cairo',
  )..addFont(rootBundle.load('assets/fonts/Cairo-Regular.ttf'))).load();
  await (FontLoader('NotoSansArabic')
        ..addFont(rootBundle.load('assets/fonts/NotoSansArabic-SemiBold.ttf')))
      .load();
  await (FontLoader(
    'MaterialIcons',
  )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
});

Widget _hub(SessionProvider session) => MultiProvider(
  providers: [
    ChangeNotifierProvider.value(value: session),
    ChangeNotifierProvider(
      create: (_) => PatientsProvider(PatientRepository()),
    ),
    ChangeNotifierProvider(
      create: (_) => AppointmentsProvider(AppointmentRepository()),
    ),
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
    home: const Scaffold(body: PatientsAppointmentsScreen()),
  ),
);

void main() {
  test(
    'completedOn returns only today-completed visits, newest first',
    timeout: const Timeout(Duration(minutes: 5)),
    () async {
      sqfliteFfiInit();
      final dir = await Directory.systemTemp.createTemp('clinic-v6-');
      final db = await databaseFactoryFfiNoIsolate.openDatabase(
        '${dir.path}/test.db',
      );
      try {
        await enableForeignKeys(db);
        await createSchema(db);
        final pid = await db.insert('patients', {'full_name': 'مريض الإنجاز'});
        final now = DateTime.now();
        final yesterday = now.subtract(const Duration(days: 1));
        await db.insert('visits', {
          'patient_id': pid,
          'visit_date': DateFmt.isoDate(yesterday),
          'visit_type': 'new',
          'completed_at': yesterday.toIso8601String(),
        });
        await db.insert('visits', {
          'patient_id': pid,
          'visit_date': DateFmt.isoDate(now),
          'visit_type': 'new',
          'completed_at': DateTime(
            now.year,
            now.month,
            now.day,
            9,
            0,
          ).toIso8601String(),
        });
        await db.insert('visits', {
          'patient_id': pid,
          'visit_date': DateFmt.isoDate(now),
          'visit_type': 'procedure',
          'visit_category': 'session',
          'completed_at': DateTime(
            now.year,
            now.month,
            now.day,
            11,
            30,
          ).toIso8601String(),
        });
        await db.insert('visits', {
          'patient_id': pid,
          'visit_date': DateFmt.isoDate(now),
          'visit_type': 'new',
        });
        AppDatabase.instance.useTestDatabase(db);
        final done = await VisitRepository().completedOn(now);
        expect(done.length, 2);
        expect(done.first.visitType, 'session');
        expect(done.first.patientName, 'مريض الإنجاز');
        expect(done.last.visitType, 'new');
      } finally {
        await AppDatabase.instance.close();
        await db.close();
        await dir.delete(recursive: true);
      }
    },
  );

  testWidgets(
    'Hub appointment search, done-visits filter, edit/move dialogs',
    timeout: const Timeout(Duration(minutes: 30)),
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      late SessionProvider session;
      late Directory dir;
      await _loadFonts(tester);
      await tester.runAsync(() async {
        sqfliteFfiInit();
        dir = await Directory.systemTemp.createTemp('clinic-v6-');
        final db = await databaseFactoryFfiNoIsolate.openDatabase(
          '${dir.path}/test.db',
        );
        await enableForeignKeys(db);
        await createSchema(db);
        await seedInitialData(db);
        AppDatabase.instance.useTestDatabase(db);
        session = SessionProvider(AuthRepository());
        await session.login('admin', '1234');
        final now = DateTime.now();
        final day = DateTime(now.year, now.month, now.day);
        final repo = PatientRepository();
        final salem = await repo.insert(
          const Patient(fullName: 'salem الحجز', fileNo: 'V6-1'),
        );
        final noura = await repo.insert(
          const Patient(fullName: 'نورا الحجز', fileNo: 'V6-2'),
        );
        final karim = await repo.insert(
          const Patient(fullName: 'كريم الجلسة', fileNo: 'V6-3'),
        );
        final hind = await repo.insert(
          const Patient(fullName: 'هند المعاينة', fileNo: 'V6-4'),
        );
        final old = await repo.insert(
          const Patient(fullName: 'قديم الأمس', fileNo: 'V6-5'),
        );
        await db.insert('appointments', {
          'patient_id': salem,
          'start_at': DateTime(
            day.year,
            day.month,
            day.day,
            9,
            0,
          ).toIso8601String(),
          'status': 'scheduled',
          'kind': 'checkup',
        });
        await db.insert('appointments', {
          'patient_id': noura,
          'start_at': DateTime(
            day.year,
            day.month,
            day.day,
            10,
            0,
          ).toIso8601String(),
          'status': 'scheduled',
          'kind': 'session',
          'session_name': 'جلسة EMS',
        });
        final stamp = DateTime(
          day.year,
          day.month,
          day.day,
          12,
          0,
        ).toIso8601String();
        await db.insert('visits', {
          'patient_id': karim,
          'visit_date': DateFmt.isoDate(day),
          'visit_type': 'procedure',
          'visit_category': 'session',
          'completed_at': stamp,
        });
        await db.insert('visits', {
          'patient_id': hind,
          'visit_date': DateFmt.isoDate(day),
          'visit_type': 'new',
          'completed_at': stamp,
        });
        final yd = day.subtract(const Duration(days: 1));
        await db.insert('visits', {
          'patient_id': old,
          'visit_date': DateFmt.isoDate(yd),
          'visit_type': 'new',
          'completed_at': DateTime(
            yd.year,
            yd.month,
            yd.day,
            12,
            0,
          ).toIso8601String(),
        });
      });

      await tester.pumpWidget(_hub(session));
      Future<void> settleDb() async {
        await tester.runAsync(() async {
          await tester.pump();
          await Future<void>.delayed(const Duration(milliseconds: 500));
        });
        await tester.pumpAndSettle();
      }

      await settleDb();
      // كل اسم يظهر في لوحة المرضى + سطره (موعد/منجزة).
      expect(find.text('salem الحجز'), findsNWidgets(2));
      expect(find.text('نورا الحجز'), findsNWidgets(2));

      // بحث المواعيد يصفّي قائمة المواعيد فقط (لوحة المرضى لا تتأثر).
      await tester.enterText(find.byKey(const Key('apptSearch')), 'نورا');
      await tester.pumpAndSettle();
      expect(find.text('salem الحجز'), findsOneWidget);
      expect(find.text('نورا الحجز'), findsNWidgets(2));
      await tester.enterText(find.byKey(const Key('apptSearch')), '');
      await tester.pumpAndSettle();
      expect(find.text('salem الحجز'), findsNWidgets(2));

      // المواعيد مقسومة: معاينات وجلسات.
      expect(find.text('مواعيد المعاينات'), findsOneWidget);
      expect(find.text('مواعيد الجلسات'), findsOneWidget);
      expect(find.text('غير محدد'), findsNothing);
      expect(find.text('تمت الزيارة'), findsOneWidget);
      expect(find.text('تمت الجلسة'), findsOneWidget);

      // بطاقة المنجزة مقسومة (زيارة الأمس لا تظهر).
      await tester.ensureVisible(find.text('المنجزة اليوم'));
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();
      expect(find.text('المعاينات المنجزة'), findsOneWidget);
      expect(find.text('الجلسات المنجزة'), findsOneWidget);
      expect(find.text('كريم الجلسة'), findsNWidgets(2));
      expect(find.text('هند المعاينة'), findsNWidgets(2));
      expect(find.text('قديم الأمس'), findsOneWidget);
      expect(find.text('دفع'), findsOneWidget);

      // حوار التعديل يفتح ويُلغى.
      await tester.drag(
        find.byKey(const Key('hubScroll')),
        const Offset(0, 600),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('تعديل الموعد'));
      await tester.pumpAndSettle();
      expect(find.textContaining('تعديل موعد'), findsOneWidget);
      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();

      // حوار النقل يفتح منتقي التاريخ ويُلغى.
      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('نقل إلى يوم آخر'));
      await tester.pumpAndSettle();
      expect(find.text('نقل الموعد إلى يوم آخر'), findsOneWidget);
      // إلغاء النقل بالنقر خارج المنتقي (نص زر الإلغاء مترجم حسب اللغة).
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
      expect(find.text('نقل الموعد إلى يوم آخر'), findsNothing);

      // "تمت الزيارة" تنقل الموعد إلى المعاينات المنجزة.
      await tester.tap(find.text('تمت الزيارة'));
      await settleDb();
      await settleDb();
      expect(find.textContaining('تم وضع علامة'), findsOneWidget);
      expect(find.text('تمت الزيارة'), findsNothing);
      // salem: لوحة المرضى + المعاينات المنجزة.
      expect(find.text('salem الحجز'), findsNWidgets(2));
      await tester.runAsync(() async {
        final db = await AppDatabase.instance.database;
        final appt = await db.query('appointments', where: "kind = 'checkup'");
        expect(appt.single['status'], 'done');
        expect(appt.single['visit_id'], isNotNull);
      });
      expect(tester.takeException(), null);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() => AppDatabase.instance.close());
      await tester.runAsync(() => dir.delete(recursive: true));
      session.dispose();
    },
  );

  testWidgets(
    'Hub narrow layout stacks without overflow stripes',
    timeout: const Timeout(Duration(minutes: 30)),
    (tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      late SessionProvider session;
      late Directory dir;
      await _loadFonts(tester);
      await tester.runAsync(() async {
        sqfliteFfiInit();
        dir = await Directory.systemTemp.createTemp('clinic-v6-');
        final db = await databaseFactoryFfiNoIsolate.openDatabase(
          '${dir.path}/test.db',
        );
        await enableForeignKeys(db);
        await createSchema(db);
        await seedInitialData(db);
        AppDatabase.instance.useTestDatabase(db);
        session = SessionProvider(AuthRepository());
        await session.login('admin', '1234');
        await PatientRepository().insert(
          const Patient(fullName: 'مريض العرض الضيق', fileNo: 'V6-N'),
        );
      });

      await tester.pumpWidget(_hub(session));
      Future<void> settleDb() async {
        await tester.runAsync(() async {
          await tester.pump();
          await Future<void>.delayed(const Duration(milliseconds: 500));
        });
        await tester.pumpAndSettle();
      }

      await settleDb();
      expect(find.text('مريض العرض الضيق'), findsOneWidget);
      // مرّر عبر كل البطاقات (النموذج المكدس + المنجزة) ثم تأكد من غياب أخطاء التجاوز.
      await tester.ensureVisible(find.text('موعد جديد'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('المنجزة اليوم'));
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();
      expect(find.text('حفظ الموعد'), findsOneWidget);
      expect(tester.takeException(), null);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() => AppDatabase.instance.close());
      await tester.runAsync(() => dir.delete(recursive: true));
      session.dispose();
    },
  );
}
