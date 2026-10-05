/// Canonical language code.
///
/// Supported values are [arabic] (`ar`) and [english] (`en`). Parsing trims
/// and lowercases the input and requires exactly two alphabetic characters.
class LanguageCode {
  const LanguageCode._(this.value);

  final String value;

  static const LanguageCode arabic = LanguageCode._('ar');
  static const LanguageCode english = LanguageCode._('en');

  /// Supported values, in deterministic order.
  static const List<LanguageCode> values = <LanguageCode>[arabic, english];

  /// Parses [input] into a supported [LanguageCode].
  factory LanguageCode.parse(String input) {
    final normalized = input.trim().toLowerCase();
    if (normalized.length != 2 || !_isAlphabetic(normalized)) {
      throw ArgumentError.value(
        input,
        'input',
        'LanguageCode must be exactly two alphabetic characters',
      );
    }
    for (final code in values) {
      if (code.value == normalized) {
        return code;
      }
    }
    throw ArgumentError.value(input, 'input', 'Unsupported LanguageCode');
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
      other is LanguageCode && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'LanguageCode($value)';
}
