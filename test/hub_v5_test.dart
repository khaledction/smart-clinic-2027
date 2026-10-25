import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:neuro_clinic/core/database/app_database.dart';
import 'package:neuro_clinic/core/database/schema.dart';
import 'package:neuro_clinic/core/database/seed.dart';
import 'package:neuro_clinic/core/theme/app_theme.dart';
import 'package:neuro_clinic/data/models/patient.dart';
import 'package:neuro_clinic/data/providers/appointments_provider.dart';
import 'package:neuro_clinic/data/providers/patients_provider.dart';
import 'package:neuro_clinic/data/providers/session_provider.dart';
import 'package:neuro_clinic/data/repositories/appointment_repository.dart';
import 'package:neuro_clinic/data/repositories/auth_repository.dart';
import 'package:neuro_clinic/data/repositories/patient_repository.dart';
import 'package:neuro_clinic/features/hub/patients_appointments_screen.dart';

void main() {
  testWidgets(
    'Hub lists patients and appointments; tapping a patient starts a visit',
    timeout: const Timeout(Duration(minutes: 30)),
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      late SessionProvider session;
      await tester.runAsync(() async {
        await (FontLoader(
          'Cairo',
        )..addFont(rootBundle.load('assets/fonts/Cairo-Regular.ttf'))).load();
        await (FontLoader('NotoSansArabic')..addFont(
              rootBundle.load('assets/fonts/NotoSansArabic-SemiBold.ttf'),
            ))
            .load();
        await (FontLoader(
          'MaterialIcons',
        )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      });
      await tester.runAsync(() async {
        sqfliteFfiInit();
        final db = await databaseFactoryFfiNoIsolate.openDatabase(
          inMemoryDatabasePath,
        );
        await enableForeignKeys(db);
        await createSchema(db);
        await seedInitialData(db);
        AppDatabase.instance.useTestDatabase(db);
        session = SessionProvider(AuthRepository());
        await session.login('admin', '1234');
        await PatientRepository().insert(
          const Patient(fullName: 'مريض المركز', fileNo: 'H-1'),
        );
      });

      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          child: MultiProvider(
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
          ),
        ),
      );
      Future<void> settleDb() async {
        await tester.runAsync(() async {
          await tester.pump();
          await Future<void>.delayed(const Duration(milliseconds: 500));
        });
        await tester.pumpAndSettle();
      }

      await settleDb();
      expect(
        find.text('المرضى والمواعيد'),
        findsNothing,
      ); // title lives in rail
      expect(find.textContaining('المرضى ('), findsOneWidget);
      expect(find.text('مريض المركز'), findsOneWidget);
      expect(find.text('موعد جديد'), findsOneWidget);

      final hubCapture = Platform.environment['CLINIC_HUB_SCREENSHOT'];
      if (hubCapture != null) {
        await tester.runAsync(() async {
          final boundary =
              boundaryKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(hubCapture).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      // One tap on the patient opens a new visit directly.
      await tester.tap(find.text('مريض المركز'));
      await settleDb();
      expect(find.textContaining('زيارة جديدة'), findsOneWidget);
      expect(find.textContaining('مرجع قبل الكشف'), findsOneWidget);

      // Cancel back to the hub; the file button opens the full record.
      await tester.tap(find.text('إلغاء'));
      await settleDb();
      await tester.tap(find.byTooltip('فتح الملف'));
      await settleDb();
      expect(find.text('الملف الطبي للمريض'), findsOneWidget);

      expect(tester.takeException(), null);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() => AppDatabase.instance.close());
      session.dispose();
    },
  );
}
