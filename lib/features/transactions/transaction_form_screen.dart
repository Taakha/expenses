import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/finance_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/money.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/glass_button.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/glass_text_field.dart';
import '../../core/widgets/screen_header.dart';
import '../../data/models/finance_models.dart';
import '../../data/repositories/finance_repository.dart';

class TransactionFormScreen extends StatefulWidget {
  const TransactionFormScreen({
    super.key,
    this.initialType = TransactionType.expense,
    this.existing,
  });

  final TransactionType initialType;
  final FinancialTransaction? existing;

  @override
  State<TransactionFormScreen> createState() => _TransactionFormScreenState();
}

class _TransactionFormScreenState extends State<TransactionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amount;
  late final TextEditingController _description;
  late final TextEditingController _notes;
  late final TextEditingController _exchangeRate;
  late final TextEditingController _destinationAmount;
  late DateTime _date;
  late TransactionType _type;
  String? _accountId;
  String? _destinationAccountId;
  String? _category;
  String _paymentMethod = 'Cash';
  bool _busy = false;
  String? _error;
  bool _loadedDefaults = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _type = existing?.type ?? widget.initialType;
    _date = existing?.occurredAt ?? DateTime.now();
    _amount = TextEditingController(
      text: existing == null
          ? ''
          : _moneyInput(existing.amountMinor, existing.currencyCode),
    );
    _description = TextEditingController(text: existing?.description ?? '');
    _notes = TextEditingController(text: existing?.notes ?? '');
    _exchangeRate = TextEditingController(text: existing?.exchangeRate ?? '');
    _destinationAmount = TextEditingController(
      text: existing?.destinationAmountMinor == null
          ? ''
          : _moneyInput(
              existing!.destinationAmountMinor!,
              existing.destinationCurrencyCode ?? existing.currencyCode,
            ),
    );
    _accountId = existing?.accountId;
    _destinationAccountId = existing?.destinationAccountId;
    _category = existing?.category;
    _paymentMethod = existing?.paymentMethod ?? 'Cash';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadedDefaults) return;
    final accounts = context.read<FinanceController>().activeAccounts;
    if (_accountId == null && accounts.isNotEmpty) _accountId = accounts.first.id;
    if (_destinationAccountId == null && accounts.length > 1) {
      _destinationAccountId = accounts.firstWhere((item) => item.id != _accountId).id;
    }
    _loadedDefaults = true;
  }

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    _notes.dispose();
    _exchangeRate.dispose();
    _destinationAmount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final finance = context.read<FinanceController>();
    final account = _findAccount(finance.accounts, _accountId);
    if (account == null) {
      setState(() => _error = 'Create an active account before recording activity.');
      return;
    }
    final destination = _type == TransactionType.transfer
        ? _findAccount(finance.accounts, _destinationAccountId)
        : null;
    if (_type == TransactionType.transfer && destination == null) {
      setState(() => _error = 'Choose a destination account.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final now = DateTime.now();
      final transaction = FinancialTransaction(
        id: widget.existing?.id ?? FinanceRepository.createId(),
        userId: finance.userId!,
        accountId: account.id,
        type: _type,
        amountMinor: parseMinorUnits(_amount.text, account.currencyCode),
        currencyCode: account.currencyCode,
        category: _type == TransactionType.transfer
            ? 'Transfer'
            : _category ?? (_type == TransactionType.income ? 'Salary' : 'Other'),
        description: _description.text.trim(),
        occurredAt: _date,
        destinationAccountId: destination?.id,
        destinationCurrencyCode: destination?.currencyCode,
        destinationAmountMinor: destination == null
            ? null
            : destination.currencyCode == account.currencyCode
            ? parseMinorUnits(_amount.text, account.currencyCode)
            : parseMinorUnits(_destinationAmount.text, destination.currencyCode),
        exchangeRate: destination != null &&
                destination.currencyCode != account.currencyCode
            ? _exchangeRate.text.trim()
            : null,
        paymentMethod: _paymentMethod,
        notes: _notes.text.trim(),
        transferId: _type == TransactionType.transfer
            ? widget.existing?.transferId ?? FinanceRepository.createId()
            : null,
        version: widget.existing?.version ?? 1,
        createdAt: widget.existing?.createdAt ?? now,
        updatedAt: now,
      );
      await finance.saveTransaction(transaction);
      if (!mounted) return;
      showAppMessage(context, widget.existing == null ? 'Saved on this device.' : 'Transaction updated.');
      Navigator.pop(context);
    } on Object catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceController>();
    final accounts = finance.activeAccounts;
    final selectedAccount = _findAccount(accounts, _accountId);
    final selectedDestination = _findAccount(accounts, _destinationAccountId);
    final isIncome = _type == TransactionType.income;
    final categories = finance.categories
        .where(
          (category) =>
              category['type'] == (isIncome ? 'income' : 'expense') &&
              (category['is_active'] as int? ?? 1) == 1,
        )
        .map((category) => category['name']! as String)
        .toList();
    if (categories.isEmpty) {
      categories.addAll(isIncome
          ? AppConstants.incomeCategories
          : AppConstants.expenseCategories);
    }
    if (_category == null || !categories.contains(_category)) {
      _category = categories.first;
    }
    return GlassScaffold(
      padding: const EdgeInsets.symmetric(horizontal: 17),
      child: ListView(
        padding: const EdgeInsets.only(top: 9, bottom: 28),
        children: [
          ScreenHeader(
            title: widget.existing == null
                ? _type == TransactionType.income
                    ? 'Add income'
                    : _type == TransactionType.transfer
                    ? 'Transfer'
                    : 'Add expense'
                : 'Edit transaction',
            subtitle: 'Saved offline first, then synchronized securely.',
            showBack: true,
          ),
          if (accounts.isEmpty)
            GlassEmptyState(
              title: 'You need an account first',
              message: 'Create a cash, bank or mobile money account before adding activity.',
              icon: Icons.account_balance_wallet_outlined,
              action: TextButton(
                onPressed: () => Navigator.pushNamed(context, '/accounts'),
                child: const Text('Create account'),
              ),
            )
          else
            GlassContainer(
              padding: const EdgeInsets.all(16),
              radius: 21,
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SegmentedButton<TransactionType>(
                      segments: const [
                        ButtonSegment(value: TransactionType.income, label: Text('Income'), icon: Icon(Icons.south_west_rounded)),
                        ButtonSegment(value: TransactionType.expense, label: Text('Expense'), icon: Icon(Icons.north_east_rounded)),
                        ButtonSegment(value: TransactionType.transfer, label: Text('Transfer'), icon: Icon(Icons.swap_horiz_rounded)),
                      ],
                      selected: {_type},
                      onSelectionChanged: (value) {
                        setState(() {
                          _type = value.first;
                          _category = null;
                        });
                      },
                    ),
                    const SizedBox(height: 13),
                    GlassTextField(
                      controller: _amount,
                      label: 'Amount (${selectedAccount?.currencyCode ?? finance.preferredCurrency})',
                      icon: Icons.payments_outlined,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        try {
                          parseMinorUnits(value ?? '', selectedAccount?.currencyCode ?? finance.preferredCurrency);
                          return null;
                        } on FormatException catch (error) {
                          return error.message;
                        }
                      },
                    ),
                    const SizedBox(height: 11),
                    GlassTextField(
                      controller: _description,
                      label: 'Description',
                      icon: Icons.edit_note_rounded,
                      validator: (value) => Validators.required(value, 'Description'),
                    ),
                    const SizedBox(height: 11),
                    DropdownButtonFormField<String>(
                      initialValue: _accountId,
                      decoration: const InputDecoration(labelText: 'Account', prefixIcon: Icon(Icons.wallet_outlined)),
                      items: accounts
                          .map((account) => DropdownMenuItem(
                                value: account.id,
                                child: Text('${account.name} · ${account.currencyCode}'),
                              ))
                          .toList(),
                      onChanged: (value) => setState(() => _accountId = value),
                      validator: (value) => value == null ? 'Select an account' : null,
                    ),
                    if (_type == TransactionType.transfer) ...[
                      const SizedBox(height: 11),
                      DropdownButtonFormField<String>(
                        initialValue: _destinationAccountId,
                        decoration: const InputDecoration(labelText: 'To account', prefixIcon: Icon(Icons.south_west_rounded)),
                        items: accounts
                            .where((account) => account.id != _accountId)
                            .map((account) => DropdownMenuItem(
                                  value: account.id,
                                  child: Text('${account.name} · ${account.currencyCode}'),
                                ))
                            .toList(),
                        onChanged: (value) => setState(() => _destinationAccountId = value),
                        validator: (value) => value == null ? 'Choose a destination account' : null,
                      ),
                      if (selectedAccount != null &&
                          selectedDestination != null &&
                          selectedAccount.currencyCode != selectedDestination.currencyCode) ...[
                        const SizedBox(height: 11),
                        GlassTextField(
                          controller: _exchangeRate,
                          label: 'Exchange rate (destination units per source unit)',
                          icon: Icons.currency_exchange,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (value) {
                            final rate = double.tryParse(value ?? '');
                            return rate == null || rate <= 0 ? 'Enter a valid exchange rate' : null;
                          },
                        ),
                        const SizedBox(height: 11),
                        GlassTextField(
                          controller: _destinationAmount,
                          label: 'Amount received (${selectedDestination.currencyCode})',
                          icon: Icons.call_received_rounded,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (value) {
                            try {
                              parseMinorUnits(value ?? '', selectedDestination.currencyCode);
                              return null;
                            } on FormatException catch (error) {
                              return error.message;
                            }
                          },
                        ),
                      ],
                    ] else ...[
                      const SizedBox(height: 11),
                      DropdownButtonFormField<String>(
                        initialValue: categories.contains(_category) ? _category : categories.first,
                        decoration: const InputDecoration(labelText: 'Category', prefixIcon: Icon(Icons.category_outlined)),
                        items: categories.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
                        onChanged: (value) => setState(() => _category = value),
                      ),
                    ],
                    const SizedBox(height: 11),
                    DropdownButtonFormField<String>(
                      initialValue: _paymentMethod,
                      decoration: const InputDecoration(labelText: 'Payment method', prefixIcon: Icon(Icons.credit_card_outlined)),
                      items: AppConstants.paymentMethods
                          .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                          .toList(),
                      onChanged: (value) => setState(() => _paymentMethod = value ?? _paymentMethod),
                    ),
                    const SizedBox(height: 6),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_today_outlined),
                      title: const Text('Date'),
                      subtitle: Text(MaterialLocalizations.of(context).formatMediumDate(_date)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _pickDate,
                    ),
                    GlassTextField(
                      controller: _notes,
                      label: 'Notes (optional)',
                      icon: Icons.notes_outlined,
                      maxLines: 2,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 9),
                      Text(_error!, style: const TextStyle(color: AppColors.expense, fontSize: 12)),
                    ],
                    const SizedBox(height: 14),
                    GlassButton(
                      label: widget.existing == null ? 'Save ${isIncome ? 'income' : _type == TransactionType.transfer ? 'transfer' : 'expense'}' : 'Save changes',
                      icon: Icons.check_rounded,
                      onPressed: _busy ? null : _save,
                      isLoading: _busy,
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 11),
          const _OfflineHint(),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 366)),
    );
    if (picked != null) setState(() => _date = picked);
  }
}

class _OfflineHint extends StatelessWidget {
  const _OfflineHint();

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(12),
      radius: 15,
      blur: 5,
      child: Row(
        children: [
          const Icon(Icons.cloud_off_outlined, color: AppColors.tealDark, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Transfers are not counted as income or expenses. Each account keeps its own currency.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

FinancialAccount? _findAccount(
  List<FinancialAccount> accounts,
  String? id,
) {
  for (final account in accounts) {
    if (account.id == id) return account;
  }
  return null;
}

String _moneyInput(int minor, String currency) {
  final scale = currencyFractionDigits(currency);
  final multiplier = scale == 0 ? 1 : 100;
  final whole = minor ~/ multiplier;
  final fraction = minor % multiplier;
  return scale == 0 ? '$whole' : '$whole.${fraction.toString().padLeft(scale, '0')}';
}
