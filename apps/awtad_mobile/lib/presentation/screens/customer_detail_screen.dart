import 'package:awtad_retail/awtad_retail.dart';
import 'package:flutter/material.dart';

import '../../core/database/retail_session.dart';

class CustomerDetailScreen extends StatefulWidget {
  const CustomerDetailScreen({
    super.key,
    required this.session,
    required this.customer,
  });

  final RetailSession session;
  final Customer customer;

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  final _openingAmount = TextEditingController();
  final _paymentAmount = TextEditingController();
  CurrencyCode _openingCurrency = CurrencyCode.yemeniRial;
  CurrencyCode _paymentCurrency = CurrencyCode.yemeniRial;
  List<CustomerAccountEntry> _entries = const <CustomerAccountEntry>[];
  List<CustomerAccountBalance> _balances = const <CustomerAccountBalance>[];
  String? _message;

  MerchantId get _merchant => RetailSession.defaultMerchant;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _openingAmount.dispose();
    _paymentAmount.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final entries = await widget.session.ledger.getEntries(
      _merchant,
      widget.customer.id,
    );
    final balances = <CustomerAccountBalance>[];
    for (final currency in CurrencyCode.values) {
      balances.add(
        await widget.session.ledger.getBalance(
          _merchant,
          widget.customer.id,
          currency,
        ),
      );
    }
    CurrencyCode openingCurrency = _openingCurrency;
    for (final currency in CurrencyCode.values) {
      if (!entries.any((entry) => entry.currency == currency)) {
        openingCurrency = currency;
        break;
      }
    }
    setState(() {
      _entries = entries;
      _balances = balances;
      _openingCurrency = openingCurrency;
    });
  }

  bool _hasEntries(CurrencyCode currency) {
    return _entries.any((entry) => entry.currency == currency);
  }

  String _newEntryId() => 'e-${DateTime.now().microsecondsSinceEpoch}';

  Future<void> _recordOpening() async {
    final minor = int.tryParse(_openingAmount.text.trim());
    if (minor == null || minor <= 0) {
      setState(() => _message = 'أدخل مبلغاً صحيحاً أكبر من صفر.');
      return;
    }
    try {
      await widget.session.openingBalances.record(
        RecordOpeningBalanceCommand(
          entryId: CustomerAccountEntryId(_newEntryId()),
          merchantId: _merchant,
          customerId: widget.customer.id,
          currency: _openingCurrency,
          amount: Money(currency: _openingCurrency, minorUnits: minor),
          occurredAt: DateTime.now().toUtc(),
        ),
      );
      _openingAmount.clear();
      setState(() => _message = 'تم تسجيل الرصيد الافتتاحي.');
      await _reload();
    } catch (error) {
      setState(() => _message = error.toString());
    }
  }

  Future<void> _recordPayment() async {
    final minor = int.tryParse(_paymentAmount.text.trim());
    if (minor == null || minor <= 0) {
      setState(() => _message = 'أدخل مبلغ دفعة صحيحاً أكبر من صفر.');
      return;
    }
    try {
      await widget.session.payments.record(
        RecordCustomerPaymentCommand(
          entryId: CustomerAccountEntryId(_newEntryId()),
          merchantId: _merchant,
          customerId: widget.customer.id,
          currency: _paymentCurrency,
          amount: Money(currency: _paymentCurrency, minorUnits: minor),
          occurredAt: DateTime.now().toUtc(),
        ),
      );
      _paymentAmount.clear();
      setState(() => _message = 'تم تسجيل الدفعة.');
      await _reload();
    } catch (error) {
      setState(() => _message = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final canRecordOpening =
        CurrencyCode.values.any((currency) => !_hasEntries(currency));
    return Scaffold(
      appBar: AppBar(title: Text(widget.customer.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            widget.customer.phone ?? 'بدون هاتف',
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 12),
          const Text(
            'الأرصدة',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          for (final balance in _balances)
            ListTile(
              title: Text(_balanceLabel(balance)),
              subtitle: Text(balance.currency.value),
            ),
          const Divider(),
          const Text(
            'رصيد افتتاحي',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          if (canRecordOpening) ...[
            const Text('يُسجل مرة واحدة لكل عملة إذا كان الحساب فارغاً.'),
            DropdownButton<CurrencyCode>(
              isExpanded: true,
              value: _openingCurrency,
              items: [
                for (final currency in CurrencyCode.values)
                  DropdownMenuItem(
                    value: currency,
                    enabled: !_hasEntries(currency),
                    child: Text(
                      _hasEntries(currency)
                          ? '${currency.value} (موجود)'
                          : currency.value,
                    ),
                  ),
              ],
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() => _openingCurrency = value);
              },
            ),
            TextField(
              controller: _openingAmount,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'المبلغ (وحدات صغرى)',
              ),
              enabled: !_hasEntries(_openingCurrency),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _hasEntries(_openingCurrency) ? null : _recordOpening,
              child: const Text('تسجيل الرصيد الافتتاحي'),
            ),
          ] else
            const Text('لكل عملة قيود مسجلة، فلا يمكن إضافة رصيد افتتاحي.'),
          const Divider(),
          const Text(
            'تسجيل دفعة',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          DropdownButton<CurrencyCode>(
            isExpanded: true,
            value: _paymentCurrency,
            items: [
              for (final currency in CurrencyCode.values)
                DropdownMenuItem(
                  value: currency,
                  child: Text(currency.value),
                ),
            ],
            onChanged: (value) {
              if (value == null) {
                return;
              }
              setState(() => _paymentCurrency = value);
            },
          ),
          TextField(
            controller: _paymentAmount,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'مبلغ الدفعة (وحدات صغرى)',
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _recordPayment,
            child: const Text('تسجيل دفعة'),
          ),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_message!),
            ),
          const Divider(),
          const Text(
            'سجل القيود',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          if (_entries.isEmpty) const Text('لا توجد قيود بعد.'),
          for (final entry in _entries)
            ListTile(
              title: Text(_typeLabel(entry.type)),
              subtitle: Text(
                '${entry.amount.minorUnits} ${entry.currency.value}'
                '${entry.reference == null ? '' : ' · ${entry.reference}'}',
              ),
              trailing: Text(
                entry.occurredAt.toUtc().toIso8601String().split('T').first,
              ),
            ),
        ],
      ),
    );
  }

  String _balanceLabel(CustomerAccountBalance balance) {
    final magnitude =
        '${balance.balanceMinorUnits.abs()} ${balance.currency.value}';
    if (balance.balanceMinorUnits > 0) {
      return 'عليه $magnitude';
    }
    if (balance.balanceMinorUnits < 0) {
      return 'له $magnitude';
    }
    return 'تسوية $magnitude';
  }

  String _typeLabel(CustomerAccountEntryType type) {
    if (type == CustomerAccountEntryType.openingBalance) {
      return 'رصيد افتتاحي';
    }
    if (type == CustomerAccountEntryType.credit) {
      return 'آجل';
    }
    return 'دفعة';
  }
}
