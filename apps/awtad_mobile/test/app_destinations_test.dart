import 'package:awtad_mobile/presentation/navigation/app_destinations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('primary destinations remain six Arabic tabs', () {
    expect(AppDestination.primary, hasLength(6));
    expect(
      AppDestination.primary.map((d) => d.labelAr).toList(),
      <String>[
        'الرئيسية',
        'المبيعات',
        'المخزون',
        'العملاء',
        'الديون',
        'التقارير',
      ],
    );
  });
}
