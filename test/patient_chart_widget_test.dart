import 'dart:io';

import 'package:neuro_clinic/features/sessions/sessions_screen.dart';
import 'package:neuro_clinic/data/repositories/clinic_flow_repository.dart';
import 'package:neuro_clinic/data/repositories/treatment_repository.dart';

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:neuro_clinic/core/database/app_database.dart';
import 'package:neuro_clinic/core/database/schema.dart';
import 'package:neuro_clinic/core/database/seed.dart';
import 'package:neuro_clinic/core/theme/app_theme.dart';
import 'package:neuro_clinic/core/widgets/form_fields.dart';
import 'package:neuro_clinic/data/models/patient.dart';
import 'package:neuro_clinic/data/models/visit.dart';
import 'package:neuro_clinic/data/models/appointment.dart';
import 'package:neuro_clinic/data/providers/session_provider.dart';
import 'package:neuro_clinic/data/repositories/auth_repository.dart';
import 'package:neuro_clinic/data/repositories/patient_repository.dart';
import 'package:neuro_clinic/data/repositories/visit_repository.dart';
import 'package:neuro_clinic/features/patients/patient_detail_screen.dart';

void main() {
  for (final width in [1180.0, 1440.0]) {
    testWidgets(
      'Patient chart, numeric age and new-visit reference at width $width',
      // Generous timeout: slow CI/sandbox machines compile the full app here.
      timeout: const Timeout(Duration(minutes: 30)),
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.runAsync(() async {
          await (FontLoader(
            'Cairo',
          )..addFont(rootBundle.load('assets/fonts/Cairo-Regular.ttf'))).load();
          await (FontLoader('NotoSansArabic')..addFont(
                rootBundle.load('assets/fonts/NotoSansArabic-SemiBold.ttf'),
              ))
              .load();
          await (FontLoader('MaterialIcons')
                ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
              .load();
        });
        sqfliteFfiInit();
        late SessionProvider session;
        late int patientId;
        await tester.runAsync(() async {
          final db = await databaseFactoryFfiNoIsolate.openDatabase(
            inMemoryDatabasePath,
          );
          await enableForeignKeys(db);
          await createSchema(db);
          await seedInitialData(db);
          AppDatabase.instance.useTestDatabase(db);
          session = SessionProvider(AuthRepository());
          await session.login('admin', '1234');
          patientId = await PatientRepository().insert(
            Patient(
              fullName: 'مريض تجريبي — بيانات وهمية',
              fileNo: 'P-1001',
              ageYears: 45,
              ageRecordedOn: DateTime(2026, 9, 20),
              gender: 'm',
              phone: '0000000000',
              allergies: 'حساسية مسجّلة للاختبار فقط',
            ),
          );
          await PatientRepository().addHistory(
            MedicalHistoryItem(
              patientId: patientId,
              condition: 'سابقة مرضية تجريبية',
              notes: 'هذه بيانات لعرض الواجهة فقط',
            ),
          );
          await PatientRepository().addMedication(
            Medication(
              patientId: patientId,
              drug: 'دواء تجريبي — ليس وصفة',
              dose: 'غير محددة',
            ),
          );
          await PatientRepository().addInvestigation(
            Investigation(
              patientId: patientId,
              kind: 'تقرير تصوير تجريبي',
              performedOn: DateTime(2026, 9, 1),
              report: 'نص تجريبي',
            ),
          );
          await VisitRepository().saveFull(
            Visit(
              patientId: patientId,
              visitDate: DateTime(2026, 8, 1),
              chiefComplaint: 'الزيارة الأولى للاختبار',
              diagnosis: 'تقييم مسجّل للاختبار',
              plan: 'استكمال التوثيق',
            ),
          );
          await VisitRepository().saveFull(
            Visit(
              patientId: patientId,
              visitDate: DateTime(2026, 9, 1),
              chiefComplaint: 'متابعة الأعراض المسجّلة',
              diagnosis: 'تقييم متابعة تجريبي',
              plan: 'مراجعة التقرير السابق وتوثيق التغيّر',
              followupInDays: 14,
            ),
          );
        });
        final boundaryKey = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundaryKey,
            child: ChangeNotifierProvider.value(
              value: session,
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
                home: PatientDetailScreen(
                  patientId: patientId,
                  name: 'مريض تجريبي',
                ),
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
        expect(find.text('الملف الطبي للمريض'), findsOneWidget);
        expect(find.text('45'), findsWidgets);
        expect(tester.takeException(), null);
        final capture = Platform.environment['CLINIC_SCREENSHOT'];
        if (width == 1440 && capture != null) {
          await tester.runAsync(() async {
            final boundary =
                boundaryKey.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage(pixelRatio: 1);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(capture).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.tap(find.text('تعديل البيانات'));
        await settleDb();
        expect(find.text('العمر بالسنوات'), findsOneWidget);
        expect(find.byType(AppDateField), findsNothing);
        final ageInput = find.ancestor(
          of: find.text('العمر بالسنوات'),
          matching: find.byType(TextFormField),
        );
        await tester.enterText(ageInput, '٤٦');
        final weightField = find.widgetWithText(TextFormField, 'الوزن (كغ)');
        await tester.ensureVisible(weightField);
        await tester.enterText(weightField, '٧٢٫٥');
        await tester.ensureVisible(find.text('حفظ').last);
        await tester.tap(find.text('حفظ').last);
        await settleDb();
        expect(find.text('46'), findsWidgets);
        expect(find.text('72.5'), findsWidgets);
        await tester.tap(find.text('سجل الزيارات').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('فتح الزيارة الأولى'));
        await settleDb();
        expect(find.text('الزيارة الأولى للاختبار'), findsOneWidget);
        expect(find.textContaining('45 سنة'), findsWidgets);
        final detailCapture = Platform.environment['CLINIC_DETAIL_SCREENSHOT'];
        if (width == 1440 && detailCapture != null) {
          await tester.runAsync(() async {
            final boundary =
                boundaryKey.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage(pixelRatio: 1);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(detailCapture).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        expect(tester.takeException(), null);
        // Request independent sessions from the original clinical encounter.
        await tester.ensureVisible(find.text('طلب جلسات / إجراء'));

        await tester.runAsync(
          () => ClinicFlowRepository().savePrices(
            checkup: 100,
            sessions: {'جلسة EMS': 120, 'جلسة سحب فقرات': 150},
          ),
        );
        await tester.tap(find.text('طلب جلسات / إجراء'));
        await settleDb();
        await tester.tap(find.byType(DropdownButton<int>).last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('جلسة سحب فقرات').last);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextFormField, 'عدد الجلسات المخططة (1–100)'),
          '2',
        );
        // السعر ثابت من الإعدادات ← الأسعار (غير قابل للتعديل هنا).
        expect(find.text('150'), findsOneWidget);
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.tap(find.text('إنشاء الطلب'));
        await settleDb();
        await tester.runAsync(() async {
          expect(
            (await TreatmentRepository().sessions(patientId: patientId)).length,
            2,
          );
        });
        Navigator.of(tester.element(find.text('تفاصيل الزيارة'))).push(
          MaterialPageRoute(
            builder: (_) => SessionsScreen(patientId: patientId),
          ),
        );
        await settleDb();
        await tester.tap(find.text('تفاصيل ونتائج الجلسة').first);
        await settleDb();
        // أهم بيانات المريض أعلى النافذة.
        expect(find.byKey(const Key('patientSummary')), findsOneWidget);
        await tester.enterText(
          find.widgetWithText(TextFormField, 'تشخيص / تقييم هذه الجلسة'),
          'تقييم جلسة مستقل للاختبار',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'النتيجة والاستجابة للجلسة'),
          'نتيجة تجريبية — لا تمثل مريضاً',
        );
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.ensureVisible(find.byKey(const Key('sessSave')));
        await tester.tap(find.byKey(const Key('sessSave')));
        await settleDb();
        await tester.ensureVisible(find.text('دفع').first);
        await tester.tap(find.text('دفع').first);
        await settleDb();
        expect(find.text('تم الدفع'), findsOneWidget);
        // نقرة ثانية بالخطأ: تنبيه فقط، دون دفعة مكررة.
        await tester.tap(find.text('تم الدفع'));
        await tester.pumpAndSettle();
        expect(find.text('تنبيه: الدفع مسجّل مسبقاً'), findsOneWidget);
        await tester.tap(find.text('حسناً'));
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          final rows = await TreatmentRepository().sessions(
            patientId: patientId,
          );
          expect(rows.where((r) => r['payment_id'] != null).length, 1);
          expect(rows.every((r) => r['status'] == 'requested'), true);
        });
        final sessionsCapture =
            Platform.environment['CLINIC_SESSIONS_SCREENSHOT'];
        if (width == 1440 && sessionsCapture != null) {
          await tester.runAsync(() async {
            final boundary =
                boundaryKey.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage(pixelRatio: 1);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(sessionsCapture)
                .writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        Navigator.of(tester.element(find.text('الجلسات والإجراءات').first))
            .pop();
        await settleDb();
        Navigator.of(tester.element(find.text('تفاصيل الزيارة'))).pop();
        await settleDb();
        await tester.tap(find.text('بدء زيارة جديدة'));
        await settleDb();
        expect(find.textContaining('مرجع قبل الكشف'), findsOneWidget);
        expect(find.textContaining('الخطة السابقة:'), findsOneWidget);
        expect(find.text('نوع الجلسة'), findsNothing);
        final typeField = find.byWidgetPredicate(
          (w) => w is AppDropdownField<String> && w.label == 'نوع الزيارة',
        );
        await tester.ensureVisible(typeField);
        await tester.tap(
          find.descendant(
            of: typeField,
            matching: find.byType(DropdownButton<String>),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('جلسة').last);
        await tester.pumpAndSettle();
        final sessionKind = find.byWidgetPredicate(
          (w) => w is AppDropdownField<String> && w.label == 'نوع الجلسة',
        );
        await tester.ensureVisible(sessionKind);
        await tester.tap(
          find.descendant(
            of: sessionKind,
            matching: find.byType(DropdownButton<String>),
          ),
        );
        await tester.pumpAndSettle();
        // نوعا الجلسات المعتمدان فقط (لا خيار «أخرى»).
        expect(find.text('أخرى'), findsNothing);
        await tester.tap(
          find.text(width == 1180 ? 'جلسة سحب فقرات' : 'جلسة EMS').last,
        );
        await tester.pumpAndSettle();
        final speech = find.byWidgetPredicate(
          (w) => w is AppDropdownField<String> && w.label == 'الكلام واللغة',
        );
        await tester.ensureVisible(speech);
        await tester.tap(
          find.descendant(
            of: speech,
            matching: find.byType(DropdownButton<String>),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('آخر').last);
        await tester.pumpAndSettle();
        final other = find.byWidgetPredicate(
          (w) => w is AppTextField && w.label == 'تفاصيل أخرى للكلام واللغة',
        );
        await tester.ensureVisible(other);
        await tester.enterText(
          find.descendant(of: other, matching: find.byType(TextFormField)),
          'وصف يدوي للاختبار',
        );
        final sensation = find.byWidgetPredicate(
          (w) => w is AppDropdownField<String> && w.label == 'الإحساس',
        );
        await tester.ensureVisible(sensation);
        await tester.tap(
          find.descendant(
            of: sensation,
            matching: find.byType(DropdownButton<String>),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('متوسط').last);
        await tester.pumpAndSettle();
        final complaint = tester.widget<AppTextField>(
          find.byWidgetPredicate(
            (w) => w is AppTextField && w.label == 'الشكوى الرئيسية',
          ),
        );
        expect(complaint.controller!.text, isEmpty);
        final field = find.descendant(
          of: find.byWidget(complaint),
          matching: find.byType(TextFormField),
        );
        await tester.ensureVisible(field);
        await tester.enterText(field, 'زيارة جديدة مستقلة');
        // Plan dropdowns create linked requests automatically on save.
        Future<void> pickPlan(String label, String choice) async {
          final drop = find.byWidgetPredicate(
            (w) => w is AppDropdownField<String> && w.label == label,
          );
          await tester.ensureVisible(drop);
          await tester.tap(
            find.descendant(
              of: drop,
              matching: find.byType(DropdownButton<String>),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text(choice).last);
          await tester.pumpAndSettle();
        }

        await pickPlan('جلسة مطلوبة', 'جلسة EMS');
        await pickPlan('تصوير مطلوب', 'طبقي محوري');
        await pickPlan('استشارة', 'استشارة طبية');
        final consultField = find.byWidgetPredicate(
          (w) => w is AppTextField && w.label == 'اسم الطبيب المستشار',
        );
        await tester.ensureVisible(consultField);
        await tester.enterText(
          find.descendant(
            of: consultField,
            matching: find.byType(TextFormField),
          ),
          'د. اختبار الواجهة',
        );
        await pickPlan('تحويل إلى', 'مشفى');
        final destField = find.byWidgetPredicate(
          (w) => w is AppTextField && w.label == 'اسم الجهة المحوَّل إليها',
        );
        await tester.ensureVisible(destField);
        await tester.enterText(
          find.descendant(of: destField, matching: find.byType(TextFormField)),
          'مشفى الاختبار',
        );
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('حفظ الزيارة'));
        await tester.pumpAndSettle();
        final formCapture = Platform.environment['CLINIC_FORM_SCREENSHOT'];
        if (width == 1440 && formCapture != null) {
          await tester.pumpAndSettle();
          await tester.runAsync(() async {
            final boundary =
                boundaryKey.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage(pixelRatio: 1);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(formCapture).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.tap(find.text('حفظ الزيارة'));
        await settleDb();
        await tester.runAsync(() async {
          final visits = await VisitRepository().forPatient(patientId);
          expect(visits.length, 3);
          expect(visits.first.visitType, 'session');
          expect(
            visits.first.sessionName,
            width == 1180 ? 'جلسة سحب فقرات' : 'جلسة EMS',
          );
          // زيارة «جلسة» = جلسة منفّذة + تبويب «جلسة» = جلسة مجدولة بموعد.
          final planSessions = await TreatmentRepository().sessions(
            visitId: visits.first.id!,
          );
          expect(planSessions.length, 2);
          final done = planSessions.singleWhere(
            (r) => r['status'] == 'completed',
          );
          expect(
            done['service_name'],
            width == 1180 ? 'جلسة سحب فقرات' : 'جلسة EMS',
          );
          final scheduled = planSessions.singleWhere(
            (r) => r['status'] == 'scheduled',
          );
          expect(scheduled['service_name'], 'جلسة EMS');
          final apptDb = await AppDatabase.instance.database;
          final appts = await apptDb.query(
            'appointments',
            where: 'session_id = ?',
            whereArgs: [scheduled['id']],
          );
          expect(appts.single['kind'], 'session');
          expect(appts.single['session_name'], 'جلسة EMS');
          final planDb = await AppDatabase.instance.database;
          expect(
            await planDb.query(
              'investigations',
              where: 'visit_id = ?',
              whereArgs: [visits.first.id!],
            ),
            hasLength(1),
          );
          expect(
            await planDb.query(
              'referrals',
              where: 'visit_id = ?',
              whereArgs: [visits.first.id!],
            ),
            hasLength(2),
          );
          final full = await VisitRepository().full(visits.first.id!);
          expect(full?.exam?.speech, 'آخر: وصف يدوي للاختبار');
          expect(full?.exam?.sensation, 'متوسط');
          expect(visits.first.chiefComplaint, 'زيارة جديدة مستقلة');
          expect(visits.last.chiefComplaint, 'الزيارة الأولى للاختبار');
        });
        expect(tester.takeException(), null);
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(() => AppDatabase.instance.close());
        session.dispose();
      },
    );
  }
}
