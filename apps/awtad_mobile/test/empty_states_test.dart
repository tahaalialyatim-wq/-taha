import 'package:awtad_mobile/presentation/screens/customers_screen.dart';
import 'package:awtad_mobile/presentation/screens/inventory_screen.dart';
import 'package:awtad_mobile/presentation/screens/sales_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'phase1_fakes.dart';

void main() {
  testWidgets('customers list shows Arabic empty state', (tester) async {
    final session = sessionWithoutSqlite();
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: CustomersScreen(session: session)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('customer-empty-state')), findsOneWidget);
    expect(find.text('لا يوجد عملاء بعد.'), findsOneWidget);
  });

  testWidgets('inventory list shows Arabic empty state', (tester) async {
    final session = sessionWithoutSqlite();
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: InventoryScreen(session: session)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('inventory-empty-state')), findsOneWidget);
    expect(find.text('لا توجد منتجات في المخزون بعد.'), findsOneWidget);
  });

  testWidgets('sales cart shows Arabic empty copy', (tester) async {
    final session = sessionWithoutSqlite();
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: SalesScreen(session: session)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sales-empty-cart')), findsOneWidget);
    expect(find.text('السلة فارغة. أضف منتجًا للبدء.'), findsOneWidget);
    expect(find.byKey(const Key('sale-total')), findsOneWidget);
    expect(find.textContaining('الإجمالي:'), findsOneWidget);
  });
}
