import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/app_icons.dart';
import '../../core/services/finance_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/glass_container.dart';
import '../../data/models/finance_models.dart';
import '../../data/repositories/finance_repository.dart';
import '../accounts/wallet_editor.dart';
import '../categories/category_editor.dart';

Future<void> showQuickAddTransaction(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const QuickAddSheet(),
  );
}

class QuickAddSheet extends StatefulWidget {
  const QuickAddSheet({super.key});

  @override
  State<QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends State<QuickAddSheet> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  TransactionType _type = TransactionType.expense;
  String? _accountId;
  String? _destinationAccountId;
  String? _category;
  String? _categoryId;
  DateTime _date = DateTime.now();
  bool _busy = false;
  bool _moreDetails = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final finance = context.read<FinanceController>();
    final accounts = finance.activeAccounts;
    if (accounts.isEmpty) {
      setState(
        () => _error = 'Create an active account before recording activity.',
      );
      return;
    }
    final account = accounts.where((item) => item.id == _accountId).firstOrNull;
    if (account == null) {
      setState(() => _error = 'Choose an account.');
      return;
    }
    final destination = _type == TransactionType.transfer
        ? accounts.where((item) => item.id == _destinationAccountId).firstOrNull
        : null;
    if (_type == TransactionType.transfer &&
        (destination == null || destination.id == account.id)) {
      setState(() => _error = 'Choose a different destination account.');
      return;
    }

    int amount;
    try {
      amount = parseMinorUnits(_amount.text, account.currencyCode);
    } on FormatException catch (error) {
      setState(() => _error = error.message);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final now = DateTime.now();
      final id = FinanceRepository.createId();
      final category = _type == TransactionType.transfer
          ? 'Transfer'
          : _category ?? (_type == TransactionType.income ? 'Salary' : 'Other');
      final transaction = FinancialTransaction(
        id: id,
        userId: finance.userId!,
        accountId: account.id,
        type: _type,
        amountMinor: amount,
        currencyCode: account.currencyCode,
        category: category,
        categoryId: _type == TransactionType.transfer ? null : _categoryId,
        description: _note.text.trim().isEmpty ? category : _note.text.trim(),
        occurredAt: _date,
        destinationAccountId: destination?.id,
        destinationCurrencyCode: destination?.currencyCode,
        destinationAmountMinor: destination == null
            ? null
            : destination.currencyCode == account.currencyCode
            ? amount
            : null,
        paymentMethod: 'Cash',
        notes: _note.text.trim(),
        transferId: _type == TransactionType.transfer
            ? FinanceRepository.createId()
            : null,
        createdAt: now,
        updatedAt: now,
      );
      final preferences = context.read<SharedPreferences>();
      await finance.saveTransaction(transaction);
      await preferences.setString('moneywise.lastAccountId', account.id);
      await preferences.setString('moneywise.lastCategory', category);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: const Text('Transaction saved'),
            action: SnackBarAction(
              label: 'Undo',
              textColor: Colors.white,
              onPressed: () => finance.deleteTransaction(id),
            ),
          ),
        );
    } on Object catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addCategory(String type) async {
    final id = await showCategoryEditor(context, initialType: type);
    if (id == null || !mounted) return;
    final category = context
        .read<FinanceController>()
        .categories
        .where((item) => item['id'] == id)
        .firstOrNull;
    if (category == null) return;
    setState(() {
      _categoryId = id;
      _category = category['name']! as String;
    });
  }

  Future<void> _editCategory(Map<String, Object?> category) async {
    final id = await showCategoryEditor(context, existing: category);
    if (id == null || !mounted) return;
    final updated = context
        .read<FinanceController>()
        .categories
        .where((item) => item['id'] == id)
        .firstOrNull;
    if (updated == null) return;
    setState(() {
      _categoryId = id;
      _category = updated['name']! as String;
    });
  }

  Future<void> _addWallet() async {
    final account = await showWalletEditor(context);
    if (account == null || !mounted) return;
    setState(() {
      _accountId = account.id;
      if (_type == TransactionType.transfer &&
          _destinationAccountId == account.id) {
        _destinationAccountId = context
            .read<FinanceController>()
            .activeAccounts
            .where((item) => item.id != account.id)
            .firstOrNull
            ?.id;
      }
    });
  }

  int? _tryParseAmount(String input, String currency) {
    try {
      return parseMinorUnits(input, currency);
    } on FormatException {
      return null;
    }
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (selected != null && mounted) setState(() => _date = selected);
  }

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceController>();
    final accounts = finance.activeAccounts;
    final preferences = context.read<SharedPreferences>();

    if (_accountId == null && accounts.isNotEmpty) {
      final lastId = preferences.getString('moneywise.lastAccountId');
      _accountId = accounts.any((item) => item.id == lastId)
          ? lastId
          : accounts.first.id;
    }
    if (_destinationAccountId == null && accounts.length > 1) {
      _destinationAccountId = accounts
          .where((item) => item.id != _accountId)
          .firstOrNull
          ?.id;
    }

    final isIncome = _type == TransactionType.income;
    final categoryRows = finance.categories
        .where(
          (category) =>
              category['type'] == (isIncome ? 'income' : 'expense') &&
              (category['is_active'] as int? ?? 1) == 1,
        )
        .toList();
    final categories = categoryRows.isEmpty
        ? isIncome
              ? AppConstants.incomeCategories
              : AppConstants.expenseCategories
        : categoryRows.map((category) => category['name']! as String).toList();
    final lastCategory = preferences.getString('moneywise.lastCategory');
    if (_type != TransactionType.transfer &&
        (_category == null ||
            (categories.contains(lastCategory) && _category == 'Other'))) {
      _category = categories.contains(lastCategory)
          ? lastCategory
          : categories.first;
    }
    if (_categoryId == null && categoryRows.isNotEmpty) {
      _categoryId = categoryRows
          .where((category) => category['name'] == _category)
          .map((category) => category['id']! as String)
          .firstOrNull;
    }
    final selectedCategoryRow = categoryRows
        .where(
          (category) =>
              category['id'] == _categoryId || category['name'] == _category,
        )
        .firstOrNull;
    final account = accounts.where((item) => item.id == _accountId).firstOrNull;
    final availableBalance = account == null
        ? null
        : finance.accountBalance(account);
    final amountPreview = account == null
        ? null
        : _tryParseAmount(_amount.text, account.currencyCode);
    final balanceAfter = availableBalance == null || amountPreview == null
        ? null
        : _type == TransactionType.income
        ? availableBalance + amountPreview
        : availableBalance - amountPreview;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: GlassContainer(
        margin: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        radius: 24,
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.lightText.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              Text(
                'Quick add transaction',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 14),
              SegmentedButton<TransactionType>(
                segments: const [
                  ButtonSegment(
                    value: TransactionType.expense,
                    label: Text('Expense'),
                    icon: Icon(AppIcons.expense),
                  ),
                  ButtonSegment(
                    value: TransactionType.income,
                    label: Text('Income'),
                    icon: Icon(AppIcons.income),
                  ),
                  ButtonSegment(
                    value: TransactionType.transfer,
                    label: Text('Transfer'),
                    icon: Icon(AppIcons.transfer),
                  ),
                ],
                selected: {_type},
                showSelectedIcon: false,
                onSelectionChanged: (values) {
                  setState(() {
                    _type = values.first;
                    _category = null;
                    _categoryId = null;
                  });
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _amount,
                onChanged: (_) => setState(() {}),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                autofocus: true,
                style: Theme.of(context).textTheme.headlineMedium,
                decoration: InputDecoration(
                  labelText: 'Amount',
                  prefixText: '${account?.currencyCode ?? 'UGX'} ',
                  prefixIcon: Icon(
                    AppIcons.cashFlow,
                    color: _type == TransactionType.income
                        ? AppColors.income
                        : AppColors.expense,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              if (_type != TransactionType.transfer)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: categories.contains(_category)
                            ? _category
                            : categories.first,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          prefixIcon: Icon(AppIcons.category),
                        ),
                        items: categories.map((item) {
                          final categoryRow = categoryRows
                              .where((category) => category['name'] == item)
                              .firstOrNull;
                          return DropdownMenuItem(
                                value: item,
                                child: Row(
                                  children: [
                                    Icon(
                                      categoryIcon(
                                        categoryRow?['icon'] as String?,
                                      ),
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(item),
                                  ],
                                ),
                              );
                        }).toList(),
                        onChanged: (value) => setState(() {
                          _category = value;
                          _categoryId = categoryRows
                              .where((category) => category['name'] == value)
                              .map((category) => category['id']! as String)
                              .firstOrNull;
                        }),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Add category',
                      onPressed: _busy
                          ? null
                          : () => _addCategory(isIncome ? 'income' : 'expense'),
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                    if (selectedCategoryRow != null)
                      IconButton(
                        tooltip: 'Edit category',
                        onPressed: _busy
                            ? null
                            : () => _editCategory(selectedCategoryRow),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                  ],
                )
              else
                DropdownButtonFormField<String>(
                  initialValue: _destinationAccountId,
                  decoration: const InputDecoration(
                    labelText: 'Destination account',
                    prefixIcon: Icon(AppIcons.accountBank),
                  ),
                  items: accounts
                      .where((item) => item.id != _accountId)
                      .map(
                        (item) => DropdownMenuItem(
                          value: item.id,
                          child: Text(item.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _destinationAccountId = value),
                ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _accountId,
                      decoration: InputDecoration(
                        labelText: _type == TransactionType.transfer
                            ? 'From wallet'
                            : 'Wallet',
                        prefixIcon: Icon(AppIcons.accountCash),
                      ),
                      items: accounts
                          .map(
                            (item) => DropdownMenuItem(
                              value: item.id,
                              child: Text(
                                '${item.name} · ${formatMinorUnits(finance.accountBalance(item), item.currencyCode)}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() => _accountId = value),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Add wallet',
                    onPressed: _busy ? null : _addWallet,
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
              if (account != null)
                Padding(
                  padding: const EdgeInsets.only(top: 5, left: 3),
                  child: Text(
                    'Available: ${formatMinorUnits(availableBalance!, account.currencyCode)}'
                    '${balanceAfter == null ? '' : ' · After: ${formatMinorUnits(balanceAfter, account.currencyCode)}'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => setState(() => _moreDetails = !_moreDetails),
                icon: Icon(
                  _moreDetails
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                ),
                label: const Text('More details'),
              ),
              if (_moreDetails) ...[
                TextField(
                  controller: _note,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                    prefixIcon: Icon(AppIcons.receipt),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(AppIcons.period),
                  label: Text(
                    '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}',
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(color: AppColors.expense)),
              ],
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: _busy ? null : _save,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(AppIcons.contribute),
                label: Text(_busy ? 'Saving...' : 'Save transaction'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
