import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:neuro_clinic/core/database/app_database.dart';
import 'package:neuro_clinic/core/database/schema.dart';
import 'package:neuro_clinic/core/database/seed.dart';
import 'package:neuro_clinic/core/theme/app_theme.dart';
import 'package:neuro_clinic/core/widgets/attachment_picker.dart';
import 'package:neuro_clinic/core/widgets/attachment_viewer.dart';
import 'package:neuro_clinic/features/investigations/investigations_screen.dart';

/// صورة PNG صغيرة (1×1) صالحة.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

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
    final dir = await Directory.systemTemp.createTemp('v10-');
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
    'المرفقات: زر معاينة + اختيار المرفق بالدائرة أو بالضغط + معاينة/تحميل/إلغاء',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      final db = await _openDb(tester);
      final today = DateTime.now().toIso8601String().substring(0, 10);
      late int patientId, none, one, two;
      late Directory out;
      await tester.runAsync(() async {
        out = await Directory.systemTemp.createTemp('v10-out-');
        patientId = await db.insert('patients', {
          'full_name': 'مريض المرفقات',
          'file_no': 'M-1',
        });
        Future<int> inv(String kind) => db.insert('investigations', {
          'patient_id': patientId,
          'kind': kind,
          'performed_on': today,
          'workflow_status': 'received',
        });
        none = await inv('فحص بلا مرفق');
        one = await inv('فحص بمرفق واحد');
        two = await inv('فحص بمرفقين');
        await db.insert('investigation_attachments', {
          'investigation_id': one,
          'name': 'single.png',
          'bytes': _png,
        });
        for (final n in ['report.pdf', 'mri-1.png']) {
          await db.insert('investigation_attachments', {
            'investigation_id': two,
            'name': n,
            'bytes': n.endsWith('.pdf') ? utf8.encode('%PDF-fake') : _png,
          });
        }
      });
      var asked = <String>[];
      AttachmentPicker.pickSaveTarget = (name) async {
        asked.add(name);
        return '${out.path}/saved-copy'; // بلا امتداد: يُضاف تلقائياً
      };
      addTearDown(() => AttachmentPicker.pickSaveTarget = (_) async => null);

      await tester.pumpWidget(_app(InvestigationsScreen(patientId: patientId)));
      await _settle(tester);

      // فحص بلا مرفقات: لا زر معاينة.
      expect(find.byKey(Key('invCardPreview$none')), findsNothing);
      expect(find.text('بدون مرفقات'), findsOneWidget);
      expect(find.text('المرفقات (1)'), findsOneWidget);
      expect(find.text('المرفقات (2)'), findsOneWidget);

      // مرفق واحد: «معاينة المرفق» تفتح المعاينة مباشرة.
      await tester.tap(find.byKey(Key('invCardPreview$one')));
      await _settle(tester);
      expect(find.byKey(const Key('attachmentPicker')), findsNothing);
      expect(find.byType(AttachmentViewer), findsOneWidget);
      Navigator.of(tester.element(find.byType(AttachmentViewer))).pop();
      await _settle(tester);

      // مرفقان: تظهر قائمة الاختيار.
      await tester.ensureVisible(find.byKey(Key('invCardPreview$two')));
      await tester.tap(find.byKey(Key('invCardPreview$two')));
      await _settle(tester);
      expect(find.byKey(const Key('attachmentPicker')), findsOneWidget);
      expect(find.text('المرفقات (2)'), findsWidgets);
      expect(find.byKey(const Key('attRow0')), findsOneWidget);
      expect(find.byKey(const Key('attRow1')), findsOneWidget);
      for (final k in ['attPreview', 'attDownload', 'attCancel']) {
        expect(find.byKey(Key(k)), findsOneWidget, reason: k);
      }

      // التحديد بالدائرة ثم «معاينة المرفق» يفتح المرفق المختار.
      await tester.tap(find.byKey(const Key('attRadio1')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('attPreview')));
      await tester.pump();
      expect(
        tester.widget<AttachmentViewer>(find.byType(AttachmentViewer)).initial,
        1,
      );
      Navigator.of(tester.element(find.byType(AttachmentViewer))).pop();
      await tester.pumpAndSettle();

      // الضغط على اسم المرفق يُظهر: معاينة / تحميل / إلغاء.
      await tester.tap(find.text('mri-1.png'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('attOptions')), findsOneWidget);
      for (final k in ['attOptPreview', 'attOptDownload', 'attOptCancel']) {
        expect(find.byKey(Key(k)), findsOneWidget, reason: k);
      }
      // إلغاء: تُغلق الخيارات وتبقى القائمة.
      await tester.tap(find.byKey(const Key('attOptCancel')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('attOptions')), findsNothing);
      expect(find.byKey(const Key('attachmentPicker')), findsOneWidget);

      // معاينة من الخيارات.
      await tester.tap(find.text('mri-1.png'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('attOptPreview')));
      await tester.pump();
      expect(
        tester.widget<AttachmentViewer>(find.byType(AttachmentViewer)).initial,
        1,
      );
      Navigator.of(tester.element(find.byType(AttachmentViewer))).pop();
      await tester.pumpAndSettle();

      // تحميل من الخيارات: يُحفظ الملف نفسه بامتداده.
      // ملفات حقيقية: تُنفَّذ الخطوات بالوقت الحقيقي لا الوهمي.
      await tester.runAsync(() async {
        await tester.tap(find.text('mri-1.png'));
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        await tester.tap(find.byKey(const Key('attOptDownload')));
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 100));
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
      });
      await _settle(tester);
      expect(asked, ['mri-1.png']);
      final saved = File('${out.path}/saved-copy.png');
      expect(await tester.runAsync(saved.exists), isTrue);
      expect(await tester.runAsync(saved.readAsBytes), _png);
      expect(find.byKey(const Key('attMessage')), findsOneWidget);
      expect(find.textContaining('تم تحميل المرفق'), findsOneWidget);

      // زر «تحميل المرفق» في الأسفل يحمّل المحدد (PDF).
      asked = [];
      await tester.tap(find.byKey(const Key('attRadio0')));
      await tester.pump();
      // ملفات حقيقية: يجب أن يبدأ الحفظ خارج الوقت الوهمي.
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('attDownload')));
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 100));
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
      });
      await _settle(tester);
      expect(asked, ['report.pdf']);
      expect(
        await tester.runAsync(File('${out.path}/saved-copy.pdf').exists),
        isTrue,
      );

      // «إلغاء» يغلق القائمة.
      await tester.tap(find.byKey(const Key('attCancel')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('attachmentPicker')), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() => AppDatabase.instance.close());
    },
  );

  testWidgets('وثيقة الفحص: معاينة عدة مرفقات تُظهر قائمة الاختيار', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    final db = await _openDb(tester);
    late int patientId;
    await tester.runAsync(() async {
      patientId = await db.insert('patients', {'full_name': 'م'});
      final id = await db.insert('investigations', {
        'patient_id': patientId,
        'kind': 'أشعة',
        'performed_on': DateTime.now().toIso8601String().substring(0, 10),
        'workflow_status': 'received',
      });
      for (final n in ['a.png', 'b.png']) {
        await db.insert('investigation_attachments', {
          'investigation_id': id,
          'name': n,
          'bytes': _png,
        });
      }
    });
    await tester.pumpWidget(_app(InvestigationsScreen(patientId: patientId)));
    await _settle(tester);
    await tester.tap(find.text('فتح / تعديل'));
    await _settle(tester);
    await tester.tap(find.byKey(const Key('invPreview')));
    await _settle(tester);
    expect(find.byKey(const Key('attachmentPicker')), findsOneWidget);
    expect(find.text('a.png'), findsWidgets);
    expect(find.text('b.png'), findsWidgets);
    await tester.tap(find.byKey(const Key('attCancel')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('invCancel')));
    await _settle(tester);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => AppDatabase.instance.close());
  });
}

