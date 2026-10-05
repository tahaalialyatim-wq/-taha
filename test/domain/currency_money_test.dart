import 'package:awtad_retail/awtad_retail.dart';
import 'package:test/test.dart';

void main() {
  group('CurrencyCode', () {
    test('exposes supported values', () {
      expect(CurrencyCode.values, hasLength(3));
      expect(
        CurrencyCode.values.map((c) => c.value),
        containsAll(<String>['YER', 'SAR', 'USD']),
      );
    });

    test('parsing trims and uppercases', () {
      expect(CurrencyCode.parse(' yer '), CurrencyCode.yemeniRial);
      expect(CurrencyCode.parse('sar'), CurrencyCode.saudiRiyal);
      expect(CurrencyCode.parse('Usd'), CurrencyCode.usDollar);
    });

    test('requires exactly three alphabetic characters', () {
      expect(() => CurrencyCode.parse('YE'), throwsArgumentError);
      expect(() => CurrencyCode.parse('YERR'), throwsArgumentError);
      expect(() => CurrencyCode.parse('Y3R'), throwsArgumentError);
    });

    test('rejects unsupported codes', () {
      expect(() => CurrencyCode.parse('EUR'), throwsArgumentError);
    });
  });

  group('Money', () {
    test('keeps integer minor units and explicit currency', () {
      const money = Money(currency: CurrencyCode.saudiRiyal, minorUnits: 1250);
      expect(money.minorUnits, 1250);
      expect(money.currency, CurrencyCode.saudiRiyal);
    });

    test('equality includes amount and currency', () {
      const a = Money(currency: CurrencyCode.yemeniRial, minorUnits: 100);
      const b = Money(currency: CurrencyCode.yemeniRial, minorUnits: 100);
      const differentAmount =
          Money(currency: CurrencyCode.yemeniRial, minorUnits: 200);
      const differentCurrency =
          Money(currency: CurrencyCode.usDollar, minorUnits: 100);
      expect(a, b);
      expect(a == differentAmount, isFalse);
      expect(a == differentCurrency, isFalse);
      expect(a.hashCode, b.hashCode);
    });
  });
}
