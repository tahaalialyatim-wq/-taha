import 'package:awtad_retail/awtad_retail.dart';
import 'package:test/test.dart';

void main() {
  group('CustomerId', () {
    test('rejects empty and whitespace-only values', () {
      expect(() => CustomerId(''), throwsArgumentError);
      expect(() => CustomerId('   '), throwsArgumentError);
    });

    test('trims correctly', () {
      expect(CustomerId('  c1 ').value, 'c1');
    });

    test('has value equality', () {
      expect(CustomerId('c1'), CustomerId('c1'));
      expect(CustomerId('c1').hashCode, CustomerId('c1').hashCode);
      expect(CustomerId('c1') == CustomerId('c2'), isFalse);
    });
  });

  group('Customer', () {
    Customer build({
      CustomerId? id,
      MerchantId? merchantId,
      String name = 'Ali',
      String? phone,
      String? notes,
    }) =>
        Customer(
          id: id ?? CustomerId('c1'),
          merchantId: merchantId ?? MerchantId('m1'),
          name: name,
          phone: phone,
          notes: notes,
        );

    test('trims name', () {
      expect(build(name: '  Ali ').name, 'Ali');
    });

    test('rejects empty and whitespace-only names', () {
      expect(() => build(name: ''), throwsArgumentError);
      expect(() => build(name: '   '), throwsArgumentError);
    });

    test('trims optional phone and notes', () {
      final customer = build(phone: '  777 ', notes: '  vip ');
      expect(customer.phone, '777');
      expect(customer.notes, 'vip');
    });

    test('blank optional phone and notes become null', () {
      final customer = build(phone: '   ', notes: '   ');
      expect(customer.phone, isNull);
      expect(customer.notes, isNull);
    });

    test('null optional fields stay null', () {
      final customer = build();
      expect(customer.phone, isNull);
      expect(customer.notes, isNull);
    });

    test('equality is by CustomerId only', () {
      final a = build(name: 'Ali');
      final b = build(name: 'Sara', merchantId: MerchantId('m2'));
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == build(id: CustomerId('c2')), isFalse);
    });

    test('owns a merchantId', () {
      expect(build().merchantId, MerchantId('m1'));
    });
  });
}
