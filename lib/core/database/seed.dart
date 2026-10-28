import 'package:flutter/foundation.dart' show debugPrint;

import 'dart:math';

import 'package:bcrypt/bcrypt.dart';
import 'package:sqflite/sqflite.dart';

/// ============================================================================
///  البيانات الأولية عند أول تشغيل
/// ----------------------------------------------------------------------------
///  • يُنشأ حساب مدير افتراضي (admin / 1234) — غيّر كلمة المرور فوراً.
///  • يُنشأ صف إعدادات العيادة الافتراضي.
/// ============================================================================
Future<void> seedInitialData(Database db) async {
  final now = DateTime.now().toIso8601String();

  await db.insert('users', {
    'username': 'admin',
    'password_hash': BCrypt.hashpw('1234', BCrypt.gensalt()),
    'full_name': 'المدير',
    'role': 'admin',
    'is_active': 1,
    'created_at': now,
  });

  await db.insert('clinic_settings', {
    'id': 1,
    'clinic_name': 'عيادة الأعصاب',
    'doctor_name': '',
    'specialty': 'طب الأعصاب',
    'phone': '',
    'address': '',
    'default_fee': 0,
    'visit_duration': 20,
    'footer_note': 'نسخة تجريبية',
  });
}

/// ============================================================================
///  بيانات تجريبية اختيارية — استدعها من شاشة الإعدادات لتجربة الواجهة
///  بسرعة. لا تُستدعى تلقائياً أبداً.
/// ============================================================================
Future<void> seedDemoData(Database db) async {
  final rnd = Random(42);
  final now = DateTime.now();

  const firstNames = [
    'أحمد',
    'محمد',
    'فاطمة',
    'سارة',
    'علي',
    'نور',
    'يوسف',
    'مريم',
  ];
  const lastNames = ['الحسن', 'العلي', 'المصري', 'الخطيب', 'الشامي', 'الزيدي'];
  const complaints = [
    'صداع متكرر منذ شهرين',
    'دوار وعدم اتزان',
    'تنميل في الأطراف السفلية',
    'نوبات تشنج',
    'ضعف في اليد اليمنى',
    'رعاش في اليدين',
    'نسيان متكرر',
    'ألم في أسفل الظهر يمتد للساق',
  ];
  const diagnoses = [
    'G43.9 صداع نصفي',
    'G40.9 صرع',
    'G62.9 اعتلال عصبي محيطي',
    'G20 مرض باركنسون',
    'G35 تصلب متعدد',
    'G45 نوبة إقفارية عابرة',
  ];

  for (var i = 0; i < 24; i++) {
    final name =
        '${firstNames[rnd.nextInt(firstNames.length)]} '
        '${lastNames[rnd.nextInt(lastNames.length)]}';
    final patientId = await db.insert('patients', {
      'file_no': 'P-${(1001 + i)}',
      'full_name': name,
      'gender': rnd.nextBool() ? 'm' : 'f',
      'birth_date': DateTime(
        1955 + rnd.nextInt(45),
        1 + rnd.nextInt(12),
        1 + rnd.nextInt(28),
      ).toIso8601String().substring(0, 10),
      'phone': '09${rnd.nextInt(90000000) + 10000000}',
      'address': 'دمشق',
      'is_active': 1,
      'created_at': now.toIso8601String(),
    });

    final visitsCount = 1 + rnd.nextInt(3);
    for (var v = 0; v < visitsCount; v++) {
      final visitDate = now.subtract(Duration(days: rnd.nextInt(180)));
      final diagnosis = diagnoses[rnd.nextInt(diagnoses.length)];
      final visitId = await db.insert('visits', {
        'patient_id': patientId,
        'visit_date': visitDate.toIso8601String().substring(0, 10),
        'visit_type': v == 0 ? 'new' : 'followup',
        'chief_complaint': complaints[rnd.nextInt(complaints.length)],
        'diagnosis': diagnosis.split(' ').skip(1).join(' '),
        'icd10': diagnosis.split(' ').first,
        'plan': 'متابعة بعد شهر',
        'followup_in_days': 30,
        'created_at': visitDate.toIso8601String(),
      });
      await db.insert('payments', {
        'patient_id': patientId,
        'visit_id': visitId,
        'amount': (20 + rnd.nextInt(80)) * 1000,
        'method': 'cash',
        'paid_at': visitDate.toIso8601String(),
      });
    }
  }

  // مواعيد اليوم
  final patients = await db.query('patients', limit: 8);
  for (var i = 0; i < patients.length; i++) {
    final start = DateTime(
      now.year,
      now.month,
      now.day,
      9 + i,
      [0, 30][rnd.nextInt(2)],
    );
    await db.insert('appointments', {
      'patient_id': patients[i]['id'],
      'start_at': start.toIso8601String(),
      'duration_min': 20,
      'status': 'scheduled',
      'created_at': now.toIso8601String(),
    });
  }
  debugPrint('✅ تم إدراج بيانات تجريبية');
}

