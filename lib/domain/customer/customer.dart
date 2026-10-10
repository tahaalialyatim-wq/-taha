import '../merchant/merchant_id.dart';
import 'customer_id.dart';

/// A merchant-owned customer record.
///
/// Equality and [hashCode] are based on [id] only. Ownership is [merchantId].
/// There is no balance, debt, credit, payment, invoice, SMS or PDF state.
class Customer {
  Customer({
    required this.id,
    required this.merchantId,
    required String name,
    String? phone,
    String? notes,
  })  : name = _validateName(name),
        phone = _optional(phone),
        notes = _optional(notes);

  final CustomerId id;
  final MerchantId merchantId;
  final String name;
  final String? phone;
  final String? notes;

  static String _validateName(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(
        value,
        'name',
        'Customer name must not be empty',
      );
    }
    return trimmed;
  }

  static String? _optional(String? value) {
    if (value == null) {
      return null;
    }
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  bool operator ==(Object other) => other is Customer && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Customer($id)';
}
