import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:neuro_clinic/main.dart';
import 'package:neuro_clinic/core/database/app_database.dart';
import 'package:neuro_clinic/core/database/schema.dart';
import 'package:neuro_clinic/core/database/seed.dart';

void main() {
  testWidgets('Arabic login and desktop dashboard render', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    sqfliteFfiInit();
    late Database db;
    await tester.runAsync(() async {
      db = await databaseFactoryFfiNoIsolate.openDatabase(inMemoryDatabasePath);
      await enableForeignKeys(db);
      await createSchema(db);
      await seedInitialData(db);
      AppDatabase.instance.useTestDatabase(db);
    });
    await tester.pumpWidget(const NeuroClinicApp());
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
    expect(find.text('دخول'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).last, '1234');
    await tester.tap(find.text('دخول'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(seconds: 2));
    });
    await tester.runAsync(() async {
      await tester.pump();
      await Future<void>.delayed(const Duration(seconds: 2));
      await tester.pump();
    });
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(seconds: 1));
    });
    await tester.pumpAndSettle();
    expect(find.text('تسجيل الخروج'), findsNothing);
    expect(find.text('لوحة اليوم'), findsWidgets);
    expect(tester.takeException(), null);
    // نافذتان مستقلتان لمواعيد اليوم + «تمت / لم تتم بعد» في البطاقات.
    expect(find.text('مواعيد معاينات اليوم'), findsOneWidget);
    expect(find.byKey(const Key('todayEms')), findsOneWidget);
    expect(find.byKey(const Key('todayTraction')), findsOneWidget);
    expect(find.text('جلسة سحب فقرات'), findsWidgets);
    expect(find.text('مواعيد اليوم'), findsNothing);
    expect(find.textContaining('لم تتم بعد'), findsWidgets);
    for (final label in [
      'المرضى والمواعيد',
      'الزيارات',
      'الجلسات والإجراءات',
      'المالية',
      'التقارير',
      'الإعدادات',
    ]) {
      await tester.tap(find.text(label).first);
      await tester.runAsync(() async {
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();
      expect(tester.takeException(), null, reason: label);
      if (label == 'الجلسات والإجراءات' || label == 'المالية') {
        // العنوان في الشريط العلوي للبرنامج فقط، دون شريط عنوان مكرر.
        expect(find.byType(AppBar), findsNothing, reason: label);
      }
      if (label == 'المالية') {
        expect(find.byKey(const Key('financeSearch')), findsOneWidget);
        expect(find.text('سجل الدفعات'), findsOneWidget);
      }
      if (label == 'الزيارات') {
        final button = tester.getSize(find.byKey(const Key('newVisit')));
        expect(button.height, 40);
        expect(button.width, 240);
      }
    }

    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => AppDatabase.instance.close());
  });
}
