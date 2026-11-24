import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/finance_controller.dart';
import '../../core/services/financial_calculation_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/glass_text_field.dart';
import '../../core/widgets/screen_header.dart';
import '../../data/models/finance_models.dart';
import '../../shared/components/transaction_tile.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final _search = TextEditingController();
  final _scrollController = ScrollController();
  static const _pageSize = 40;
  final List<FinancialTransaction> _items = [];
  String _filter = 'All';
  String _sort = 'Newest first';
  String? _category;
  String? _accountId;
  DateTime? _from;
  DateTime? _through;
  Timer? _searchDebounce;
  Object? _observedSnapshot;
  FinancialSummary? _summary;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _exporting = false;
  String? _error;
  int _request = 0;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _search.dispose();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.extentAfter < 500) {
      _loadMore();
    }
  }

  String? get _typeFilter => switch (_filter) {
    'Income' => TransactionType.income.name,
    'Expenses' => TransactionType.expense.name,
    'Transfers' => TransactionType.transfer.name,
    _ => null,
  };

  Future<void> _reload() async {
    final request = ++_request;
    final finance = context.read<FinanceController>();
    setState(() {
      _items.clear();
      _summary = null;
      _loading = true;
      _loadingMore = false;
      _hasMore = true;
      _error = null;
    });
    try {
      final pageFuture = finance.loadTransactionPage(
        pageSize: _pageSize,
        search: _search.text,
        accountId: _accountId,
        category: _category,
        type: _typeFilter,
        from: _from,
        through: _through,
        ascending: _sort == 'Oldest first',
      );
      final summaryFuture = finance.summaryFor(
        search: _search.text,
        accountId: _accountId,
        category: _category,
        type: _typeFilter,
        from: _from,
        through: _through,
      );
      final page = await pageFuture;
      final summary = await summaryFuture;
      if (!mounted || request != _request) return;
      setState(() {
        _items.addAll(page.transactions);
        _summary = summary;
        _hasMore = page.hasMore;
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted || request != _request) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || !_hasMore || _items.isEmpty) return;
    final request = _request;
    final last = _items.last;
    setState(() => _loadingMore = true);
    try {
      final page = await context.read<FinanceController>().loadTransactionPage(
        pageSize: _pageSize,
        beforeDate: last.occurredAt.millisecondsSinceEpoch,
        beforeId: last.id,
        search: _search.text,
        accountId: _accountId,
        category: _category,
        type: _typeFilter,
        from: _from,
        through: _through,
        ascending: _sort == 'Oldest first',
      );
      if (!mounted || request != _request) return;
      setState(() {
        _items.addAll(page.transactions);
        _hasMore = page.hasMore;
        _loadingMore = false;
      });
    } on Object catch (error) {
      if (!mounted || request != _request) return;
      setState(() {
        _error = error.toString();
        _loadingMore = false;
      });
    }
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final dates = await showDateRangePicker(
      context: context,
      firstDate: DateTime(1900),
      lastDate: now.add(const Duration(days: 366)),
      initialDateRange: _from == null || _through == null
          ? null
          : DateTimeRange(start: _from!, end: _through!),
    );
    if (dates == null || !mounted) return;
    setState(() {
      _from = DateTime(dates.start.year, dates.start.month, dates.start.day);
      _through = DateTime(
        dates.end.year,
        dates.end.month,
        dates.end.day,
        23,
        59,
        59,
        999,
      );
    });
    await _reload();
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final path = await context
          .read<FinanceController>()
          .exportTransactionsCsv(
            search: _search.text,
            accountId: _accountId,
            category: _category,
            type: _typeFilter,
            from: _from,
            through: _through,
          );
      if (mounted) showAppMessage(context, 'CSV exported to $path');
    } on Object catch (error) {
      if (mounted) {
        showAppMessage(context, 'Export failed: $error', isError: true);
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceController>();
    if (!identical(_observedSnapshot, finance.snapshot)) {
      _observedSnapshot = finance.snapshot;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && finance.userId != null) _reload();
      });
    }
    final categories = finance.categories
        .map((category) => category['name']! as String)
        .toSet()
        .toList()
      ..sort();

    final grouped = <DateTime, List<FinancialTransaction>>{};
    for (final item in _items) {
      final key = DateTime(
        item.occurredAt.year,
        item.occurredAt.month,
        item.occurredAt.day,
      );
      grouped.putIfAbsent(key, () => []).add(item);
    }
    final accountNames = {
      for (final account in finance.accounts) account.id: account.name,
    };
    final summary =
        _summary ??
        const FinancialSummary(
          incomeByCurrency: {},
          expensesByCurrency: {},
          balanceByCurrency: {},
        );

    return GlassScaffold(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: ScreenHeader(
              title: 'Transactions',
              subtitle: 'Income, expenses and transfers in one place.',
              trailing: IconButton(
                tooltip: 'Export CSV',
                onPressed: _exporting ? null : _export,
                icon: _exporting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.file_download_outlined),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: GlassTextField(
              controller: _search,
              label: 'Search transactions',
              icon: Icons.search_rounded,
              onChanged: (_) {
                _searchDebounce?.cancel();
                _searchDebounce = Timer(
                  const Duration(milliseconds: 300),
                  _reload,
                );
              },
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 45,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final value in ['All', 'Income', 'Expenses', 'Transfers'])
                    Padding(
                      padding: const EdgeInsets.only(right: 7, top: 9),
                      child: ChoiceChip(
                        label: Text(value),
                        selected: _filter == value,
                        onSelected: (_) {
                          setState(() => _filter = value);
                          _reload();
                        },
                      ),
                    ),
                  if (categories.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 9),
                      child: PopupMenuButton<String?>(
                        tooltip: 'Filter category',
                        onSelected: (value) {
                          setState(() => _category = value);
                          _reload();
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: null,
                            child: Text('All categories'),
                          ),
                          ...categories.map(
                            (category) => PopupMenuItem(
                              value: category,
                              child: Text(category),
                            ),
                          ),
                        ],
                        child: Chip(
                          label: Text(_category ?? 'Category'),
                          avatar: const Icon(Icons.filter_list, size: 15),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      initialValue: _accountId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Account',
                        prefixIcon: Icon(Icons.wallet_outlined),
                        isDense: true,
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('All accounts'),
                        ),
                        for (final account in finance.accounts)
                          DropdownMenuItem<String?>(
                            value: account.id,
                            child: Text(account.name),
                          ),
                      ],
                      onChanged: (value) {
                        setState(() => _accountId = value);
                        _reload();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _pickDateRange,
                    icon: const Icon(Icons.date_range_outlined),
                    label: Text(
                      _from == null || _through == null
                          ? 'Date range'
                          : '${_from!.day}/${_from!.month}–${_through!.day}/${_through!.month}',
                    ),
                  ),
                  if (_from != null || _through != null)
                    IconButton(
                      tooltip: 'Clear date range',
                      onPressed: () {
                        setState(() {
                          _from = null;
                          _through = null;
                        });
                        _reload();
                      },
                      icon: const Icon(Icons.clear),
                    ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Row(
              children: [
                Expanded(
                  child: _SummaryPill(
                    label: 'Income',
                    values: summary.incomeByCurrency,
                    color: AppColors.income,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SummaryPill(
                    label: 'Expenses',
                    values: summary.expensesByCurrency,
                    color: AppColors.expense,
                  ),
                ),
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  tooltip: 'Sort transactions',
                  onSelected: (value) {
                    setState(() => _sort = value);
                    _reload();
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'Newest first',
                      child: Text('Newest first'),
                    ),
                    PopupMenuItem(
                      value: 'Oldest first',
                      child: Text('Oldest first'),
                    ),
                  ],
                  icon: const Icon(Icons.sort_rounded),
                ),
              ],
            ),
          ),
          if (_loading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: Text(_error!)),
            )
          else if (_items.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: GlassEmptyState(
                  title: 'No transactions found',
                  message:
                      'Try another filter or record your first transaction.',
                  icon: Icons.receipt_long_outlined,
                ),
              ),
            )
          else
            for (final entry in grouped.entries) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 13, bottom: 7),
                  child: Text(
                    _dateHeading(entry.key),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
              SliverList.builder(
                itemCount: entry.value.length,
                itemBuilder: (context, index) {
                  final item = entry.value[index];
                  return TransactionTile(
                    transaction: item,
                    accountName: accountNames[item.accountId],
                  );
                },
              ),
            ],
          if (_loadingMore)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 76)),
        ],
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({
    required this.label,
    required this.values,
    required this.color,
  });

  final String label;
  final Map<String, int> values;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final total = values.entries
        .map((entry) => formatMinorUnits(entry.value, entry.key))
        .join(' · ');
    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      radius: 14,
      blur: 6,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 3),
          Text(
            total.isEmpty ? '—' : total,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

String _dateHeading(DateTime date) {
  final now = DateTime.now();
  if (date.year == now.year && date.month == now.month && date.day == now.day) {
    return 'Today';
  }
  final yesterday = DateTime(now.year, now.month, now.day - 1);
  if (date.year == yesterday.year &&
      date.month == yesterday.month &&
      date.day == yesterday.day) {
    return 'Yesterday';
  }
  return '${date.day}/${date.month}/${date.year}';
}
