import '../../domain/customer/customer.dart';
import '../../domain/customer/customer_id.dart';
import '../../domain/merchant/merchant_id.dart';
import 'customer_exceptions.dart';

/// Merchant-scoped repository for [Customer] records.
///
/// Identity is [MerchantId] + [CustomerId]. Reads for the wrong merchant
/// return `null`/`false`. Mutations for the wrong merchant throw
/// [MerchantMismatchException]. Mutations for missing customers throw
/// [CustomerNotFoundException]. [getAll] returns an unmodifiable snapshot.
abstract class CustomerRepository {
  /// Stores [customer]. Rejects duplicate [MerchantId] + [CustomerId] and a
  /// non-null phone already used by another customer of the same merchant.
  /// Null phones remain allowed.
  Future<void> add(Customer customer);

  /// Returns the customer with [customerId] owned by [merchantId], or `null`.
  Future<Customer?> getById(MerchantId merchantId, CustomerId customerId);

  /// Returns an unmodifiable snapshot of all customers owned by [merchantId].
  Future<List<Customer>> getAll(MerchantId merchantId);

  /// Replaces [customer]. Throws when missing or owned by another merchant.
  /// Rejects a non-null phone already used by another customer of the same
  /// merchant. The customer's own current phone is not a duplicate.
  Future<void> update(Customer customer);

  /// Throws [DuplicateCustomerPhoneException] when [customer] carries a
  /// non-null phone already stored on another customer of the same merchant.
  /// Comparison is exact on the already-trimmed phone string. Null phones are
  /// skipped. [existing] may include other merchants and the same customer.
  static void requireUniquePhone(
    Customer customer,
    Iterable<Customer> existing,
  ) {
    final phone = customer.phone;
    if (phone == null) {
      return;
    }
    for (final other in existing) {
      if (other.merchantId != customer.merchantId) {
        continue;
      }
      if (other.id == customer.id) {
        continue;
      }
      if (other.phone == phone) {
        throw DuplicateCustomerPhoneException(
          merchantId: customer.merchantId,
          customerId: customer.id,
          existingCustomerId: other.id,
          phone: phone,
        );
      }
    }
  }

  /// Removes a customer. Throws when missing or owned by another merchant.
  Future<void> remove(MerchantId merchantId, CustomerId customerId);

  /// Whether [merchantId] owns a customer with [customerId].
  Future<bool> exists(MerchantId merchantId, CustomerId customerId);
}
