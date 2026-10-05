import 'barcode_type.dart';

/// A product barcode value.
///
/// The [value] is trimmed; empty or whitespace-only values are rejected. There
/// is no camera, scanner or checksum logic. Equality includes the value, the
/// [type] and the [isPrimary] flag.
class Barcode {
  Barcode(String value, {this.type = BarcodeType.other, this.isPrimary = false})
      : value = _validate(value);

  final String value;
  final BarcodeType type;
  final bool isPrimary;

  static String _validate(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(value, 'value', 'Barcode must not be empty');
    }
    return trimmed;
  }

  @override
  bool operator ==(Object other) =>
      other is Barcode &&
      other.value == value &&
      other.type == type &&
      other.isPrimary == isPrimary;

  @override
  int get hashCode => Object.hash(value, type, isPrimary);

  @override
  String toString() => 'Barcode($value, $type, primary: $isPrimary)';
}
