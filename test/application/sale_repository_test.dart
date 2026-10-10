import 'package:awtad_retail/awtad_retail.dart';
import 'package:test/test.dart';

void main() {
  const price = Money(currency: CurrencyCode.yemeniRial, minorUnits: 100);

  late InMemorySaleRepository repository;

  setUp(() {
    repository = InMemorySaleRepository();
  });

  SaleLine line({String product = 'p1', Quantity? quantity}) => SaleLine(
        productId: ProductId(product),
        quantity: quantity ?? Quantity.whole(1),
        unitSellingPrice: price,
      );

  Sale sale({
    String id = 's1',
    String merchant = 'm1',
    List<SaleLine>? lines,
  }) =>
      Sale(
        id: SaleId(id),
        merchantId: MerchantId(merchant),
        currency: CurrencyCode.yemeniRial,
        lines: lines ?? <SaleLine>[line()],
      );

  group('InMemorySaleRepository', () {
    test('add stores a Sale', () async {
      final stored = sale();
      await repository.add(stored);
      final found = await repository.getById(MerchantId('m1'), SaleId('s1'));
      expect(found, stored);
    });

    test('getById retrieves the correct Sale', () async {
      await repository.add(sale(id: 's1'));
      await repository
          .add(sale(id: 's2', lines: <SaleLine>[line(product: 'p2')]));
      final found = await repository.getById(MerchantId('m1'), SaleId('s2'));
      expect(found!.id, SaleId('s2'));
      expect(found.lines.single.productId, ProductId('p2'));
    });

    test('getById returns null for missing Sale', () async {
      expect(
        await repository.getById(MerchantId('m1'), SaleId('missing')),
        isNull,
      );
    });

    test('getById enforces MerchantId isolation', () async {
      await repository.add(sale());
      expect(
        await repository.getById(MerchantId('m2'), SaleId('s1')),
        isNull,
      );
      expect(
        await repository.getById(MerchantId('m1'), SaleId('s1')),
        isNotNull,
      );
    });

    test("getAll returns only the requested merchant's sales", () async {
      await repository.add(sale(id: 's1'));
      await repository.add(sale(id: 's2'));
      await repository.add(sale(id: 's1', merchant: 'm2'));
      final all = await repository.getAll(MerchantId('m1'));
      expect(all.map((s) => s.id), <SaleId>[SaleId('s1'), SaleId('s2')]);
      expect(all.every((s) => s.merchantId == MerchantId('m1')), isTrue);
    });

    test('getAll returns an empty list when merchant has no sales', () async {
      await repository.add(sale());
      expect(await repository.getAll(MerchantId('m2')), isEmpty);
    });

    test('duplicate SaleId for the same merchant throws DuplicateSaleException',
        () async {
      await repository.add(sale());
      expect(
        () => repository.add(sale(lines: <SaleLine>[line(product: 'p9')])),
        throwsA(isA<DuplicateSaleException>()),
      );
    });

    test('the same SaleId may exist for different merchants', () async {
      await repository.add(sale(merchant: 'm1'));
      await repository.add(sale(merchant: 'm2'));
      expect(
        await repository.getById(MerchantId('m1'), SaleId('s1')),
        isNotNull,
      );
      expect(
        await repository.getById(MerchantId('m2'), SaleId('s1')),
        isNotNull,
      );
    });

    test('getAll result cannot mutate repository state', () async {
      await repository.add(sale());
      final all = await repository.getAll(MerchantId('m1'));
      expect(() => all.add(sale(id: 's2')), throwsUnsupportedError);
      expect(await repository.getAll(MerchantId('m1')), hasLength(1));
    });

    test(
        'caller mutation of an input collection cannot mutate repository state',
        () async {
      final input = <SaleLine>[line()];
      final stored = sale(lines: input);
      await repository.add(stored);
      input.add(line(product: 'p2'));
      final found = await repository.getById(MerchantId('m1'), SaleId('s1'));
      expect(found!.lines, hasLength(1));
    });

    test('stored Sale remains immutable', () async {
      await repository.add(sale());
      final found = await repository.getById(MerchantId('m1'), SaleId('s1'));
      expect(
        () => found!.lines.add(line(product: 'p2')),
        throwsUnsupportedError,
      );
    });

    test('multiple sales for one merchant are returned deterministically',
        () async {
      await repository.add(sale(id: 's1'));
      await repository.add(sale(id: 's2'));
      await repository.add(sale(id: 's3'));
      final first = await repository.getAll(MerchantId('m1'));
      final second = await repository.getAll(MerchantId('m1'));
      expect(
        first.map((s) => s.id.value).toList(),
        <String>['s1', 's2', 's3'],
      );
      expect(
        second.map((s) => s.id.value).toList(),
        first.map((s) => s.id.value).toList(),
      );
    });
  });
}
