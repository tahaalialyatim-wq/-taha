import 'package:awtad_retail/awtad_retail.dart';
import 'package:awtad_retail/domain/inventory/merchant_id.dart' as compat;
import 'package:test/test.dart';

void main() {
  group('MerchantId', () {
    test('trims input', () {
      expect(MerchantId('  m1 ').value, 'm1');
    });

    test('rejects empty values', () {
      expect(() => MerchantId(''), throwsArgumentError);
      expect(() => MerchantId('   '), throwsArgumentError);
    });

    test('has value equality', () {
      expect(MerchantId('m1'), MerchantId('m1'));
      expect(MerchantId('m1') == MerchantId('m2'), isFalse);
      expect(MerchantId('m1').hashCode, MerchantId('m1').hashCode);
    });

    test('compatibility inventory path re-exports the canonical type', () {
      final compat.MerchantId viaCompat = compat.MerchantId('m1');
      expect(viaCompat, isA<MerchantId>());
      expect(viaCompat, MerchantId('m1'));
    });
  });
}
