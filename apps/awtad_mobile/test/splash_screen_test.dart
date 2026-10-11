import 'package:awtad_mobile/presentation/screens/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('splash shows Arabic brand copy', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: SplashScreen(),
        ),
      ),
    );
    expect(find.text('الأوتاد'), findsOneWidget);
    expect(find.text('للمبيعات'), findsOneWidget);
    expect(find.text('AWTAD RETAIL'), findsOneWidget);
  });

  testWidgets('database failure offers retry', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      MaterialApp(
        home: DatabaseFailureScreen(onRetry: () => retried = true),
      ),
    );
    await tester.tap(find.text('إعادة المحاولة'));
    expect(retried, isTrue);
  });
}
