import '../language/language_code.dart';
import '../merchant/merchant_id.dart';
import '../money/currency_code.dart';
import 'store_id.dart';
import 'store_name.dart';
import 'store_type.dart';

/// A merchant owned store.
///
/// Equality and [hashCode] are based on [id] only.
class Store {
  const Store({
    required this.id,
    required this.merchantId,
    required this.name,
    required this.type,
    required this.defaultCurrency,
    required this.defaultLanguage,
  });

  final StoreId id;
  final MerchantId merchantId;
  final StoreName name;
  final StoreType type;

  /// Default currency for the store. There is no implicit default.
  final CurrencyCode defaultCurrency;

  /// Default language for the store. There is no implicit default.
  final LanguageCode defaultLanguage;

  @override
  bool operator ==(Object other) => other is Store && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Store($id)';
}
