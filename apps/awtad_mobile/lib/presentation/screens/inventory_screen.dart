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
  final _price = TextEditingController(text: '100');
  List<MerchantInventoryItem> _items = const <MerchantInventoryItem>[];
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
    _price.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final items = await widget.session.inventory.getAll(
      RetailSession.defaultMerchant,
    );
    setState(() => _items = items);
  }

  Future<void> _add() async {
    final id = _product.text.trim();
    if (id.isEmpty) {
      setState(() => _message = 'أدخل معرف المنتج.');
      return;
    }
    try {
      await widget.session.inventoryService.addProduct(
        RetailSession.defaultMerchant,
        ProductId(id),
        quantity: Quantity.whole(int.parse(_qty.text.trim())),
        sellingPrice: Money(
          currency: CurrencyCode.saudiRiyal,
          minorUnits: int.parse(_price.text.trim()),
        ),
      );
      _product.clear();
      setState(() => _message = 'تمت إضافة المنتج.');
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
          controller: _product,
          decoration: const InputDecoration(labelText: 'معرف المنتج'),
        ),
        TextField(
          controller: _qty,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'الكمية'),
        ),
        TextField(
          controller: _price,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'سعر البيع (هللات)'),
        ),
        const SizedBox(height: 8),
        FilledButton(onPressed: _add, child: const Text('إضافة للمخزون')),
        if (_message != null) Text(_message!),
        const Divider(),
        for (final item in _items)
          ListTile(
            title: Text(item.productId.value),
            subtitle: Text(
              'كمية ${item.quantity.wholeUnits} · سعر ${item.sellingPrice?.minorUnits ?? 0}',
            ),
          ),
      ],
    );
  }
}
