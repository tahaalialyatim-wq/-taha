import 'package:awtad_retail/awtad_retail.dart';
import 'package:test/test.dart';

void main() {
  group('LanguageCode', () {
    test('exposes supported values', () {
      expect(LanguageCode.values, hasLength(2));
      expect(
          LanguageCode.values,
          containsAll(<LanguageCode>[
            LanguageCode.arabic,
            LanguageCode.english,
          ]));
      expect(LanguageCode.arabic.value, 'ar');
      expect(LanguageCode.english.value, 'en');
    });

    test('parsing trims and lowercases', () {
      expect(LanguageCode.parse('  AR '), LanguageCode.arabic);
      expect(LanguageCode.parse('En'), LanguageCode.english);
    });

    test('requires exactly two alphabetic characters', () {
      expect(() => LanguageCode.parse('a'), throwsArgumentError);
      expect(() => LanguageCode.parse('ara'), throwsArgumentError);
      expect(() => LanguageCode.parse('a1'), throwsArgumentError);
      expect(() => LanguageCode.parse('1a'), throwsArgumentError);
    });

    test('rejects unsupported codes', () {
      expect(() => LanguageCode.parse('fr'), throwsArgumentError);
    });

    test('has value equality', () {
      expect(LanguageCode.parse('ar'), LanguageCode.arabic);
      expect(LanguageCode.arabic.hashCode, LanguageCode.parse('ar').hashCode);
    });
  });
}
