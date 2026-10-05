/// Human readable name of a [Store].
class StoreName {
  StoreName(String value) : value = _validate(value);

  final String value;

  static String _validate(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(value, 'value', 'StoreName must not be empty');
    }
    return trimmed;
  }

  @override
  bool operator ==(Object other) => other is StoreName && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'StoreName($value)';
}
