import 'package:awtad_retail/awtad_retail.dart';
import 'package:test/test.dart';

void main() {
  const yer = Money(currency: CurrencyCode.yemeniRial, minorUnits: 1000);
  const sar = Money(currency: CurrencyCode.saudiRiyal, minorUnits: 1000);

  SaleLine line({
    String product = 'p1',
    Quantity? quantity,
    Money? unitSellingPrice,
  }) =>
      SaleLine(
        productId: ProductId(product),
        quantity: quantity ?? Quantity.whole(1),
        unitSellingPrice: unitSellingPrice ?? yer,
      );

  group('SaleId', () {
    test('rejects empty and whitespace-only values', () {
      expect(() => SaleId(''), throwsArgumentError);
      expect(() => SaleId('   '), throwsArgumentError);
    });

    test('trims correctly', () {
      expect(SaleId('  s1 ').value, 's1');
    });

    test('has value equality', () {
      expect(SaleId('s1'), SaleId('s1'));
      expect(SaleId('s1').hashCode, SaleId('s1').hashCode);
      expect(SaleId('s1') == SaleId('s2'), isFalse);
    });
  });

  group('SaleLine', () {
    test('rejects zero quantity', () {
      expect(
        () => line(quantity: Quantity.zero),
        throwsArgumentError,
      );
    });

    test('rejects negative quantity', () {
      expect(() => Quantity.fromMilliUnits(-1), throwsArgumentError);
    });

    test('calculates lineTotal correctly', () {
      final saleLine = line(
        quantity: Quantity.whole(3),
        unitSellingPrice: const Money(
          currency: CurrencyCode.yemeniRial,
          minorUnits: 250,
        ),
      );
      expect(
        saleLine.lineTotal,
        const Money(currency: CurrencyCode.yemeniRial, minorUnits: 750),
      );
    });

    test('fractional quantity calculates using milliUnits', () {
      final saleLine = line(
        quantity: Quantity.fromMilliUnits(1500),
        unitSellingPrice: const Money(
          currency: CurrencyCode.yemeniRial,
          minorUnits: 200,
        ),
      );
      expect(
        saleLine.lineTotal,
        const Money(currency: CurrencyCode.yemeniRial, minorUnits: 300),
      );
    });

    test('money multiplication uses integer minorUnits only', () {
      final saleLine = line(
        quantity: Quantity.fromMilliUnits(750),
        unitSellingPrice: const Money(
          currency: CurrencyCode.yemeniRial,
          minorUnits: 333,
        ),
      );
      expect(saleLine.lineTotal.minorUnits, (333 * 750) ~/ Quantity.scale);
      expect(saleLine.lineTotal.minorUnits, isA<int>());
    });

    test('preserves currency on lineTotal', () {
      final saleLine = line(unitSellingPrice: sar);
      expect(saleLine.lineTotal.currency, CurrencyCode.saudiRiyal);
      expect(saleLine.unitSellingPrice.currency, CurrencyCode.saudiRiyal);
    });
  });

  group('SaleLine historical cost', () {
    SaleLine costed({
      required Money selling,
      required Money? cost,
      Quantity? quantity,
    }) =>
        SaleLine(
          productId: ProductId('p1'),
          quantity: quantity ?? Quantity.whole(1),
          unitSellingPrice: selling,
          unitPurchaseCost: cost,
        );

    test('derives integer cost and gross profit without conversion', () {
      final line = costed(
        selling: const Money(
          currency: CurrencyCode.yemeniRial,
          minorUnits: 250,
        ),
        cost: const Money(
          currency: CurrencyCode.yemeniRial,
          minorUnits: 100,
        ),
        quantity: Quantity.whole(3),
      );
      expect(
        line.lineCost,
        const Money(currency: CurrencyCode.yemeniRial, minorUnits: 300),
      );
      expect(
        line.grossProfit,
        const Money(currency: CurrencyCode.yemeniRial, minorUnits: 450),
      );
    });

    test('applies quantity scale consistently for fractional quantities', () {
      final line = costed(
        selling: const Money(
          currency: CurrencyCode.yemeniRial,
          minorUnits: 200,
        ),
        cost: const Money(
          currency: CurrencyCode.yemeniRial,
          minorUnits: 100,
        ),
        quantity: Quantity.fromMilliUnits(1500),
      );
      expect(line.lineTotal.minorUnits, 300);
      expect(line.lineCost!.minorUnits, 150);
      expect(line.grossProfit!.minorUnits, 150);
    });

    test('supports losses when cost exceeds selling price', () {
      final line = costed(
        selling: const Money(
          currency: CurrencyCode.yemeniRial,
          minorUnits: 100,
        ),
        cost: const Money(
          currency: CurrencyCode.yemeniRial,
          minorUnits: 250,
        ),
      );
      expect(line.grossProfit!.minorUnits, -150);
    });

    test('missing cost yields unknown cost and profit, never zero', () {
      final line = costed(
        selling: const Money(
          currency: CurrencyCode.yemeniRial,
          minorUnits: 100,
        ),
        cost: null,
      );
      expect(line.lineCost, isNull);
      expect(line.grossProfit, isNull);
    });

    test('zero selling price yields a loss and an unavailable margin', () {
      final line = costed(
        selling: const Money(
          currency: CurrencyCode.yemeniRial,
          minorUnits: 0,
        ),
        cost: const Money(
          currency: CurrencyCode.yemeniRial,
          minorUnits: 40,
        ),
      );
      expect(line.lineTotal.minorUnits, 0);
      expect(line.grossProfit!.minorUnits, -40);
      final margin = GrossProfitMargin.fromMinorUnits(
        revenueMinorUnits: line.lineTotal.minorUnits,
        grossProfitMinorUnits: line.grossProfit!.minorUnits,
      );
      expect(margin.isAvailable, isFalse);
      expect(margin.label, '—');
    });

    test('foreign cost currency yields unknown profit without conversion', () {
      final line = costed(
        selling: const Money(
          currency: CurrencyCode.yemeniRial,
          minorUnits: 100,
        ),
        cost: const Money(
          currency: CurrencyCode.saudiRiyal,
          minorUnits: 100,
        ),
      );
      expect(line.lineCost, isNull);
      expect(line.grossProfit, isNull);
    });
  });

  group('GrossProfitMargin', () {
    test('computes one decimal percent from integer totals', () {
      final margin = GrossProfitMargin.fromMinorUnits(
        revenueMinorUnits: 300,
        grossProfitMinorUnits: 100,
      );
      expect(margin.isAvailable, isTrue);
      expect(margin.label, '33.3%');
    });

    test('reports losses with a negative sign', () {
      final margin = GrossProfitMargin.fromMinorUnits(
        revenueMinorUnits: 1000,
        grossProfitMinorUnits: -50,
      );
      expect(margin.label, '-5.0%');
    });

    test('rounds to the nearest tenth away from zero', () {
      final margin = GrossProfitMargin.fromMinorUnits(
        revenueMinorUnits: 3,
        grossProfitMinorUnits: 1,
      );
      expect(margin.label, '33.3%');
      final smallLoss = GrossProfitMargin.fromMinorUnits(
        revenueMinorUnits: 2000,
        grossProfitMinorUnits: -1,
      );
      expect(smallLoss.label, '-0.1%');
    });

    test('is unavailable for zero or negative revenue', () {
      final zero = GrossProfitMargin.fromMinorUnits(
        revenueMinorUnits: 0,
        grossProfitMinorUnits: 0,
      );
      expect(zero.isAvailable, isFalse);
      expect(zero.label, '—');
      final negative = GrossProfitMargin.fromMinorUnits(
        revenueMinorUnits: -10,
        grossProfitMinorUnits: 5,
      );
      expect(negative.isAvailable, isFalse);
    });

    test('zero profit over positive revenue is a real 0.0 percent', () {
      final margin = GrossProfitMargin.fromMinorUnits(
        revenueMinorUnits: 500,
        grossProfitMinorUnits: 0,
      );
      expect(margin.label, '0.0%');
    });
  });

  group('Sale', () {
    test('rejects empty lines', () {
      expect(
        () => Sale(
          id: SaleId('s1'),
          merchantId: MerchantId('m1'),
          currency: CurrencyCode.yemeniRial,
          lines: const <SaleLine>[],
        ),
        throwsArgumentError,
      );
    });

    test('rejects mixed line currencies', () {
      expect(
        () => Sale(
          id: SaleId('s1'),
          merchantId: MerchantId('m1'),
          currency: CurrencyCode.yemeniRial,
          lines: <SaleLine>[line(), line(product: 'p2', unitSellingPrice: sar)],
        ),
        throwsArgumentError,
      );
    });

    test('accepts multiple lines with the same currency', () {
      final sale = Sale(
        id: SaleId('s1'),
        merchantId: MerchantId('m1'),
        currency: CurrencyCode.yemeniRial,
        lines: <SaleLine>[
          line(quantity: Quantity.whole(2)),
          line(product: 'p2', quantity: Quantity.whole(1)),
        ],
      );
      expect(sale.lines, hasLength(2));
      expect(sale.merchantId, MerchantId('m1'));
      expect(sale.currency, CurrencyCode.yemeniRial);
    });

    test('line collection is immutable', () {
      final sale = Sale(
        id: SaleId('s1'),
        merchantId: MerchantId('m1'),
        currency: CurrencyCode.yemeniRial,
        lines: <SaleLine>[line()],
      );
      expect(() => sale.lines.add(line(product: 'p2')), throwsUnsupportedError);
    });

    test('equality uses SaleId identity', () {
      final a = Sale(
        id: SaleId('s1'),
        merchantId: MerchantId('m1'),
        currency: CurrencyCode.yemeniRial,
        lines: <SaleLine>[line()],
      );
      final b = Sale(
        id: SaleId('s1'),
        merchantId: MerchantId('m2'),
        currency: CurrencyCode.yemeniRial,
        lines: <SaleLine>[line(product: 'p9', quantity: Quantity.whole(9))],
      );
      final c = Sale(
        id: SaleId('s2'),
        merchantId: MerchantId('m1'),
        currency: CurrencyCode.yemeniRial,
        lines: <SaleLine>[line()],
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == c, isFalse);
    });

    test('does not expose mutable internal state', () {
      final input = <SaleLine>[line()];
      final sale = Sale(
        id: SaleId('s1'),
        merchantId: MerchantId('m1'),
        currency: CurrencyCode.yemeniRial,
        lines: input,
      );
      input.add(line(product: 'p2'));
      expect(sale.lines, hasLength(1));
      expect(() => sale.lines.clear(), throwsUnsupportedError);
    });

    test('cash sale omits customerId', () {
      final sale = Sale(
        id: SaleId('s1'),
        merchantId: MerchantId('m1'),
        currency: CurrencyCode.yemeniRial,
        lines: <SaleLine>[line()],
      );
      expect(sale.customerId, isNull);
    });

    test('credit sale may carry customerId', () {
      final sale = Sale(
        id: SaleId('s1'),
        merchantId: MerchantId('m1'),
        currency: CurrencyCode.yemeniRial,
        lines: <SaleLine>[line()],
        customerId: CustomerId('c1'),
      );
      expect(sale.customerId, CustomerId('c1'));
    });

    test('total is the sum of lineTotals', () {
      final sale = Sale(
        id: SaleId('s1'),
        merchantId: MerchantId('m1'),
        currency: CurrencyCode.yemeniRial,
        lines: <SaleLine>[
          line(quantity: Quantity.whole(2)),
          line(product: 'p2', quantity: Quantity.whole(3)),
        ],
      );
      expect(
        sale.total,
        const Money(currency: CurrencyCode.yemeniRial, minorUnits: 5000),
      );
    });
  });
}
