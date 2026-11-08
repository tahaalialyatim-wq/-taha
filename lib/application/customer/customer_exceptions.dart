import '../../domain/customer/customer_id.dart';
import '../../domain/merchant/merchant_id.dart';

/// Thrown when a merchant already owns a customer with the same [CustomerId].
class DuplicateCustomerException implements Exception {
  const DuplicateCustomerException({
    required this.merchantId,
    required this.customerId,
  });

  final MerchantId merchantId;
  final CustomerId customerId;

  @override
  String toString() =>
      'DuplicateCustomerException(merchant: ${merchantId.value}, '
      'customer: ${customerId.value})';
}

/// Thrown when a merchant already owns another customer with the same phone.
class DuplicateCustomerPhoneException implements Exception {
  const DuplicateCustomerPhoneException({
    required this.merchantId,
    required this.customerId,
    required this.existingCustomerId,
    required this.phone,
  });

  final MerchantId merchantId;
  final CustomerId customerId;
  final CustomerId existingCustomerId;
  final String phone;

  @override
  String toString() =>
      'DuplicateCustomerPhoneException(merchant: ${merchantId.value}, '
      'customer: ${customerId.value}, existing: ${existingCustomerId.value}, '
      'phone: $phone)';
}

/// Thrown when a mutation targets a customer that does not exist.
class CustomerNotFoundException implements Exception {
  const CustomerNotFoundException({
    required this.merchantId,
    required this.customerId,
  });

  final MerchantId merchantId;
  final CustomerId customerId;

  @override
  String toString() =>
      'CustomerNotFoundException(merchant: ${merchantId.value}, '
      'customer: ${customerId.value})';
}
