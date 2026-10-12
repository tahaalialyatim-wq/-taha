import 'package:awtad_retail/awtad_retail.dart';
import 'package:flutter/material.dart';

import '../../core/database/retail_session.dart';
import 'customer_detail_screen.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key, required this.session});

  final RetailSession session;

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  List<Customer> _customers = const <Customer>[];
  String? _message;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final customers = await widget.session.customers.getAll(
      RetailSession.defaultMerchant,
    );
    setState(() => _customers = customers);
  }

  Future<void> _add() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _message = 'أدخل اسم العميل.');
      return;
    }
    try {
      await widget.session.customers.add(
        Customer(
          id: CustomerId('c-${DateTime.now().microsecondsSinceEpoch}'),
          merchantId: RetailSession.defaultMerchant,
          name: name,
          phone: _phone.text,
        ),
      );
      _name.clear();
      _phone.clear();
      setState(() => _message = 'تم إنشاء الحساب.');
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
          'دليل العملاء',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        TextField(
          controller: _name,
          decoration: const InputDecoration(labelText: 'الاسم'),
        ),
        TextField(
          controller: _phone,
          decoration: const InputDecoration(labelText: 'الهاتف'),
        ),
        const SizedBox(height: 8),
        FilledButton(onPressed: _add, child: const Text('إنشاء حساب')),
        if (_message != null) Text(_message!),
        const Divider(),
        for (final customer in _customers)
          ListTile(
            title: Text(customer.name),
            subtitle: Text(customer.phone ?? 'بدون هاتف'),
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => CustomerDetailScreen(
                    session: widget.session,
                    customer: customer,
                  ),
                ),
              );
              await _reload();
            },
          ),
      ],
    );
  }
}
