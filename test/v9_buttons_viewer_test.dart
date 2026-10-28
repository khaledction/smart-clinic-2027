import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:neuro_clinic/core/database/app_database.dart';
import 'package:neuro_clinic/core/database/schema.dart';
import 'package:neuro_clinic/core/database/seed.dart';
import 'package:neuro_clinic/core/theme/app_colors.dart';
import 'package:neuro_clinic/core/theme/app_sizes.dart';
import 'package:neuro_clinic/core/theme/app_theme.dart';
import 'package:neuro_clinic/core/widgets/attachment_viewer.dart';
import 'package:neuro_clinic/data/providers/session_provider.dart';
import 'package:neuro_clinic/data/repositories/auth_repository.dart';
import 'package:neuro_clinic/data/repositories/clinic_flow_repository.dart';
import 'package:neuro_clinic/features/investigations/investigations_screen.dart';
import 'package:neuro_clinic/features/sessions/sessions_screen.dart';
import 'package:neuro_clinic/features/visits/visit_form_screen.dart';

/// صورة PNG صغيرة (1×1) صالحة.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

Widget _app(Widget home, {SessionProvider? session}) {
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
  if (session == null) return app;
  return ChangeNotifierProvider.value(value: session, child: app);
}

Future<Database> _openDb(WidgetTester tester) async {
  late Database db;
  await tester.runAsync(() async {
    sqfliteFfiInit();
    final dir = await Directory.systemTemp.createTemp('v9-');
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
  test('كل الأزرار: كحلي + خط أبيض + مقاس وشكل واحد', () {
    final theme = AppTheme.light();
    for (final style in [
      theme.filledButtonTheme.style!,
      theme.outlinedButtonTheme.style!,
      theme.textButtonTheme.style!,
      theme.elevatedButtonTheme.style!,
    ]) {
      expect(style.backgroundColor!.resolve({}), AppColors.navy);
      expect(style.foregroundColor!.resolve({}), Colors.white);
      expect(style.minimumSize!.resolve({}), const Size(0, AppSizes.button));
      final shape = style.shape!.resolve({})! as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(AppSizes.buttonRadius));
    }
  });

  testWidgets('معاينة الصور: تكبير بالمفاتيح + و − و 0 وبدولاب الفأرة', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: AttachmentViewer(
            files: [
              ViewerFile(name: 'mri.png', load: () async => _png),
              ViewerFile(name: 'xray.png', load: () async => _png),
            ],
          ),
        ),
      ),
    );
    await _settle(tester);
    String label() =>
        tester.widget<Text>(find.byKey(const Key('zoomLabel'))).data!;
    expect(label(), '100%');
    expect(find.textContaining('معاينة الصور أو PDF'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.equal); // مفتاح + / =
    await tester.pump();
    expect(label(), '125%');
    await tester.sendKeyEvent(LogicalKeyboardKey.numpadAdd);
    await tester.pump();
    expect(label(), '156%');
    await tester.sendKeyEvent(LogicalKeyboardKey.minus);
    await tester.pump();
    expect(label(), '125%');
    await tester.sendKeyEvent(LogicalKeyboardKey.numpadSubtract);
    await tester.pump();
    expect(label(), '100%');
    await tester.sendKeyEvent(LogicalKeyboardKey.equal);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit0);
    await tester.pump();
    expect(label(), '100%');

    // الأزرار في الشريط.
    await tester.tap(find.byKey(const Key('zoomIn')));
    await tester.pump();
    expect(label(), '125%');
    await tester.tap(find.byKey(const Key('zoomOut')));
    await tester.pump();
    expect(label(), '100%');

    // دولاب الفأرة للأعلى = تكبير.
    final center = tester.getCenter(find.byKey(const Key('attachmentZoom')));
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(pointer.hover(center));
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, -200)));
    await tester.pump();
    final zoomed = int.parse(label().replaceAll('%', ''));
    expect(zoomed, greaterThan(100));
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, 400)));
    await tester.pump();
    expect(int.parse(label().replaceAll('%', '')), lessThan(zoomed));

    // التنقل بين الملفات يعيد الحجم.
    await tester.tap(find.text('xray.png'));
    await _settle(tester);
    expect(label(), '100%');
  });

  testWidgets('نافذة الفحوص: ترويسة المريض + تسميات ورموز وأزرار الوثيقة', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    final db = await _openDb(tester);
    late int patientId;
    await tester.runAsync(() async {
      patientId = await db.insert('patients', {
        'full_name': 'مريض الترويسة',
        'file_no': 'F-77',
        'phone': '0999123456',
        'allergies': 'بنسلين',
      });
      await db.insert('investigations', {
        'patient_id': patientId,
        'kind': 'رنين قديم',
        'performed_on': DateTime.now().toIso8601String().substring(0, 10),
        'workflow_status': 'legacy',
      });
    });
    await tester.pumpWidget(_app(InvestigationsScreen(patientId: patientId)));
    await _settle(tester);

    // الترويسة نفسها الموجودة في الملف الطبي.
    expect(find.byKey(const Key('patientChartHeader')), findsOneWidget);
    expect(find.text('مريض الترويسة'), findsOneWidget);
    expect(find.text('F-77'), findsOneWidget);
    expect(find.textContaining('0999123456'), findsOneWidget);
    expect(find.textContaining('بنسلين'), findsOneWidget);

    // التسمية الجديدة مع رمز الحالة (القيمة المخزنة legacy لم تتغير).
    expect(find.text('صور وتحاليل سابقة'), findsOneWidget);
    expect(find.text('سجل سابق — راجع تصنيفه'), findsNothing);
    expect(find.byIcon(Icons.photo_library_outlined), findsWidgets);

    await tester.tap(find.text('فتح / تعديل'));
    await _settle(tester);
    expect(find.text('تعديل توثيق الفحص'), findsOneWidget);
    for (final entry in {
      'إرفاق الصور أو PDF': Icons.attach_file,
      'معاينة الصور أو PDF': Icons.visibility_outlined,
      'حفظ': Icons.save_outlined,
      'إلغاء': Icons.close,
    }.entries) {
      final button = find.ancestor(
        of: find.text(entry.key),
        matching: find.bySubtype<ButtonStyleButton>(),
      );
      expect(button, findsOneWidget, reason: entry.key);
      expect(
        find.descendant(of: button, matching: find.byIcon(entry.value)),
        findsOneWidget,
        reason: entry.key,
      );
      expect(tester.getSize(button).height, AppSizes.button);
    }
    // معاينة دون مرفقات: رسالة واضحة.
    await tester.tap(find.byKey(const Key('invPreview')));
    await tester.pump();
    expect(find.textContaining('لا توجد صور أو ملفات PDF'), findsOneWidget);
    await tester.tap(find.byKey(const Key('invCancel')));
    await _settle(tester);

    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => AppDatabase.instance.close());
  });

  testWidgets('نافذة جلسات المريض تعرض ترويسة الملف', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    final db = await _openDb(tester);
    late int patientId;
    await tester.runAsync(() async {
      patientId = await db.insert('patients', {
        'full_name': 'مريض الجلسات',
        'file_no': 'S-5',
      });
    });
    await tester.pumpWidget(_app(SessionsScreen(patientId: patientId)));
    await _settle(tester);
    expect(find.byKey(const Key('patientChartHeader')), findsOneWidget);
    expect(find.text('مريض الجلسات'), findsOneWidget);
    expect(find.text('S-5'), findsOneWidget);

    // شاشة كل الجلسات (بلا مريض محدد) لا تعرض ترويسة.
    await tester.pumpWidget(_app(const SessionsScreen(embedded: true)));
    await _settle(tester);
    expect(find.byKey(const Key('patientChartHeader')), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => AppDatabase.instance.close());
  });

  testWidgets('زر «دفع» بجانب «حفظ الزيارة» يسجّل أجر المعاينة عند الحفظ', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    final db = await _openDb(tester);
    late int patientId;
    late SessionProvider session;
    await tester.runAsync(() async {
      patientId = await db.insert('patients', {'full_name': 'مريض الدفع'});
      await ClinicFlowRepository().savePrices(
        checkup: 5000,
        sessions: {'جلسة EMS': 3000, 'جلسة سحب فقرات': 4000},
      );
      session = SessionProvider(AuthRepository());
      await session.login('doctor', '1234');
    });
    await tester.pumpWidget(
      _app(
        VisitFormScreen(patientId: patientId, patientName: 'مريض الدفع'),
        session: session,
      ),
    );
    await _settle(tester);

    final pay = find.byKey(const Key('visitFormPay'));
    expect(pay, findsOneWidget);
    // بجانب «حفظ الزيارة» وبالارتفاع نفسه.
    final save = find.ancestor(
      of: find.text('حفظ الزيارة'),
      matching: find.bySubtype<ButtonStyleButton>(),
    );
    expect(tester.getSize(save).height, AppSizes.button);
    expect(
      tester
          .getSize(
            find.descendant(of: pay, matching: find.byType(OutlinedButton)),
          )
          .height,
      AppSizes.button,
    );
    expect(
      (tester.getCenter(pay).dy - tester.getCenter(save).dy).abs(),
      lessThan(1),
    );

    await tester.tap(find.text('دفع'));
    await _settle(tester);
    expect(find.text('تم الدفع'), findsOneWidget);
    // نقرة ثانية بالخطأ: تنبيه فقط.
    await tester.tap(find.text('تم الدفع'));
    await tester.pumpAndSettle();
    expect(find.text('تنبيه: الدفع مسجّل مسبقاً'), findsOneWidget);
    await tester.tap(find.text('حسناً'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('حفظ الزيارة'));
    await _settle(tester);
    await tester.runAsync(() async {
      final payments = await db.query('payments');
      expect(payments.length, 1);
      expect(payments.single['category'], 'consultation');
      expect((payments.single['amount'] as num).toDouble(), 5000);
    });
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => AppDatabase.instance.close());
  });
}

