import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:neuro_clinic/core/theme/app_colors.dart';
import 'package:neuro_clinic/core/theme/app_theme.dart';
import 'package:neuro_clinic/core/widgets/clinic_brand.dart';
import 'package:neuro_clinic/core/widgets/patient_autocomplete.dart';
import 'package:neuro_clinic/core/widgets/search_field.dart';
import 'package:neuro_clinic/data/models/patient.dart';

const _patients = [
  Patient(id: 1, fileNo: 'A-101', fullName: 'أحمد سالم', phone: '0999000111'),
  Patient(id: 2, fileNo: 'B-7', fullName: 'منى خالد', phone: '0933222444'),
  Patient(id: 3, fullName: 'سامر يوسف'),
];

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.light(),
  home: Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      body: Padding(padding: const EdgeInsets.all(20), child: child),
    ),
  ),
);

void main() {
  test('اسم العيادة على سطرين: بعد الكلمة الأولى أو عند فاصل السطر', () {
    expect(
      clinicNameTwoLines('عيادة الدكتور طارق نجم مقلد'),
      'عيادة\nالدكتور طارق نجم مقلد',
    );
    expect(clinicNameTwoLines('عيادة الدكتور\nطارق'), 'عيادة الدكتور\nطارق');
    expect(clinicNameTwoLines('عيادة'), 'عيادة');
    expect(clinicNameOneLine('عيادة\n الدكتور'), 'عيادة الدكتور');
  });

  test('بحث المريض بالاسم أو رقم الملف أو الهاتف', () {
    bool m(int i, String q) => PatientAutocomplete.matches(_patients[i], q);
    expect(m(0, 'أحمد'), isTrue);
    expect(m(0, 'a-101'), isTrue);
    expect(m(1, '0933'), isTrue);
    expect(m(1, 'منى خالد'), isTrue);
    expect(m(2, 'أحمد'), isFalse);
    expect(m(2, ''), isTrue);
  });

  testWidgets('الإكمال التلقائي يعرض الاقتراحات ويختار المريض', (tester) async {
    Patient? picked;
    await tester.pumpWidget(
      _wrap(
        PatientAutocomplete(patients: _patients, onSelected: (p) => picked = p),
      ),
    );
    await tester.enterText(find.byKey(const Key('patientAutocomplete')), 'من');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('patientOption:2')), findsOneWidget);
    expect(find.byKey(const Key('patientOption:1')), findsNothing);
    await tester.tap(find.byKey(const Key('patientOption:2')));
    await tester.pumpAndSettle();
    expect(picked?.id, 2);
    expect(find.text('منى خالد'), findsOneWidget);
    // تعديل النص بعد الاختيار يلغي الاختيار.
    await tester.enterText(find.byKey(const Key('patientAutocomplete')), 'م');
    await tester.pumpAndSettle();
    expect(picked, isNull);
  });

  testWidgets('مربع البحث المميز: كبسولة بحافة كحلية وأيقونة داخل دائرة', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(AppSearchField(controller: TextEditingController(), hint: 'بحث')),
    );
    expect(find.byKey(const Key('searchIconChip')), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField));
    final border = field.decoration!.enabledBorder! as OutlineInputBorder;
    expect(border.borderRadius.topLeft.x, greaterThanOrEqualTo(20));
    expect(border.borderSide.width, greaterThanOrEqualTo(1.4));
  });

  test('حقول الإدخال بحافة واضحة والنوافذ بخلفية بيضاء', () {
    final theme = AppTheme.light();
    final enabled =
        theme.inputDecorationTheme.enabledBorder! as OutlineInputBorder;
    expect(enabled.borderSide.color, AppColors.fieldBorder);
    expect(enabled.borderSide.width, greaterThanOrEqualTo(1.2));
    expect(theme.dialogTheme.backgroundColor, Colors.white);
    expect(theme.dialogTheme.surfaceTintColor, Colors.transparent);
  });
}
