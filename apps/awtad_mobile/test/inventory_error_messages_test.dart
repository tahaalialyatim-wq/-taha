import 'package:awtad_mobile/core/database/database_init_exception.dart';
import 'package:awtad_mobile/presentation/screens/inventory_screen.dart';
import 'package:awtad_mobile/presentation/utils/inventory_save_error_message.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'phase1_fakes.dart';

const _price = 'تحقق من السعر والعملة. لا يسمح بأسعار سالبة.';
const _storage = 'تعذر حفظ المنتج في قاعدة البيانات. حاول مرة أخرى.';
const _fallback = 'حدث خطأ غير متوقع. حاول مرة أخرى.';

void main() {
  test('price and currency errors map to Arabic price feedback', () {
    final typed = ArgumentError.value(-1, 'sellingPrice', 'Price must not be negative');
    final fromMessage = Exception('negative currency price rejected');
    for (final error in <Object>[typed, fromMessage]) {
      final message = inventorySaveErrorMessage(error);
      expect(message, _price);
      expect(message, isNot(error.toString()));
    }
  });

  test('storage-like inventory errors map to Arabic storage feedback', () {
    final typed = DatabaseInitException('failed to open sqlite file');
    final fromMessage = Exception('database write failed');
    for (final error in <Object>[typed, fromMessage]) {
      final message = inventorySaveErrorMessage(error);
      expect(message, _storage);
      expect(message, isNot(error.toString()));
    }
  });

  test('unknown inventory errors map to Arabic fallback and never leak toString',
      () {
    const error = 'totally-unknown-failure-xyz';
    final message = inventorySaveErrorMessage(error);
    expect(message, _fallback);
    expect(message, isNot(error.toString()));
  });

  testWidgets('inventory screen shows Arabic price feedback on save failure',
      (tester) async {
    await _pumpSaveFailure(
      tester,
      ArgumentError.value(-1, 'sellingPrice', 'Price must not be negative'),
    );
    expect(find.text(_price), findsOneWidget);
    expect(find.textContaining('ArgumentError'), findsNothing);
  });

  testWidgets('inventory screen shows Arabic storage feedback', (tester) async {
    await _pumpSaveFailure(
      tester,
      Exception('sqlite constraint failed'),
    );
    expect(find.text(_storage), findsOneWidget);
  });

  testWidgets('inventory screen shows Arabic fallback and hides toString',
      (tester) async {
    const error = 'totally-unknown-failure-xyz';
    await _pumpSaveFailure(tester, error);
    expect(find.text(_fallback), findsOneWidget);
    expect(find.text(error), findsNothing);
  });
}

Future<void> _pumpSaveFailure(WidgetTester tester, Object error) async {
  final inventory = FakeInventoryRepository(addError: error);
  final session = sessionWithoutSqlite(inventory: inventory);
  await tester.pumpWidget(
    MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: InventoryScreen(session: session)),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('product-field')), 'p1');
  await tester.tap(find.byKey(const Key('save-button')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('inventory-save-message')), findsOneWidget);
}
