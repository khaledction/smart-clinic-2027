import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neuro_clinic/core/theme/app_colors.dart';
import 'package:neuro_clinic/core/widgets/paid_widgets.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: Center(child: child)),
      ),
    ),
  );

  Color? background(WidgetTester tester) {
    final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
    return button.style?.backgroundColor?.resolve({});
  }

  testWidgets('دفع: أبيض بإطار أخضر ثم أخضر كامل بعد النقر', (tester) async {
    var calls = 0;
    await pump(
      tester,
      PayToggle(
        paid: false,
        onPay: () async {
          calls++;
          return true;
        },
      ),
    );
    expect(find.text('دفع'), findsOneWidget);
    expect(background(tester), Colors.white);

    await tester.tap(find.text('دفع'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.text('تم الدفع'), findsOneWidget);
    expect(background(tester), AppColors.paid);

    // النقرة الثانية بالخطأ: تنبيه ولا دفعة ثانية.
    await tester.tap(find.text('تم الدفع'));
    await tester.pumpAndSettle();
    expect(find.text('تنبيه: الدفع مسجّل مسبقاً'), findsOneWidget);
    await tester.tap(find.text('حسناً'));
    await tester.pumpAndSettle();
    expect(calls, 1);
  });

  testWidgets('نقر مزدوج سريع أثناء التسجيل لا يكرر الدفع', (tester) async {
    var calls = 0;
    await pump(
      tester,
      PayToggle(
        paid: false,
        onPay: () async {
          calls++;
          await Future<void>.delayed(const Duration(milliseconds: 300));
          return true;
        },
      ),
    );
    await tester.tap(find.text('دفع'));
    await tester.pump();
    await tester.tap(find.byType(OutlinedButton));
    await tester.pump();
    expect(find.text('تنبيه: الدفع مسجّل مسبقاً'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('حسناً'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.text('تم الدفع'), findsOneWidget);
  });

  testWidgets('فشل التسجيل (سعر غير محدد) يبقي الزر أبيض', (tester) async {
    await pump(tester, PayToggle(paid: false, onPay: () async => false));
    await tester.tap(find.text('دفع'));
    await tester.pumpAndSettle();
    expect(find.text('دفع'), findsOneWidget);
    expect(background(tester), Colors.white);
  });

  testWidgets('دفعة مسجلة مسبقاً تظهر خضراء وتنبّه عند النقر', (tester) async {
    var calls = 0;
    await pump(
      tester,
      PayToggle(
        paid: true,
        paidLabel: 'مدفوع 5000',
        onPay: () async {
          calls++;
          return true;
        },
      ),
    );
    expect(find.text('مدفوع 5000'), findsOneWidget);
    expect(background(tester), AppColors.paid);
    await tester.tap(find.text('مدفوع 5000'));
    await tester.pumpAndSettle();
    expect(find.text('تنبيه: الدفع مسجّل مسبقاً'), findsOneWidget);
    expect(calls, 0);
  });
}
