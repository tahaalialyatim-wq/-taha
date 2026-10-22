import '../../domain/customer/customer.dart';
import '../../domain/customer/customer_id.dart';
import '../../domain/merchant/merchant_id.dart';
import '../inventory/inventory_exceptions.dart';
import 'customer_exceptions.dart';
import 'customer_repository.dart';

/// In-memory [CustomerRepository].
///
/// There is no persistence. Storage is merchant-scoped: identity is
/// [MerchantId] + [CustomerId].
class InMemoryCustomerRepository implements CustomerRepository {
  final Map<String, Customer> _byKey = <String, Customer>{};
  final List<String> _order = <String>[];

  @override
  Future<void> add(Customer customer) async {
    final key = _key(customer.merchantId, customer.id);
    if (_byKey.containsKey(key)) {
      throw DuplicateCustomerException(
        merchantId: customer.merchantId,
        customerId: customer.id,
      );
    }
    CustomerRepository.requireUniquePhone(customer, _byKey.values);
    _byKey[key] = customer;
    _order.add(key);
  }

  @override
  Future<Customer?> getById(
    MerchantId merchantId,
    CustomerId customerId,
  ) async {
    return _byKey[_key(merchantId, customerId)];
  }

  @override
  Future<List<Customer>> getAll(MerchantId merchantId) async {
    final customers = <Customer>[];
    for (final key in _order) {
      final customer = _byKey[key];
      if (customer != null && customer.merchantId == merchantId) {
        customers.add(customer);
      }
    }
    return List<Customer>.unmodifiable(customers);
  }

  @override
  Future<void> update(Customer customer) async {
    final existing = _requireOwned(customer.merchantId, customer.id);
    CustomerRepository.requireUniquePhone(customer, _byKey.values);
    final key = _key(existing.merchantId, existing.id);
    _byKey[key] = customer;
  }

  @override
  Future<void> remove(MerchantId merchantId, CustomerId customerId) async {
    _requireOwned(merchantId, customerId);
    final key = _key(merchantId, customerId);
    _byKey.remove(key);
    _order.remove(key);
  }

  @override
  Future<bool> exists(MerchantId merchantId, CustomerId customerId) async {
    return _byKey.containsKey(_key(merchantId, customerId));
  }

  Customer _requireOwned(MerchantId merchantId, CustomerId customerId) {
    Customer? existing;
    for (final customer in _byKey.values) {
      if (customer.id == customerId) {
        existing = customer;
        if (customer.merchantId == merchantId) {
          return customer;
        }
      }
    }
    if (existing == null) {
      throw CustomerNotFoundException(
        merchantId: merchantId,
        customerId: customerId,
      );
    }
    throw MerchantMismatchException(
      expected: merchantId,
      actual: existing.merchantId,
    );
  }

  static String _key(MerchantId merchantId, CustomerId customerId) =>
      '${merchantId.value}:${customerId.value}';
}
