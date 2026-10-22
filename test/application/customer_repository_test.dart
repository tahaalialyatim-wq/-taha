import 'package:awtad_retail/awtad_retail.dart';
import 'package:test/test.dart';

void main() {
  late InMemoryCustomerRepository repository;

  setUp(() {
    repository = InMemoryCustomerRepository();
  });

  Customer customer({
    String id = 'c1',
    String merchant = 'm1',
    String name = 'Ali',
    String? phone,
    String? notes,
  }) =>
      Customer(
        id: CustomerId(id),
        merchantId: MerchantId(merchant),
        name: name,
        phone: phone,
        notes: notes,
      );

  group('InMemoryCustomerRepository', () {
    test('add stores a Customer', () async {
      final stored = customer();
      await repository.add(stored);
      final found =
          await repository.getById(MerchantId('m1'), CustomerId('c1'));
      expect(found, stored);
    });

    test('getById retrieves the correct Customer', () async {
      await repository.add(customer(id: 'c1', name: 'Ali'));
      await repository.add(customer(id: 'c2', name: 'Sara'));
      final found =
          await repository.getById(MerchantId('m1'), CustomerId('c2'));
      expect(found!.id, CustomerId('c2'));
      expect(found.name, 'Sara');
    });

    test('getById returns null for missing Customer', () async {
      expect(
        await repository.getById(MerchantId('m1'), CustomerId('missing')),
        isNull,
      );
    });

    test('getById enforces MerchantId isolation', () async {
      await repository.add(customer());
      expect(
        await repository.getById(MerchantId('m2'), CustomerId('c1')),
        isNull,
      );
      expect(
        await repository.getById(MerchantId('m1'), CustomerId('c1')),
        isNotNull,
      );
    });

    test('exists is merchant-scoped', () async {
      await repository.add(customer());
      expect(
          await repository.exists(MerchantId('m1'), CustomerId('c1')), isTrue);
      expect(
        await repository.exists(MerchantId('m2'), CustomerId('c1')),
        isFalse,
      );
      expect(
        await repository.exists(MerchantId('m1'), CustomerId('missing')),
        isFalse,
      );
    });

    test("getAll returns only the requested merchant's customers", () async {
      await repository.add(customer(id: 'c1'));
      await repository.add(customer(id: 'c2'));
      await repository.add(customer(id: 'c1', merchant: 'm2', name: 'Other'));
      final all = await repository.getAll(MerchantId('m1'));
      expect(all.map((c) => c.id),
          <CustomerId>[CustomerId('c1'), CustomerId('c2')]);
      expect(all.every((c) => c.merchantId == MerchantId('m1')), isTrue);
    });

    test('getAll returns an empty list when merchant has no customers',
        () async {
      await repository.add(customer());
      expect(await repository.getAll(MerchantId('m2')), isEmpty);
    });

    test(
        'duplicate CustomerId for the same merchant throws DuplicateCustomerException',
        () async {
      await repository.add(customer());
      expect(
        () => repository.add(customer(name: 'Other')),
        throwsA(isA<DuplicateCustomerException>()),
      );
    });

    test('duplicate phone for the same merchant is rejected on add', () async {
      await repository.add(customer(id: 'c1', phone: '777'));
      expect(
        () => repository.add(customer(id: 'c2', name: 'Sara', phone: '777')),
        throwsA(isA<DuplicateCustomerPhoneException>()),
      );
      expect(await repository.getAll(MerchantId('m1')), hasLength(1));
      expect(
        (await repository.getById(MerchantId('m1'), CustomerId('c1')))!.phone,
        '777',
      );
    });

    test('duplicate phone for the same merchant is rejected on update',
        () async {
      await repository.add(customer(id: 'c1', phone: '777'));
      await repository.add(customer(id: 'c2', name: 'Sara', phone: '888'));
      expect(
        () => repository.update(customer(id: 'c2', name: 'Sara', phone: '777')),
        throwsA(isA<DuplicateCustomerPhoneException>()),
      );
      expect(
        (await repository.getById(MerchantId('m1'), CustomerId('c2')))!.phone,
        '888',
      );
      expect(
        (await repository.getById(MerchantId('m1'), CustomerId('c1')))!.phone,
        '777',
      );
    });

    test('update may keep the same customer phone', () async {
      await repository.add(customer(phone: '777'));
      await repository.update(customer(name: 'Sara', phone: '777'));
      final found =
          await repository.getById(MerchantId('m1'), CustomerId('c1'));
      expect(found!.name, 'Sara');
      expect(found.phone, '777');
    });

    test('different merchants may share the same phone', () async {
      await repository.add(customer(merchant: 'm1', phone: '777'));
      await repository.add(
        customer(id: 'c2', merchant: 'm2', name: 'Other', phone: '777'),
      );
      expect(
        (await repository.getById(MerchantId('m1'), CustomerId('c1')))!.phone,
        '777',
      );
      expect(
        (await repository.getById(MerchantId('m2'), CustomerId('c2')))!.phone,
        '777',
      );
    });

    test('null and blank phones remain allowed for multiple customers',
        () async {
      await repository.add(customer(id: 'c1'));
      await repository.add(customer(id: 'c2', name: 'Sara', phone: '   '));
      expect(
        (await repository.getById(MerchantId('m1'), CustomerId('c1')))!.phone,
        isNull,
      );
      expect(
        (await repository.getById(MerchantId('m1'), CustomerId('c2')))!.phone,
        isNull,
      );
    });

    test('phone comparison trims surroundings but preserves digits and zeros',
        () async {
      await repository.add(customer(id: 'c1', phone: '  0777 '));
      expect(
        (await repository.getById(MerchantId('m1'), CustomerId('c1')))!.phone,
        '0777',
      );
      expect(
        () => repository.add(customer(id: 'c2', name: 'Sara', phone: '0777')),
        throwsA(isA<DuplicateCustomerPhoneException>()),
      );
      await repository.add(customer(id: 'c3', name: 'Omar', phone: '777'));
      await repository.add(customer(id: 'c4', name: 'Lina', phone: '+777'));
      expect(
        (await repository.getById(MerchantId('m1'), CustomerId('c3')))!.phone,
        '777',
      );
      expect(
        (await repository.getById(MerchantId('m1'), CustomerId('c4')))!.phone,
        '+777',
      );
    });

    test('the same CustomerId may exist for different merchants', () async {
      await repository.add(customer(merchant: 'm1'));
      await repository.add(customer(merchant: 'm2', name: 'Other'));
      expect(
        await repository.getById(MerchantId('m1'), CustomerId('c1')),
        isNotNull,
      );
      expect(
        await repository.getById(MerchantId('m2'), CustomerId('c1')),
        isNotNull,
      );
    });

    test('getAll result cannot mutate repository state', () async {
      await repository.add(customer());
      final all = await repository.getAll(MerchantId('m1'));
      expect(() => all.add(customer(id: 'c2')), throwsUnsupportedError);
      expect(await repository.getAll(MerchantId('m1')), hasLength(1));
    });

    test('multiple customers for one merchant are returned deterministically',
        () async {
      await repository.add(customer(id: 'c1'));
      await repository.add(customer(id: 'c2'));
      await repository.add(customer(id: 'c3'));
      final first = await repository.getAll(MerchantId('m1'));
      final second = await repository.getAll(MerchantId('m1'));
      expect(
        first.map((c) => c.id.value).toList(),
        <String>['c1', 'c2', 'c3'],
      );
      expect(
        second.map((c) => c.id.value).toList(),
        first.map((c) => c.id.value).toList(),
      );
    });

    test('update replaces an existing Customer', () async {
      await repository.add(customer());
      await repository.update(customer(name: 'Sara', phone: '777'));
      final found =
          await repository.getById(MerchantId('m1'), CustomerId('c1'));
      expect(found!.name, 'Sara');
      expect(found.phone, '777');
    });

    test('update of a missing Customer throws CustomerNotFoundException',
        () async {
      expect(
        () => repository.update(customer()),
        throwsA(isA<CustomerNotFoundException>()),
      );
    });

    test('update for the wrong merchant throws MerchantMismatchException',
        () async {
      await repository.add(customer(merchant: 'm1'));
      expect(
        () => repository.update(customer(merchant: 'm2')),
        throwsA(isA<MerchantMismatchException>()),
      );
    });

    test('remove deletes an existing Customer', () async {
      await repository.add(customer());
      await repository.remove(MerchantId('m1'), CustomerId('c1'));
      expect(
        await repository.getById(MerchantId('m1'), CustomerId('c1')),
        isNull,
      );
      expect(
          await repository.exists(MerchantId('m1'), CustomerId('c1')), isFalse);
    });

    test('remove of a missing Customer throws CustomerNotFoundException',
        () async {
      expect(
        () => repository.remove(MerchantId('m1'), CustomerId('missing')),
        throwsA(isA<CustomerNotFoundException>()),
      );
    });

    test('remove for the wrong merchant throws MerchantMismatchException',
        () async {
      await repository.add(customer());
      expect(
        () => repository.remove(MerchantId('m2'), CustomerId('c1')),
        throwsA(isA<MerchantMismatchException>()),
      );
      expect(
        await repository.getById(MerchantId('m1'), CustomerId('c1')),
        isNotNull,
      );
    });

    test('remove does not affect another merchant with the same CustomerId',
        () async {
      await repository.add(customer(merchant: 'm1'));
      await repository.add(customer(merchant: 'm2', name: 'Other'));
      await repository.remove(MerchantId('m1'), CustomerId('c1'));
      expect(
        await repository.getById(MerchantId('m1'), CustomerId('c1')),
        isNull,
      );
      expect(
        await repository.getById(MerchantId('m2'), CustomerId('c1')),
        isNotNull,
      );
    });
  });
}
