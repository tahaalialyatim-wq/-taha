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

class _SalesScreenState extends State<SalesScreen> {
  final _search = TextEditingController();
  final Map<String, int> _cart = <String, int>{};
  List<MerchantInventoryItem> _items = const <MerchantInventoryItem>[];
  List<Customer> _customers = const <Customer>[];
  CustomerId? _creditCustomer;
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
    setState(() {
      _items = items;
      _customers = customers;
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

  Future<void> _complete({required bool credit}) async {
    if (_cart.isEmpty) {
      setState(() => _message = 'أضف منتجاً إلى سلة البيع.');
      return;
    }
    final merchant = RetailSession.defaultMerchant;
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
        final customerId = _creditCustomer;
        if (customerId == null) {
          setState(() => _message = 'اختر عميلاً للبيع الآجل.');
          return;
        }
        await widget.session.creditSales.complete(
          CreditSaleCommand(
            saleId: SaleId('sale-${DateTime.now().microsecondsSinceEpoch}'),
            merchantId: merchant,
            customerId: customerId,
            ledgerEntryId: CustomerAccountEntryId(
              'e-${DateTime.now().microsecondsSinceEpoch}',
            ),
            currency: CurrencyCode.saudiRiyal,
            occurredAt: DateTime.now().toUtc(),
            lines: lines,
          ),
        );
      } else {
        await widget.session.cashSales.complete(
          CompleteSaleCommand(
            saleId: SaleId('sale-${DateTime.now().microsecondsSinceEpoch}'),
            merchantId: merchant,
            currency: CurrencyCode.saudiRiyal,
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
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
                    'المخزون: ${item.quantity.wholeUnits} · السعر: ${item.sellingPrice?.minorUnits ?? 0}',
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
