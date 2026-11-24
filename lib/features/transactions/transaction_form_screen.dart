import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
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

  @override
  Widget build(BuildContext context) {
    final (snapshot, preferredCurrency) = context
        .select<FinanceController, (FinanceSnapshot?, String)>(
          (finance) => (finance.snapshot, finance.preferredCurrency),
        );
    final accounts = (snapshot?.accounts ?? const <FinancialAccount>[])
        .where((account) => !account.isArchived)
        .toList();
    final selectedAccount = _findAccount(accounts, _accountId);
    final selectedDestination = _findAccount(accounts, _destinationAccountId);
    final isIncome = _type == TransactionType.income;
    final categories = (snapshot?.categories ?? const <Map<String, Object?>>[])
        .where(
          (category) =>
              category['type'] == (isIncome ? 'income' : 'expense') &&
              (category['is_active'] as int? ?? 1) == 1,
        )
        .map((category) => category['name']! as String)
        .toList();
    if (categories.isEmpty) {
      categories.addAll(
        isIncome
            ? AppConstants.incomeCategories
            : AppConstants.expenseCategories,
      );
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
                        });
                      },
                    ),
                    const SizedBox(height: 13),
                    GlassTextField(
                      controller: _amount,
                      label:
                          'Amount (${selectedAccount?.currencyCode ?? preferredCurrency})',
                      icon: Icons.payments_outlined,
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
                    DropdownButtonFormField<String>(
                      initialValue: _accountId,
                      decoration: const InputDecoration(
                        labelText: 'Account',
                        prefixIcon: Icon(Icons.wallet_outlined),
                      ),
                      items: accounts
                          .map(
                            (account) => DropdownMenuItem(
                              value: account.id,
                              child: Text(
                                '${account.name} · ${account.currencyCode}',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() => _accountId = value),
                      validator: (value) =>
                          value == null ? 'Select an account' : null,
                    ),
                    if (_type == TransactionType.transfer) ...[
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
                      DropdownButtonFormField<String>(
                        initialValue: categories.contains(_category)
                            ? _category
                            : categories.first,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          prefixIcon: Icon(Icons.category_outlined),
                        ),
                        items: categories
                            .map(
                              (item) => DropdownMenuItem(
                                value: item,
                                child: Text(item),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setState(() => _category = value),
                      ),
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

String _moneyInput(int minor, String currency) {
  final scale = currencyFractionDigits(currency);
  final multiplier = scale == 0 ? 1 : 100;
  final whole = minor ~/ multiplier;
  final fraction = minor % multiplier;
  return scale == 0
      ? '$whole'
      : '$whole.${fraction.toString().padLeft(scale, '0')}';
}
