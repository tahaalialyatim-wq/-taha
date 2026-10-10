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
