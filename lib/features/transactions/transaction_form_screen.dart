import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/finance_controller.dart';
import '../../core/services/financial_calculation_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/money.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/glass_button.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/glass_text_field.dart';
import '../../core/widgets/screen_header.dart';
import '../../app/routes/route_names.dart';
import '../../data/models/finance_models.dart';
import '../../data/repositories/finance_repository.dart';
import '../accounts/wallet_editor.dart';
import '../categories/category_editor.dart';

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
  String? _categoryId;
  String _paymentMethod = 'Cash';
  bool _busy = false;
  String? _error;
  bool _loadedDefaults = false;
  final List<_ReceiptDraft> _receipts = [];
  final Set<String> _newReceiptPaths = {};
  Set<String> _originalReceiptPaths = {};
  bool _receiptsLoaded = false;
  bool _receiptsPersisted = false;

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
    _categoryId = existing?.categoryId;
    _paymentMethod = existing?.paymentMethod ?? 'Cash';
    _receiptsLoaded = existing == null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadedDefaults) return;
    final accounts = context.read<FinanceController>().activeAccounts;
    if (_accountId == null && accounts.isNotEmpty) {
      _accountId = accounts.first.id;
    }
    if (_destinationAccountId == null && accounts.length > 1) {
      _destinationAccountId = accounts
          .firstWhere((item) => item.id != _accountId)
          .id;
    }
    _loadedDefaults = true;
    if (widget.existing != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadReceipts());
    }
  }

  @override
  void dispose() {
    if (!_receiptsPersisted) {
      for (final receiptPath in _newReceiptPaths) {
        unawaited(_deleteReceiptFile(receiptPath));
      }
    }
    _amount.dispose();
    _description.dispose();
    _notes.dispose();
    _exchangeRate.dispose();
    _destinationAmount.dispose();
    super.dispose();
  }

  Future<void> _loadReceipts() async {
    try {
      final finance = context.read<FinanceController>();
      final attachments = await finance.loadTransactionReceipts(
        widget.existing!.id,
      );
      final receiptDrafts = attachments
          .map(
            (receipt) => _ReceiptDraft(
              id: receipt.id,
              localPath: receipt.localPath,
              mimeType: receipt.mimeType,
              fileSize: receipt.fileSize,
              createdAt: receipt.createdAt,
            ),
          )
          .toList();
      final legacyPath = widget.existing!.receiptPath;
      if (receiptDrafts.isEmpty && legacyPath != null) {
        final file = File(legacyPath);
        if (await file.exists()) {
          receiptDrafts.add(
            _ReceiptDraft(
              id: FinanceRepository.createId(),
              localPath: legacyPath,
              mimeType: _receiptMimeType(legacyPath),
              fileSize: await file.length(),
              createdAt: DateTime.now(),
            ),
          );
        }
      }
      if (!mounted) return;
      setState(() {
        _receipts
          ..clear()
          ..addAll(receiptDrafts);
        _originalReceiptPaths = receiptDrafts
            .map((receipt) => receipt.localPath)
            .toSet();
        _receiptsLoaded = true;
      });
    } on Object catch (error) {
      if (mounted) setState(() => _error = 'Could not load receipts: $error');
    }
  }

  Future<void> _pickReceipts() async {
    try {
      final picked = await ImagePicker().pickMultiImage();
      if (picked.isEmpty || !mounted) return;
      final drafts = <_ReceiptDraft>[];
      for (final image in picked) {
        final receipt = _ReceiptDraft(
          id: FinanceRepository.createId(),
          localPath: image.path,
          mimeType: _receiptMimeType(image.path),
          fileSize: await File(image.path).length(),
          createdAt: DateTime.now(),
          isNew: true,
        );
        drafts.add(receipt);
      }
      if (!mounted) return;
      setState(() => _receipts.addAll(drafts));
    } on Object catch (error) {
      if (mounted) setState(() => _error = 'Could not attach receipts: $error');
    }
  }

  Future<void> _save() async {
    if (!_receiptsLoaded) {
      setState(() => _error = 'Wait for existing receipts to finish loading.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    final finance = context.read<FinanceController>();
    final account = _findAccount(finance.accounts, _accountId);
    if (account == null) {
      setState(
        () => _error = 'Create an active account before recording activity.',
      );
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
      final transactionId = widget.existing?.id ?? FinanceRepository.createId();
      final receiptDrafts = await _persistReceiptDrafts(finance.userId!);
      final transaction = FinancialTransaction(
        id: transactionId,
        userId: finance.userId!,
        accountId: account.id,
        type: _type,
        amountMinor: parseMinorUnits(_amount.text, account.currencyCode),
        currencyCode: account.currencyCode,
        category: _type == TransactionType.transfer
            ? 'Transfer'
            : _category ??
                  (_type == TransactionType.income ? 'Salary' : 'Other'),
        categoryId: _type == TransactionType.transfer ? null : _categoryId,
        description: _description.text.trim(),
        occurredAt: _date,
        destinationAccountId: destination?.id,
        destinationCurrencyCode: destination?.currencyCode,
        destinationAmountMinor: destination == null
            ? null
            : destination.currencyCode == account.currencyCode
            ? parseMinorUnits(_amount.text, account.currencyCode)
            : parseMinorUnits(
                _destinationAmount.text,
                destination.currencyCode,
              ),
        exchangeRate:
            destination != null &&
                destination.currencyCode != account.currencyCode
            ? _exchangeRate.text.trim()
            : null,
        paymentMethod: _paymentMethod,
        notes: _notes.text.trim(),
        receiptPath: receiptDrafts.firstOrNull?.localPath,
        transferId: _type == TransactionType.transfer
            ? widget.existing?.transferId ?? FinanceRepository.createId()
            : null,
        version: widget.existing?.version ?? 1,
        createdAt: widget.existing?.createdAt ?? now,
        updatedAt: now,
      );
      final receipts = [
        for (final receipt in receiptDrafts)
          ReceiptAttachment(
            id: receipt.id,
            userId: finance.userId!,
            transactionId: transaction.id,
            localPath: receipt.localPath,
            mimeType: receipt.mimeType,
            fileSize: receipt.fileSize,
            createdAt: receipt.createdAt,
          ),
      ];
      await finance.saveTransaction(transaction, receipts: receipts);
      _receiptsPersisted = true;
      setState(() {
        _receipts
          ..clear()
          ..addAll(receiptDrafts);
      });
      for (final receiptPath in _originalReceiptPaths.difference(
        _receipts.map((receipt) => receipt.localPath).toSet(),
      )) {
        final file = File(receiptPath);
        if (await file.exists()) await file.delete();
      }
      if (!mounted) return;
      final openBudgets = _type == TransactionType.expense
          ? await _showBudgetFollowup(context, finance, transaction)
          : false;
      if (!mounted) return;
      if (openBudgets) {
        Navigator.pop(context);
        await Navigator.pushNamed(context, RouteNames.budgets);
        return;
      }
      showAppMessage(
        context,
        widget.existing == null
            ? 'Saved on this device.'
            : 'Transaction updated.',
      );
      Navigator.pop(context);
    } on Object catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _showBudgetFollowup(
    BuildContext context,
    FinanceController finance,
    FinancialTransaction transaction,
  ) async {
    final budget = _matchingBudget(
      finance.budgets,
      currencyCode: transaction.currencyCode,
      accountId: transaction.accountId,
      category: transaction.category,
      categoryId: transaction.categoryId,
      date: transaction.occurredAt,
    );
    var title = 'No matching budget';
    var message =
        'This expense was saved. Create a ${transaction.category} budget to track future spending.';
    var offerCreate = true;
    if (budget != null) {
      final progress = finance.budgetProgress(budget);
      if (progress.remainingMinor >= 0) return false;
      title = 'Budget exceeded';
      message =
          'You have spent ${formatMinorUnits(progress.spentMinor, budget.currencyCode)} against your ${formatMinorUnits(budget.limitMinor, budget.currencyCode)} ${budget.name} budget. This expense was saved.';
      offerCreate = false;
    }
    if (!context.mounted) return false;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(offerCreate ? 'Not now' : 'Got it'),
              ),
              if (offerCreate)
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Create budget'),
                ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final finance = context.read<FinanceController>();
    final (snapshot, preferredCurrency) = context
        .select<FinanceController, (FinanceSnapshot?, String)>(
          (finance) => (finance.snapshot, finance.preferredCurrency),
        );
    final accounts = (snapshot?.accounts ?? const <FinancialAccount>[])
        .where((account) => !account.isArchived)
        .toList();
    final selectedAccount = _findAccount(accounts, _accountId);
    final selectedDestination = _findAccount(accounts, _destinationAccountId);
    final matchingBudget =
        _type == TransactionType.expense && selectedAccount != null
        ? _matchingBudget(
            context.read<FinanceController>().budgets,
            currencyCode: selectedAccount.currencyCode,
            accountId: selectedAccount.id,
            category: _category ?? 'Other',
            categoryId: _categoryId,
            date: _date,
          )
        : null;
    final isIncome = _type == TransactionType.income;
    final categoryRows =
        (snapshot?.categories ?? const <Map<String, Object?>>[])
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
    if (_category == null || !categories.contains(_category)) {
      _category = categories.first;
    }
    if (_categoryId == null && categoryRows.isNotEmpty) {
      _categoryId = categoryRows
          .where((category) => category['name'] == _category)
          .map((category) => category['id']! as String)
          .firstOrNull;
    }
    if (_categoryId != null) {
      final categoryForId = categoryRows
          .where((category) => category['id'] == _categoryId)
          .firstOrNull;
      if (categoryForId != null) {
        _category = categoryForId['name']! as String;
      }
    }
    final selectedCategoryRow = categoryRows
        .where(
          (category) =>
              category['id'] == _categoryId || category['name'] == _category,
        )
        .firstOrNull;
    final walletField = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _accountId,
                decoration: const InputDecoration(
                  labelText: 'Wallet',
                  prefixIcon: Icon(Icons.wallet_outlined),
                ),
                items: accounts
                    .map(
                      (account) => DropdownMenuItem(
                        value: account.id,
                        child: Text(
                          '${account.name} · ${formatMinorUnits(finance.accountBalance(account), account.currencyCode)}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _accountId = value),
                validator: (value) =>
                    value == null ? 'Select a wallet' : null,
              ),
            ),
            IconButton(
              tooltip: 'Add wallet',
              onPressed: _busy ? null : () => _addWallet(context),
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
        if (selectedAccount != null) ...[
          const SizedBox(height: 5),
          _WalletBalancePreview(
            account: selectedAccount,
            availableMinor: finance.accountBalance(selectedAccount),
            transactionType: _type,
            amountMinor: _previewAmount(
              _amount.text,
              selectedAccount.currencyCode,
            ),
          ),
        ],
      ],
    );
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
                        ButtonSegment(
                          value: TransactionType.income,
                          label: Text('Income'),
                          icon: Icon(Icons.south_west_rounded),
                        ),
                        ButtonSegment(
                          value: TransactionType.expense,
                          label: Text('Expense'),
                          icon: Icon(Icons.north_east_rounded),
                        ),
                        ButtonSegment(
                          value: TransactionType.transfer,
                          label: Text('Transfer'),
                          icon: Icon(Icons.swap_horiz_rounded),
                        ),
                      ],
                      selected: {_type},
                      onSelectionChanged: (value) {
                        setState(() {
                          _type = value.first;
                          _category = null;
                          _categoryId = null;
                        });
                      },
                    ),
                    const SizedBox(height: 13),
                    GlassTextField(
                      controller: _amount,
                      label:
                          'Amount (${selectedAccount?.currencyCode ?? preferredCurrency})',
                      icon: Icons.payments_outlined,
                      onChanged: (_) => setState(() {}),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (value) {
                        try {
                          parseMinorUnits(
                            value ?? '',
                            selectedAccount?.currencyCode ?? preferredCurrency,
                          );
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
                      validator: (value) =>
                          Validators.required(value, 'Description'),
                    ),
                    const SizedBox(height: 11),
                    if (_type == TransactionType.transfer) ...[
                      walletField,
                      const SizedBox(height: 11),
                      DropdownButtonFormField<String>(
                        initialValue: _destinationAccountId,
                        decoration: const InputDecoration(
                          labelText: 'To account',
                          prefixIcon: Icon(Icons.south_west_rounded),
                        ),
                        items: accounts
                            .where((account) => account.id != _accountId)
                            .map(
                              (account) => DropdownMenuItem(
                                value: account.id,
                                child: Text(
                                  '${account.name} · ${account.currencyCode}',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _destinationAccountId = value),
                        validator: (value) => value == null
                            ? 'Choose a destination account'
                            : null,
                      ),
                      if (selectedAccount != null &&
                          selectedDestination != null &&
                          selectedAccount.currencyCode !=
                              selectedDestination.currencyCode) ...[
                        const SizedBox(height: 11),
                        GlassTextField(
                          controller: _exchangeRate,
                          label: 'Exchange rate (destination units per source unit)',
                          icon: Icons.currency_exchange,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (value) {
                            final rate = double.tryParse(value ?? '');
                            return rate == null || rate <= 0
                                ? 'Enter a valid exchange rate'
                                : null;
                          },
                        ),
                        const SizedBox(height: 11),
                        GlassTextField(
                          controller: _destinationAmount,
                          label:
                              'Amount received (${selectedDestination.currencyCode})',
                          icon: Icons.call_received_rounded,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (value) {
                            try {
                              parseMinorUnits(
                                value ?? '',
                                selectedDestination.currencyCode,
                              );
                              return null;
                            } on FormatException catch (error) {
                              return error.message;
                            }
                          },
                        ),
                      ],
                    ] else ...[
                      const SizedBox(height: 11),
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
                                prefixIcon: Icon(Icons.category_outlined),
                              ),
                              items: categories.map((item) {
                                final categoryRow = categoryRows
                                    .where(
                                      (category) => category['name'] == item,
                                    )
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
                                    .where(
                                      (category) => category['name'] == value,
                                    )
                                    .map(
                                      (category) => category['id']! as String,
                                    )
                                    .firstOrNull;
                              }),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Add category',
                            onPressed: _busy
                                ? null
                                : () => _addCategory(
                                    context,
                                    isIncome ? 'income' : 'expense',
                                  ),
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                          if (selectedCategoryRow != null)
                            IconButton(
                              tooltip: 'Edit category',
                              onPressed: _busy
                                  ? null
                                  : () => _editCategory(
                                      context,
                                      selectedCategoryRow,
                                    ),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                        ],
                      ),
                      if (_type == TransactionType.expense) ...[
                        const SizedBox(height: 8),
                        _BudgetLinkPreview(
                          budget: matchingBudget,
                          progress: matchingBudget == null
                              ? null
                              : context
                                    .read<FinanceController>()
                                    .budgetProgress(matchingBudget),
                          amountMinor: selectedAccount == null
                              ? null
                              : _previewAmount(
                                  _amount.text,
                                  selectedAccount.currencyCode,
                                ),
                        ),
                      ],
                      const SizedBox(height: 11),
                      walletField,
                    ],
                    const SizedBox(height: 11),
                    DropdownButtonFormField<String>(
                      initialValue: _paymentMethod,
                      decoration: const InputDecoration(
                        labelText: 'Payment method',
                        prefixIcon: Icon(Icons.credit_card_outlined),
                      ),
                      items: AppConstants.paymentMethods
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(item),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(
                        () => _paymentMethod = value ?? _paymentMethod,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_today_outlined),
                      title: const Text('Date'),
                      subtitle: Text(
                        MaterialLocalizations.of(context)
                            .formatMediumDate(_date),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _pickDate,
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: _busy || !_receiptsLoaded
                            ? null
                            : _pickReceipts,
                        icon: const Icon(Icons.attach_file_rounded),
                        label: Text(
                          _receipts.isEmpty
                              ? 'Attach receipts'
                              : 'Receipts (${_receipts.length})',
                        ),
                      ),
                    ),
                    if (!_receiptsLoaded) const LinearProgressIndicator(),
                    if (_receipts.isNotEmpty)
                      SizedBox(
                        height: 104,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _receipts.length,
                          itemBuilder: (context, index) {
                            final receipt = _receipts[index];
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: SizedBox(
                                width: 92,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.file(
                                        File(receipt.localPath),
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stack) =>
                                            const Icon(
                                              Icons.broken_image_outlined,
                                            ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 2,
                                      right: 2,
                                      child: IconButton.filledTonal(
                                        tooltip: 'Remove receipt',
                                        onPressed: _busy
                                            ? null
                                            : () => setState(
                                                () => _receipts.removeAt(index),
                                              ),
                                        icon: const Icon(Icons.close, size: 15),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    GlassTextField(
                      controller: _notes,
                      label: 'Notes (optional)',
                      icon: Icons.notes_outlined,
                      maxLines: 2,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 9),
                      Text(
                        _error!,
                        style: const TextStyle(
                          color: AppColors.expense,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    GlassButton(
                      label: widget.existing == null
                          ? 'Save ${isIncome
                                ? 'income'
                                : _type == TransactionType.transfer
                                ? 'transfer'
                                : 'expense'}'
                          : 'Save changes',
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

  Future<void> _addCategory(BuildContext context, String type) async {
    final finance = context.read<FinanceController>();
    final id = await showCategoryEditor(context, initialType: type);
    if (id == null || !context.mounted || !mounted) return;
    final category = finance.categories
        .where((item) => item['id'] == id)
        .firstOrNull;
    if (category == null) return;
    setState(() {
      _categoryId = id;
      _category = category['name']! as String;
    });
  }

  Future<void> _addWallet(BuildContext context) async {
    final finance = context.read<FinanceController>();
    final account = await showWalletEditor(context);
    if (account == null || !context.mounted || !mounted) return;
    setState(() {
      _accountId = account.id;
      if (_type == TransactionType.transfer &&
          _destinationAccountId == account.id) {
        _destinationAccountId = finance.activeAccounts
            .where((item) => item.id != account.id)
            .firstOrNull
            ?.id;
      }
    });
  }

  Future<void> _editCategory(
    BuildContext context,
    Map<String, Object?> category,
  ) async {
    final finance = context.read<FinanceController>();
    final id = await showCategoryEditor(context, existing: category);
    if (id == null || !context.mounted || !mounted) return;
    final updated = finance.categories
        .where((item) => item['id'] == id)
        .firstOrNull;
    if (updated == null) return;
    setState(() {
      _categoryId = id;
      _category = updated['name']! as String;
    });
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

  Future<List<_ReceiptDraft>> _persistReceiptDrafts(String uid) async {
    if (_receipts.isEmpty) return [];
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory(
      path.join(documents.path, 'moneywise', 'receipts', uid),
    );
    await directory.create(recursive: true);
    final persisted = <_ReceiptDraft>[];
    for (final receipt in _receipts) {
      if (!receipt.isNew) {
        persisted.add(receipt);
        continue;
      }
      final destinationPath = path.join(
        directory.path,
        '${receipt.id}${path.extension(receipt.localPath)}',
      );
      final destination = File(destinationPath);
      _newReceiptPaths.add(destinationPath);
      if (await destination.exists()) await destination.delete();
      await File(receipt.localPath).copy(destinationPath);
      persisted.add(
        _ReceiptDraft(
          id: receipt.id,
          localPath: destinationPath,
          mimeType: receipt.mimeType,
          fileSize: await destination.length(),
          createdAt: receipt.createdAt,
        ),
      );
    }
    return persisted;
  }

  static Future<void> _deleteReceiptFile(String receiptPath) async {
    final file = File(receiptPath);
    if (await file.exists()) await file.delete();
  }
}

class _ReceiptDraft {
  const _ReceiptDraft({
    required this.id,
    required this.localPath,
    required this.mimeType,
    required this.fileSize,
    required this.createdAt,
    this.isNew = false,
  });

  final String id;
  final String localPath;
  final String mimeType;
  final int fileSize;
  final DateTime createdAt;
  final bool isNew;
}

String _receiptMimeType(String receiptPath) {
  return switch (path.extension(receiptPath).toLowerCase()) {
    '.png' => 'image/png',
    '.gif' => 'image/gif',
    '.webp' => 'image/webp',
    '.heic' => 'image/heic',
    '.heif' => 'image/heif',
    _ => 'image/jpeg',
  };
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
          const Icon(
            Icons.cloud_off_outlined,
            color: AppColors.tealDark,
            size: 18,
          ),
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

FinancialAccount? _findAccount(List<FinancialAccount> accounts, String? id) {
  for (final account in accounts) {
    if (account.id == id) return account;
  }
  return null;
}

FinancialBudget? _matchingBudget(
  List<FinancialBudget> budgets, {
  required String currencyCode,
  required String accountId,
  required String category,
  required String? categoryId,
  required DateTime date,
}) {
  final matching =
      budgets.where((budget) {
        final budgetEnd = DateTime(
          budget.endDate.year,
          budget.endDate.month,
          budget.endDate.day,
          23,
          59,
          59,
          999,
        );
        return !budget.isArchived &&
            budget.currencyCode == currencyCode &&
            !date.isBefore(budget.startDate) &&
            !date.isAfter(budgetEnd) &&
            (budget.accountId == null || budget.accountId == accountId) &&
            (budget.categoryIds.isEmpty ||
                budget.categoryIds.contains(categoryId ?? category) ||
                budget.categoryIds.contains(category));
      }).toList()..sort((left, right) {
        final leftPriority =
            (left.accountId == null ? 0 : 2) +
            (left.categoryIds.isEmpty ? 0 : 1);
        final rightPriority =
            (right.accountId == null ? 0 : 2) +
            (right.categoryIds.isEmpty ? 0 : 1);
        final priorityOrder = rightPriority.compareTo(leftPriority);
        if (priorityOrder != 0) return priorityOrder;
        final dateOrder = (left.createdAt ?? DateTime(1970)).compareTo(
          right.createdAt ?? DateTime(1970),
        );
        return dateOrder != 0 ? dateOrder : left.id.compareTo(right.id);
      });
  return matching.firstOrNull;
}

class _BudgetLinkPreview extends StatelessWidget {
  const _BudgetLinkPreview({
    required this.budget,
    required this.progress,
    required this.amountMinor,
  });

  final FinancialBudget? budget;
  final BudgetProgress? progress;
  final int? amountMinor;

  @override
  Widget build(BuildContext context) {
    final budget = this.budget;
    final progress = this.progress;
    final projectedSpent = progress == null
        ? null
        : progress.spentMinor + (amountMinor ?? 0);
    final projectedPercent = projectedSpent == null || budget == null
        ? null
        : budget.limitMinor <= 0
        ? 0.0
        : projectedSpent * 100 / budget.limitMinor;
    return GlassContainer(
      padding: const EdgeInsets.all(11),
      radius: 14,
      blur: 5,
      child: Row(
        children: [
          Icon(
            budget == null
                ? Icons.info_outline_rounded
                : Icons.pie_chart_outline_rounded,
            color: AppColors.tealDark,
            size: 19,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  budget == null
                      ? 'No matching budget'
                      : 'Linked budget: ${budget.name}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  budget == null
                      ? 'This expense will save normally without a budget.'
                      : '${progress!.usageLabel} used · '
                            '${formatMinorUnits(progress.spentMinor, budget.currencyCode)} spent · '
                            '${formatMinorUnits(progress.remainingMinor, budget.currencyCode)} left',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (budget != null &&
                    progress != null &&
                    amountMinor != null &&
                    amountMinor! > 0) ...[
                  const SizedBox(height: 2),
                  Text(
                    'After this expense: ${_formatPercent(projectedPercent!)} used · '
                    '${formatMinorUnits(projectedSpent!, budget.currencyCode)} spent · '
                    '${formatMinorUnits(budget.limitMinor - projectedSpent, budget.currencyCode)} left',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WalletBalancePreview extends StatelessWidget {
  const _WalletBalancePreview({
    required this.account,
    required this.availableMinor,
    required this.transactionType,
    required this.amountMinor,
  });

  final FinancialAccount account;
  final int availableMinor;
  final TransactionType transactionType;
  final int? amountMinor;

  @override
  Widget build(BuildContext context) {
    final balanceAfter = amountMinor == null
        ? null
        : transactionType == TransactionType.income
        ? availableMinor + amountMinor!
        : availableMinor - amountMinor!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Available: ${formatMinorUnits(availableMinor, account.currencyCode)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          if (balanceAfter != null)
            Text(
              'After: ${formatMinorUnits(balanceAfter, account.currencyCode)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}

int? _previewAmount(String input, String currency) {
  try {
    return parseMinorUnits(input, currency);
  } on FormatException {
    return null;
  }
}

String _formatPercent(double value) {
  final formatted = value.toStringAsFixed(1);
  return formatted.endsWith('.0')
      ? formatted.substring(0, formatted.length - 2)
      : formatted;
}

String _moneyInput(int minor, String currency) {
  final scale = currencyFractionDigits(currency);
  final multiplier = scale == 0 ? 1 : 100;
  final whole = minor ~/ multiplier;
  final fraction = minor % multiplier;
  return scale == 0
      ? '$whole'
      : '$whole.${fraction.toString().padLeft(scale, '0')}';
}
