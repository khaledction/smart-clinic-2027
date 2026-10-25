import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:neuro_clinic/core/database/app_database.dart';
import 'package:neuro_clinic/core/database/schema.dart';
import 'package:neuro_clinic/core/database/seed.dart';
import 'package:neuro_clinic/core/theme/app_theme.dart';
import 'package:neuro_clinic/core/theme/app_colors.dart';
import 'package:neuro_clinic/core/theme/app_sizes.dart';
import 'package:neuro_clinic/data/repositories/treatment_repository.dart';
import 'package:neuro_clinic/features/sessions/sessions_screen.dart';

Widget _app(Widget home) {
  final app = MaterialApp(
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
  return app;
}

Future<Database> _openDb(WidgetTester tester) async {
  late Database db;
  await tester.runAsync(() async {
    sqfliteFfiInit();
    final dir = await Directory.systemTemp.createTemp('v11-');
    db = await databaseFactoryFfiNoIsolate.openDatabase('${dir.path}/t.db');
    await enableForeignKeys(db);
    await createSchema(db);
    await seedInitialData(db);
    AppDatabase.instance.useTestDatabase(db);
  });
  return db;
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(() async {
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 250));
    });
  }
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'نافذة تفاصيل ونتائج الجلسة: ملخص المريض + خمسة أزرار موحدة + «تمت الجلسة» أخضر',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      final db = await _openDb(tester);
      late int patientId;
      await tester.runAsync(() async {
        patientId = await db.insert('patients', {
          'full_name': 'مريض الجلسة',
          'file_no': 'J-9',
          'age_years': 52,
          'weight_kg': 81,
          'blood_type': 'A+',
        });
        final visitId = await db.insert('visits', {
          'patient_id': patientId,
          'visit_date': '2025-03-04',
        });
        await TreatmentRepository().request(
          patientId: patientId,
          sourceVisitId: visitId,
          name: 'EMS',
          count: 1,
          price: 100,
        );
      });
      await tester.pumpWidget(_app(SessionsScreen(patientId: patientId)));
      await _settle(tester);
      await tester.tap(find.text('تفاصيل ونتائج الجلسة').first);
      await _settle(tester);

      // أعلى النافذة: أهم بيانات المريض.
      final summary = find.byKey(const Key('patientSummary'));
      expect(summary, findsOneWidget);
      for (final t in ['مريض الجلسة', '52 سنة', '81 كغ', 'A+', '4/3/2025']) {
        expect(
          find.descendant(of: summary, matching: find.text(t)),
          findsOneWidget,
          reason: t,
        );
      }
      expect(
        find.descendant(
          of: summary,
          matching: find.textContaining('زمرة الدم'),
        ),
        findsOneWidget,
      );

      // الأزرار الخمسة في الأسفل: صف واحد، عرض وارتفاع متطابقان.
      const keys = [
        'sessOpenVisit',
        'sessSchedule',
        'sessDone',
        'sessSave',
        'sessCancel',
      ];
      final rects = [for (final k in keys) tester.getRect(find.byKey(Key(k)))];
      for (final r in rects) {
        expect(r.height, AppSizes.button);
        expect(r.width, closeTo(rects.first.width, 0.5));
        expect(r.top, closeTo(rects.first.top, 0.5));
      }
      for (final t in [
        'فتح الزيارة التي طلبت الجلسة',
        'تحديد موعد الجلسة الجديد',
        'تنفيذ الجلسة',
        'حفظ الجلسة',
        'إلغاء',
      ]) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
      // الأزرار أسفل الحقول.
      expect(
        rects.first.top,
        greaterThan(
          tester
              .getRect(find.widgetWithText(TextFormField, 'ملاحظات الجلسة'))
              .bottom,
        ),
      );
      Color? bg(String k) => tester
          .widget<FilledButton>(find.byKey(Key(k)))
          .style
          ?.backgroundColor
          ?.resolve({});
      expect(bg('sessDone'), isNull); // لون الثيم الكحلي

      // تنفيذ الجلسة ← أخضر «تمت الجلسة» وتاريخ اليوم.
      await tester.tap(find.byKey(const Key('sessDone')));
      await tester.pump();
      expect(find.text('تمت الجلسة'), findsOneWidget);
      expect(find.text('تنفيذ الجلسة'), findsNothing);
      expect(bg('sessDone'), AppColors.paid);
      expect(find.textContaining('تاريخ التنفيذ: غير محدد'), findsNothing);

      await tester.tap(find.byKey(const Key('sessSave')));
      await _settle(tester);
      expect(find.byKey(const Key('sessionDialog')), findsNothing);
      await tester.runAsync(() async {
        final row = (await TreatmentRepository().sessions(patientId: patientId))
            .single;
        expect(row['status'], 'completed');
        expect(row['performed_on'], isNotNull);
        expect(row['payment_id'], isNull); // الحفظ لا يسجل دفعة
      });

      // عند إعادة الفتح يبقى الزر أخضر «تمت الجلسة».
      await tester.tap(find.text('تفاصيل ونتائج الجلسة').first);
      await _settle(tester);
      expect(find.text('تمت الجلسة'), findsOneWidget);
      expect(bg('sessDone'), AppColors.paid);
      await tester.tap(find.byKey(const Key('sessCancel')));
      await _settle(tester);
      expect(find.byKey(const Key('sessionDialog')), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() => AppDatabase.instance.close());
    },
  );
}
