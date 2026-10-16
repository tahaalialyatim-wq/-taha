import 'package:awtad_retail/awtad_retail.dart';
import 'package:flutter/material.dart';

import '../../core/database/retail_session.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key, required this.session});

  final RetailSession session;

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final _product = TextEditingController();
  final _qty = TextEditingController(text: '1');
  final _sellingPrice = TextEditingController();
  final _purchasePrice = TextEditingController();
  List<MerchantInventoryItem> _items = const <MerchantInventoryItem>[];
  CurrencyCode? _defaultCurrency;
  CurrencyCode? _sellingCurrency;
  CurrencyCode? _purchaseCurrency;
  MerchantInventoryItem? _editing;
  String? _message;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _product.dispose();
    _qty.dispose();
    _sellingPrice.dispose();
    _purchasePrice.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final merchant = RetailSession.defaultMerchant;
    final items = await widget.session.inventory.getAll(merchant);
    final savedDefault =
        await widget.session.settings.readDefaultCurrency(merchant);
    if (!mounted) {
      return;
    }
    setState(() {
      _items = items;
      _defaultCurrency = savedDefault;
      if (_editing == null) {
        _sellingCurrency ??= savedDefault;
        _purchaseCurrency ??= savedDefault;
      }
    });
  }

  void _startEdit(MerchantInventoryItem item) {
    _product.text = item.productId.value;
    _qty.text = item.quantity.wholeUnits.toString();
    _sellingPrice.text = item.sellingPrice?.minorUnits.toString() ?? '';
    _purchasePrice.text = item.purchasePrice?.minorUnits.toString() ?? '';
    setState(() {
      _editing = item;
      _sellingCurrency = item.sellingPrice?.currency ?? _defaultCurrency;
      _purchaseCurrency = item.purchasePrice?.currency ?? _defaultCurrency;
      _message = null;
    });
  }

  void _cancelEdit() {
    _product.clear();
    _qty.text = '1';
    _sellingPrice.clear();
    _purchasePrice.clear();
    setState(() {
      _editing = null;
      _sellingCurrency = _defaultCurrency;
      _purchaseCurrency = _defaultCurrency;
      _message = null;
    });
  }

  Money? _priceFrom(TextEditingController controller, CurrencyCode? currency) {
    final text = controller.text.trim();
    if (text.isEmpty) {
      return null;
    }
    return Money(currency: currency!, minorUnits: int.parse(text));
  }

  Future<void> _add() async {
    final id = _product.text.trim();
    final qtyText = _qty.text.trim();
    if (id.isEmpty) {
      setState(() => _message = 'أدخل معرف المنتج.');
      return;
    }
    Quantity quantity;
    try {
      quantity = Quantity.whole(int.parse(qtyText));
    } on FormatException {
      setState(() => _message = 'أدخل كمية صحيحة.');
      return;
    }
    final needsSelling = _sellingPrice.text.trim().isNotEmpty;
    final needsPurchase = _purchasePrice.text.trim().isNotEmpty;
    if (needsSelling && _sellingCurrency == null) {
      setState(() => _message = 'اختر عملة سعر البيع قبل الحفظ.');
      return;
    }
    if (needsPurchase && _purchaseCurrency == null) {
      setState(() => _message = 'اختر عملة سعر الشراء قبل الحفظ.');
      return;
    }
    try {
      final selling =
          needsSelling ? _priceFrom(_sellingPrice, _sellingCurrency) : null;
      final purchase =
          needsPurchase ? _priceFrom(_purchasePrice, _purchaseCurrency) : null;
      final editing = _editing;
      if (editing == null) {
        await widget.session.inventoryService.addProduct(
          RetailSession.defaultMerchant,
          ProductId(id),
          quantity: quantity,
          sellingPrice: selling,
          purchasePrice: purchase,
        );
        _product.clear();
        _qty.text = '1';
        _sellingPrice.clear();
        _purchasePrice.clear();
        setState(() {
          _message = 'تمت إضافة المنتج.';
          _sellingCurrency = _defaultCurrency;
          _purchaseCurrency = _defaultCurrency;
        });
      } else {
        await widget.session.inventory.update(
          MerchantInventoryItem(
            id: editing.id,
            merchantId: editing.merchantId,
            productId: editing.productId,
            quantity: quantity,
            sellingPrice: selling,
            purchasePrice: purchase,
            minimumStock: editing.minimumStock,
          ),
        );
        setState(() {
          _editing = null;
          _message = 'تم حفظ التعديل.';
          _sellingCurrency = _defaultCurrency;
          _purchaseCurrency = _defaultCurrency;
        });
      }
      await _reload();
    } catch (error) {
      setState(() => _message = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'إدارة المخزون',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('product-field'),
          controller: _product,
          readOnly: _editing != null,
          decoration: const InputDecoration(labelText: 'معرف المنتج'),
        ),
        TextField(
          key: const Key('qty-field'),
          controller: _qty,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'الكمية'),
        ),
        const SizedBox(height: 12),
        _currencyRow(
          label: 'عملة سعر البيع',
          prefix: 'selling',
          value: _sellingCurrency,
          onSelected: (code) => setState(() => _sellingCurrency = code),
        ),
        TextField(
          key: const Key('selling-price-field'),
          controller: _sellingPrice,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
              labelText: _priceLabel('سعر البيع', _sellingCurrency)),
        ),
        const SizedBox(height: 12),
        _currencyRow(
          label: 'عملة سعر الشراء',
          prefix: 'purchase',
          value: _purchaseCurrency,
          onSelected: (code) => setState(() => _purchaseCurrency = code),
        ),
        TextField(
          key: const Key('purchase-price-field'),
          controller: _purchasePrice,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
              labelText: _priceLabel('سعر الشراء', _purchaseCurrency)),
        ),
        const SizedBox(height: 8),
        FilledButton(
          key: const Key('save-button'),
          onPressed: _add,
          child: Text(_editing == null ? 'إضافة للمخزون' : 'حفظ التعديل'),
        ),
        if (_editing != null)
          TextButton(
            key: const Key('cancel-button'),
            onPressed: _cancelEdit,
            child: const Text('إلغاء'),
          ),
        if (_message != null) Text(_message!),
        const Divider(),
        for (final item in _items)
          ListTile(
            title: Text(item.productId.value),
            subtitle: Text(
              'كمية ${item.quantity.wholeUnits} · بيع ${_moneyLabel(item.sellingPrice)} · '
              'شراء ${_moneyLabel(item.purchasePrice)}',
            ),
            trailing: IconButton(
              key: Key('edit-${item.productId.value}'),
              icon: const Icon(Icons.edit),
              onPressed: () => _startEdit(item),
            ),
          ),
      ],
    );
  }

  String _priceLabel(String base, CurrencyCode? currency) {
    if (currency == null) {
      return '$base (وحدات صغرى)';
    }
    return '$base (وحدات صغرى ${currency.value})';
  }

  String _moneyLabel(Money? money) {
    if (money == null) {
      return '—';
    }
    return '${money.minorUnits} ${money.currency.value}';
  }

  Widget _currencyRow({
    required String label,
    required String prefix,
    required CurrencyCode? value,
    required ValueChanged<CurrencyCode> onSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          children: [
            for (final code in CurrencyCode.values)
              ChoiceChip(
                key: Key('$prefix-currency-${code.value}'),
                label: Text(code.value),
                selected: value == code,
                onSelected: (_) => onSelected(code),
              ),
          ],
        ),
      ],
    );
  }
}
