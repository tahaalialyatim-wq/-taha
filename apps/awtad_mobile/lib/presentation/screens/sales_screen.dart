import 'package:awtad_retail/awtad_retail.dart';
import 'package:flutter/material.dart';

import '../../core/database/retail_session.dart';
import '../../core/theme/app_theme.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key, required this.session});

  final RetailSession session;

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

/// Result of inspecting the cart's priced items.
class _CartCurrency {
  const _CartCurrency({
    required this.currency,
    required this.mixed,
    required this.totalMinorUnits,
  });

  /// The unanimous currency of priced items, or `null` when none/ambiguous.
  final CurrencyCode? currency;

  /// Whether priced items use more than one currency.
  final bool mixed;

  /// Integer minor-unit total of priced items.
  final int totalMinorUnits;
}

class _SalesScreenState extends State<SalesScreen> {
  final _search = TextEditingController();
  final Map<String, int> _cart = <String, int>{};
  List<MerchantInventoryItem> _items = const <MerchantInventoryItem>[];
  List<Customer> _customers = const <Customer>[];
  CustomerId? _creditCustomer;
  CurrencyCode? _selectedCurrency;
  bool _userSelectedCurrency = false;
  bool _loading = true;
  String? _message;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final merchant = RetailSession.defaultMerchant;
    final items = await widget.session.inventory.getAll(merchant);
    final customers = await widget.session.customers.getAll(merchant);
    final savedDefault =
        await widget.session.settings.readDefaultCurrency(merchant);
    if (!mounted) {
      return;
    }
    setState(() {
      _items = items;
      _customers = customers;
      _selectedCurrency ??= savedDefault;
      _loading = false;
    });
  }

  Iterable<MerchantInventoryItem> get _visible {
    final query = _search.text.trim();
    if (query.isEmpty) {
      return _items;
    }
    return _items.where(
      (item) => item.productId.value.contains(query),
    );
  }

  MerchantInventoryItem? _itemByProduct(String productId) {
    for (final item in _items) {
      if (item.productId.value == productId) {
        return item;
      }
    }
    return null;
  }

  _CartCurrency _cartCurrency() {
    final codes = <CurrencyCode>{};
    var total = 0;
    for (final entry in _cart.entries) {
      final price = _itemByProduct(entry.key)?.sellingPrice;
      if (price == null) {
        continue;
      }
      codes.add(price.currency);
      total += price.minorUnits * entry.value;
    }
    return _CartCurrency(
      currency: codes.length == 1 ? codes.first : null,
      mixed: codes.length > 1,
      totalMinorUnits: total,
    );
  }

  /// Intrinsic cart currency when unanimous, otherwise the explicit selection.
  CurrencyCode? get _effectiveCurrency {
    final cart = _cartCurrency();
    return cart.currency ?? _selectedCurrency;
  }

  Future<void> _complete({required bool credit}) async {
    if (_cart.isEmpty) {
      setState(() => _message = 'أضف منتجاً إلى سلة البيع.');
      return;
    }
    final merchant = RetailSession.defaultMerchant;
    final cart = _cartCurrency();
    if (cart.mixed) {
      setState(
        () => _message = 'لا يمكن خلط عملات مختلفة في فاتورة واحدة.',
      );
      return;
    }
    final intrinsic = cart.currency;
    final selected = _selectedCurrency;
    final CurrencyCode currency;
    if (intrinsic != null) {
      if (_userSelectedCurrency && selected != null && selected != intrinsic) {
        setState(
          () => _message =
              'عملة الفاتورة يجب أن تطابق عملة أسعار المنتجات (${intrinsic.value}).',
        );
        return;
      }
      currency = intrinsic;
    } else if (selected != null) {
      currency = selected;
    } else {
      setState(() => _message = 'اختر عملة الفاتورة قبل الحفظ.');
      return;
    }
    if (credit && _creditCustomer == null) {
      setState(() => _message = 'اختر عميلاً للبيع الآجل.');
      return;
    }

    final lines = <SaleCommandLine>[];
    for (final entry in _cart.entries) {
      lines.add(
        SaleCommandLine(
          productId: ProductId(entry.key),
          quantity: Quantity.whole(entry.value),
        ),
      );
    }
    try {
      if (credit) {
        await widget.session.creditSales.complete(
          CreditSaleCommand(
            saleId: SaleId('sale-${DateTime.now().microsecondsSinceEpoch}'),
            merchantId: merchant,
            customerId: _creditCustomer!,
            ledgerEntryId: CustomerAccountEntryId(
              'e-${DateTime.now().microsecondsSinceEpoch}',
            ),
            currency: currency,
            occurredAt: DateTime.now().toUtc(),
            lines: lines,
          ),
        );
      } else {
        await widget.session.cashSales.complete(
          CompleteSaleCommand(
            saleId: SaleId('sale-${DateTime.now().microsecondsSinceEpoch}'),
            merchantId: merchant,
            currency: currency,
            lines: lines,
          ),
        );
      }
      _cart.clear();
      setState(() => _message = 'تم حفظ البيع.');
      await _reload();
    } catch (error) {
      setState(() => _message = error.toString());
    }
  }

  String _priceLabel(MerchantInventoryItem item) {
    final price = item.sellingPrice;
    if (price == null) {
      return 'بلا سعر';
    }
    return '${price.minorUnits} ${price.currency.value}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final cart = _cartCurrency();
    final effective = _effectiveCurrency;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _search,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'بحث المنتجات وإتمام البيع',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              const Text('عملة الفاتورة: '),
              const SizedBox(width: 8),
              Expanded(
                child: Wrap(
                  spacing: 8,
                  children: [
                    for (final code in CurrencyCode.values)
                      ChoiceChip(
                        key: Key('sale-currency-${code.value}'),
                        label: Text(code.value),
                        selected: effective == code,
                        onSelected: (_) => setState(() {
                          _selectedCurrency = code;
                          _userSelectedCurrency = true;
                        }),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (_message != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(_message!, style: const TextStyle(color: Colors.red)),
          ),
        Expanded(
          child: ListView(
            children: [
              for (final item in _visible)
                ListTile(
                  title: Text(item.productId.value),
                  subtitle: Text(
                    'المخزون: ${item.quantity.wholeUnits} · السعر: ${_priceLabel(item)}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.add_shopping_cart),
                    onPressed: item.quantity.wholeUnits <= 0
                        ? null
                        : () {
                            setState(() {
                              _cart[item.productId.value] =
                                  (_cart[item.productId.value] ?? 0) + 1;
                            });
                          },
                  ),
                ),
            ],
          ),
        ),
        if (_customers.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: DropdownButton<CustomerId>(
              isExpanded: true,
              hint: const Text('عميل البيع الآجل'),
              value: _creditCustomer,
              items: [
                for (final customer in _customers)
                  DropdownMenuItem(
                    value: customer.id,
                    child: Text(customer.name),
                  ),
              ],
              onChanged: (value) => setState(() => _creditCustomer = value),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              'الإجمالي: ${effective == null ? '—' : '${cart.totalMinorUnits} ${effective.value}'}',
              key: const Key('sale-total'),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () => _complete(credit: false),
                  child:
                      Text('نقدي (${_cart.values.fold(0, (a, b) => a + b)})'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.brand,
                  ),
                  onPressed: () => _complete(credit: true),
                  child: const Text('آجل'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
