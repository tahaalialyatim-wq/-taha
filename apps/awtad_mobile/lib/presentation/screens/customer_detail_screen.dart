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
  CurrencyCode? _paymentCurrency;
  bool _paymentCurrencyChosen = false;
  List<CustomerAccountEntry> _entries = const <CustomerAccountEntry>[];
  List<CustomerAccountBalance> _balances = const <CustomerAccountBalance>[];
  String? _openingMessage;
  String? _paymentMessage;

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
    final savedDefault = await widget.session.settings.readDefaultCurrency(
      _merchant,
    );
    if (!mounted) {
      return;
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
      if (!_paymentCurrencyChosen) {
        _paymentCurrency = _derivePaymentCurrency(balances, savedDefault);
      }
    });
  }

  /// Currencies with a positive outstanding balance for this customer.
  List<CurrencyCode> get _outstandingCurrencies {
    return _balances
        .where((balance) => balance.balanceMinorUnits > 0)
        .map((balance) => balance.currency)
        .toList(growable: false);
  }

  /// Payment currency derived from outstanding debt, then the stored default.
  ///
  /// A single outstanding currency is preselected. Multiple outstanding
  /// currencies return `null` so the user must choose explicitly. With no
  /// outstanding debt the persisted store default pre-fills the selection.
  CurrencyCode? _derivePaymentCurrency(
    List<CustomerAccountBalance> balances,
    CurrencyCode? savedDefault,
  ) {
    final positive = balances
        .where((balance) => balance.balanceMinorUnits > 0)
        .map((balance) => balance.currency)
        .toList(growable: false);
    if (positive.length == 1) {
      return positive.single;
    }
    if (positive.length > 1) {
      return null;
    }
    return savedDefault;
  }

  bool _hasEntries(CurrencyCode currency) {
    return _entries.any((entry) => entry.currency == currency);
  }

  String _newEntryId() => 'e-${DateTime.now().microsecondsSinceEpoch}';

  Future<void> _recordOpening() async {
    final minor = int.tryParse(_openingAmount.text.trim());
    if (minor == null || minor <= 0) {
      setState(() => _openingMessage = 'أدخل مبلغاً صحيحاً أكبر من صفر.');
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
      setState(() => _openingMessage = 'تم تسجيل الرصيد الافتتاحي.');
      await _reload();
    } catch (error) {
      setState(() => _openingMessage = error.toString());
    }
  }

  Future<void> _recordPayment() async {
    final minor = int.tryParse(_paymentAmount.text.trim());
    if (minor == null || minor <= 0) {
      setState(() => _paymentMessage = 'أدخل مبلغ دفعة صحيحاً أكبر من صفر.');
      return;
    }
    final currency = _paymentCurrency;
    if (currency == null) {
      setState(() => _paymentMessage = 'اختر عملة الدفعة قبل الحفظ.');
      return;
    }
    try {
      await widget.session.payments.record(
        RecordCustomerPaymentCommand(
          entryId: CustomerAccountEntryId(_newEntryId()),
          merchantId: _merchant,
          customerId: widget.customer.id,
          currency: currency,
          amount: Money(currency: currency, minorUnits: minor),
          occurredAt: DateTime.now().toUtc(),
        ),
      );
      _paymentAmount.clear();
      _paymentCurrencyChosen = false;
      setState(() => _paymentMessage = 'تم تسجيل الدفعة.');
      await _reload();
    } catch (error) {
      setState(() => _paymentMessage = error.toString());
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
          if (_openingMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_openingMessage!),
            ),
          const Divider(),
          const Text(
            'تسجيل دفعة',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          if (_outstandingCurrencies.length > 1 && _paymentCurrency == null)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('لدى العميل أرصدة بعدة عملات. اختر عملة الدفعة.'),
            ),
          DropdownButton<CurrencyCode>(
            key: const Key('payment-currency-dropdown'),
            isExpanded: true,
            hint: const Text('اختر عملة الدفعة'),
            value: _paymentCurrency,
            items: [
              for (final currency in CurrencyCode.values)
                DropdownMenuItem(
                  key: Key('payment-currency-${currency.value}'),
                  value: currency,
                  child: Text(currency.value),
                ),
            ],
            onChanged: (value) {
              if (value == null) {
                return;
              }
              setState(() {
                _paymentCurrency = value;
                _paymentCurrencyChosen = true;
              });
            },
          ),
          TextField(
            controller: _paymentAmount,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'مبلغ الدفعة (وحدات صغرى)',
              helperText: _paymentCurrency?.value,
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _recordPayment,
            child: const Text('تسجيل دفعة'),
          ),
          if (_paymentMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_paymentMessage!),
            ),
          const Divider(),
          const Text(
            'الأرصدة',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          for (final balance in _balances)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(_balanceLabel(balance)),
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
