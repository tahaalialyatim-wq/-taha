/// Canonical currency code.
///
/// Supported values are [yemeniRial] (`YER`), [saudiRiyal] (`SAR`) and
/// [usDollar] (`USD`). Parsing trims and uppercases the input and requires
/// exactly three alphabetic characters. No conversion or exchange rates are
/// modelled.
class CurrencyCode {
  const CurrencyCode._(this.value);

  final String value;

  static const CurrencyCode yemeniRial = CurrencyCode._('YER');
  static const CurrencyCode saudiRiyal = CurrencyCode._('SAR');
  static const CurrencyCode usDollar = CurrencyCode._('USD');

  /// Supported values, in deterministic order.
  static const List<CurrencyCode> values = <CurrencyCode>[
    yemeniRial,
    saudiRiyal,
    usDollar,
  ];

  /// Parses [input] into a supported [CurrencyCode].
  factory CurrencyCode.parse(String input) {
    final normalized = input.trim().toUpperCase();
    if (normalized.length != 3 || !_isAlphabetic(normalized)) {
      throw ArgumentError.value(
        input,
        'input',
        'CurrencyCode must be exactly three alphabetic characters',
      );
    }
    for (final code in values) {
      if (code.value == normalized) {
        return code;
      }
    }
    throw ArgumentError.value(input, 'input', 'Unsupported CurrencyCode');
  }

  static bool _isAlphabetic(String value) {
    for (final unit in value.codeUnits) {
      final isLower = unit >= 0x61 && unit <= 0x7A;
      final isUpper = unit >= 0x41 && unit <= 0x5A;
      if (!isLower && !isUpper) {
        return false;
      }
    }
    return true;
  }

  @override
  bool operator ==(Object other) =>
      other is CurrencyCode && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'CurrencyCode($value)';
}
