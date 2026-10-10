import '../../domain/customer/customer.dart';
import '../../domain/customer/customer_id.dart';
import '../../domain/merchant/merchant_id.dart';

/// Merchant-scoped repository for [Customer] records.
///
/// Identity is [MerchantId] + [CustomerId]. Reads for the wrong merchant
/// return `null`/`false`. Mutations for the wrong merchant throw
/// [MerchantMismatchException]. Mutations for missing customers throw
/// [CustomerNotFoundException]. [getAll] returns an unmodifiable snapshot.
abstract class CustomerRepository {
  /// Stores [customer]. Rejects duplicate [MerchantId] + [CustomerId].
  Future<void> add(Customer customer);

  /// Returns the customer with [customerId] owned by [merchantId], or `null`.
  Future<Customer?> getById(MerchantId merchantId, CustomerId customerId);

  /// Returns an unmodifiable snapshot of all customers owned by [merchantId].
  Future<List<Customer>> getAll(MerchantId merchantId);

  /// Replaces [customer]. Throws when missing or owned by another merchant.
  Future<void> update(Customer customer);

  /// Removes a customer. Throws when missing or owned by another merchant.
  Future<void> remove(MerchantId merchantId, CustomerId customerId);

  /// Whether [merchantId] owns a customer with [customerId].
  Future<bool> exists(MerchantId merchantId, CustomerId customerId);
}
