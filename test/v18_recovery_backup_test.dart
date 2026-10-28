import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:neuro_clinic/core/database/app_database.dart';
import 'package:neuro_clinic/core/database/schema.dart';
import 'package:neuro_clinic/core/database/seed.dart';
import 'package:neuro_clinic/core/services/app_folders.dart';
import 'package:neuro_clinic/core/services/auto_backup.dart';
import 'package:neuro_clinic/core/services/developer_mode.dart';
import 'package:neuro_clinic/core/services/password_recovery.dart';
import 'package:neuro_clinic/core/theme/app_theme.dart';
import 'package:neuro_clinic/data/repositories/app_prefs_repository.dart';
import 'package:neuro_clinic/data/repositories/auth_repository.dart';
import 'package:neuro_clinic/features/login/forgot_password_dialog.dart';

Future<Directory> _openTempDb() async {
  sqfliteFfiInit();
  final dir = await Directory.systemTemp.createTemp('v18-');
  final db = await databaseFactoryFfiNoIsolate.openDatabase('${dir.path}/t.db');
  await enableForeignKeys(db);
  await createSchema(db);
  await seedInitialData(db);
  AppDatabase.instance.useTestDatabase(db);
  AppPrefsRepository.directory = () async => dir;
  return dir;
}

const _configured = AppPrefs(
  recoveryEmail: 'doctor@gmail.com',
  recoveryWhatsapp: '0944123456',
);

String _codeFrom(String body) => RegExp(r'\d{6}').firstMatch(body)!.group(0)!;

void main() {
  tearDown(() {
    PasswordRecovery.clear();
    PasswordRecovery.now = DateTime.now;
    AutoBackup.now = DateTime.now;
  });

  group('استعادة كلمة المرور', () {
    test('الرمز عبر برنامج البريد (mailto) ثم كلمة مرور جديدة تعمل', () async {
      await _openTempDb();
      await AppPrefsRepository().save(_configured);
      String? body;
      PasswordRecovery.openUri = (u) async =>
          body = Uri.decodeComponent(u.toString());
      final r = PasswordRecovery();
      await r.sendCode('admin', RecoveryChannel.email);
      expect(body, startsWith('mailto:doctor@gmail.com?subject='));
      final code = _codeFrom(body!);
      expect(body, contains('admin'));
      await expectLater(
        r.reset('admin', code == '000000' ? '111111' : '000000', 'new-pass'),
        throwsA(isA<StateError>()),
      );
      await r.reset('admin', code, 'new-pass');
      final auth = AuthRepository();
      expect(await auth.login('admin', 'new-pass'), isNotNull);
      expect(await auth.login('admin', '1234'), isNull);
      // الرمز يُستخدم مرة واحدة فقط.
      await expectLater(
        r.reset('admin', code, 'again'),
        throwsA(isA<StateError>()),
      );
    });

    test('واتساب يفتح wa.me بالرقم الدولي والرمز', () async {
      await _openTempDb();
      await AppPrefsRepository().save(_configured);
      Uri? opened;
      PasswordRecovery.openUri = (u) async => opened = u;
      await PasswordRecovery().sendCode('admin', RecoveryChannel.whatsapp);
      expect(opened!.host, 'wa.me');
      expect(opened!.path, '/963944123456');
      expect(opened!.queryParameters['text'], matches(RegExp(r'\d{6}')));
    });

    test('انتهاء الصلاحية والمحاولات الخاطئة ومستخدم غير موجود', () async {
      await _openTempDb();
      await AppPrefsRepository().save(_configured);
      String? body;
      PasswordRecovery.openUri = (u) async =>
          body = Uri.decodeComponent(u.toString());
      final r = PasswordRecovery();
      await expectLater(
        r.sendCode('nobody', RecoveryChannel.email),
        throwsA(isA<StateError>()),
      );
      var t = DateTime(2026, 9, 28, 10);
      PasswordRecovery.now = () => t;
      await r.sendCode('admin', RecoveryChannel.email);
      t = t.add(const Duration(minutes: 16));
      await expectLater(
        r.reset('admin', _codeFrom(body!), 'x1234'),
        throwsA(
          isA<StateError>().having((e) => e.message, 'm', contains('انتهت')),
        ),
      );
      t = DateTime(2026, 9, 28, 11);
      await r.sendCode('admin', RecoveryChannel.email);
      final good = _codeFrom(body!);
      final bad = good == '999999' ? '888888' : '999999';
      for (var i = 0; i < PasswordRecovery.maxAttempts; i++) {
        await expectLater(
          r.reset('admin', bad, 'x1234'),
          throwsA(isA<StateError>()),
        );
      }
      // بعد 5 محاولات خاطئة يُلغى الرمز حتى الصحيح.
      await expectLater(
        r.reset('admin', good, 'x1234'),
        throwsA(isA<StateError>()),
      );
    });

    test('بدون إعدادات: رسالة توجّه إلى الإعدادات', () async {
      await _openTempDb();
      await expectLater(
        PasswordRecovery().sendCode('admin', RecoveryChannel.email),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'm',
            contains('الإعدادات'),
          ),
        ),
      );
    });

    test('كلمة مرور جديدة أقصر من 8 أحرف مرفوضة', () async {
      await _openTempDb();
      await AppPrefsRepository().save(_configured);
      String? body;
      PasswordRecovery.openUri = (u) async =>
          body = Uri.decodeComponent(u.toString());
      final r = PasswordRecovery();
      await r.sendCode('admin', RecoveryChannel.email);
      await expectLater(
        r.reset('admin', _codeFrom(body!), 'short'),
        throwsA(isA<StateError>().having((e) => e.message, 'm', contains('8'))),
      );
    });

    test('البريد اختياري: واتساب وحده يكفي', () async {
      await _openTempDb();
      await AppPrefsRepository().save(
        const AppPrefs(recoveryWhatsapp: '0944123456'),
      );
      final p = await AppPrefsRepository().load();
      expect(p.canEmail, isFalse);
      expect(p.canWhatsapp, isTrue);
      await expectLater(
        PasswordRecovery().sendCode('admin', RecoveryChannel.email),
        throwsA(isA<StateError>()),
      );
    });

    test('إخفاء البريد والرقم وتحويل الرقم للصيغة الدولية', () {
      expect(PasswordRecovery.maskEmail('doctor@gmail.com'), 'do***@gmail.com');
      expect(PasswordRecovery.maskPhone('0944123456'), '…456');
      expect(
        PasswordRecovery.normalizePhone('+963 944-123-456'),
        '963944123456',
      );
      expect(PasswordRecovery.normalizePhone('00963944123456'), '963944123456');
    });
  });

  group('وضع المبرمج ومجلد البرنامج', () {
    test('بيانات العيادة تُفتح فقط بحساب المبرمج', () {
      DeveloperMode.lock();
      expect(DeveloperMode.tryLogin('khaled.a.f', '1234'), isNull);
      expect(DeveloperMode.tryLogin('admin', '@kh@12345678'), isNull);
      expect(DeveloperMode.unlocked.value, isFalse);
      expect(DeveloperMode.tryLogin('khaled.a.f', '@kh@12345678'), isNotNull);
      expect(DeveloperMode.unlocked.value, isTrue);
      DeveloperMode.lock();
      expect(DeveloperMode.unlocked.value, isFalse);
    });

    test('النسخ التلقائي داخل مجلد البرنامج myclinic/backups', () async {
      final root = await Directory.systemTemp.createTemp('v19-root-');
      AppFolders.overrideRoot = root.path;
      addTearDown(() => AppFolders.overrideRoot = null);
      expect(AppFolders.windowsRoot, r'D:\myclinic');
      final b = await AppFolders.backups();
      expect(b.existsSync(), isTrue);
      expect(b.path, '${root.path}${Platform.pathSeparator}backups');
    });
  });

  group('النسخ التلقائي', () {
    test('نسخة واحدة يومياً + 30 يومية + 12 شهرية + مجلد ثانٍ', () async {
      final base = await Directory.systemTemp.createTemp('v18-bk-');
      final second = await Directory.systemTemp.createTemp('v18-bk2-');
      AppPrefsRepository.directory = () async => base;
      AutoBackup.baseDirectory = () async => base;
      var writes = 0;
      AutoBackup.writeBackup = (target) async {
        writes++;
        await File(target).writeAsString('db $writes');
      };
      await AppPrefsRepository().save(AppPrefs(backupDir2: second.path));
      var day = DateTime(2025, 1, 1, 9);
      AutoBackup.now = () => day;

      final first = await AutoBackup.runIfDue();
      expect(first, isNotNull);
      expect(first!.secondCopy, isNotNull);
      // التشغيل الثاني في اليوم نفسه لا ينشئ نسخة جديدة.
      expect(await AutoBackup.runIfDue(), isNull);
      expect(writes, 1);

      for (var i = 1; i < 420; i++) {
        day = DateTime(2025, 1, 1, 9).add(Duration(days: i));
        await AutoBackup.runIfDue();
      }
      final dir = await AutoBackup.folder();
      List<String> names(String sub) =>
          Directory('${dir.path}/$sub')
              .listSync()
              .map((e) => e.path.split(Platform.pathSeparator).last)
              .toList()
            ..sort();
      expect(names('daily').length, AutoBackup.keepDaily);
      expect(names('daily').last, AutoBackup.dailyName(day));
      expect(names('monthly').length, AutoBackup.keepMonthly);
      expect(second.listSync().length, AutoBackup.keepDaily);
      final prefs = await AppPrefsRepository().load();
      expect(prefs.lastAutoBackup, day);
    });

    test('إيقاف النسخ التلقائي يمنعه، و«نسخ الآن» يعمل دائماً', () async {
      final base = await Directory.systemTemp.createTemp('v18-bk-');
      AppPrefsRepository.directory = () async => base;
      AutoBackup.baseDirectory = () async => base;
      AutoBackup.writeBackup = (t) => File(t).writeAsString('x');
      await AppPrefsRepository().save(const AppPrefs(autoBackup: false));
      expect(await AutoBackup.runIfDue(), isNull);
      expect(await AutoBackup.runIfDue(force: true), isNotNull);
    });

    test('مجلد ثانٍ غير متاح لا يُفشل النسخة الأساسية', () async {
      final base = await Directory.systemTemp.createTemp('v18-bk-');
      AppPrefsRepository.directory = () async => base;
      AutoBackup.baseDirectory = () async => base;
      AutoBackup.writeBackup = (t) => File(t).writeAsString('x');
      await AppPrefsRepository().save(
        AppPrefs(backupDir2: '${base.path}/missing-usb'),
      );
      final r = await AutoBackup.runIfDue();
      expect(File(r!.path).existsSync(), isTrue);
      expect(r.secondError, isNotNull);
    });

    test('نسخة حقيقية من قاعدة البيانات (VACUUM INTO)', () async {
      final dir = await _openTempDb();
      AutoBackup.baseDirectory = () async => dir;
      AutoBackup.writeBackup = AppDatabase.instance.backupTo;
      final r = await AutoBackup.runIfDue(force: true);
      final copy = await databaseFactoryFfiNoIsolate.openDatabase(r!.path);
      final users = await copy.query('users');
      expect(users, isNotEmpty);
      await copy.close();
    });
  });

  testWidgets('نافذة «نسيت كلمة المرور»: إرسال بالبريد ثم تغيير الكلمة', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await _openTempDb();
      await AppPrefsRepository().save(_configured);
    });
    String? body;
    PasswordRecovery.openUri = (u) async =>
        body = Uri.decodeComponent(u.toString());
    String? result = 'none';
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () async =>
                      result = await ForgotPasswordDialog.show(context),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    Future<void> settle() async {
      for (var i = 0; i < 4; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 150)),
        );
        await tester.pump(const Duration(milliseconds: 200));
      }
    }

    await tester.tap(find.text('open'));
    await settle();
    expect(find.text('نسيت كلمة المرور'), findsOneWidget);
    expect(find.textContaining('do***@gmail.com'), findsOneWidget);
    expect(find.textContaining('…456'), findsOneWidget);
    await tester.tap(find.byKey(const Key('forgotByEmail')));
    await settle();
    expect(find.byKey(const Key('forgotCode')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('forgotCode')),
      _codeFrom(body!),
    );
    await tester.enterText(find.byKey(const Key('forgotPass')), 'abcd9xyz');
    await tester.enterText(find.byKey(const Key('forgotPass2')), 'abcd9xyz');
    await tester.tap(find.byKey(const Key('forgotReset')));
    await settle();
    expect(result, 'admin');
    final ok = await tester.runAsync(
      () => AuthRepository().login('admin', 'abcd9xyz'),
    );
    expect(ok, isNotNull);
    await tester.runAsync(() => AppDatabase.instance.close());
  });
}

