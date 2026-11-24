import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/finance_controller.dart';
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
  String _filter = 'All';
  String _sort = 'Newest first';
  String? _category;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceController>();
    var items = finance.transactions.where((transaction) {
      final matchesType = switch (_filter) {
        'Income' => transaction.type == TransactionType.income,
        'Expenses' =>
          transaction.type == TransactionType.expense ||
              transaction.type == TransactionType.refund,
        'Transfers' => transaction.type == TransactionType.transfer,
        _ => true,
      };
      final query = _search.text.trim().toLowerCase();
      final matchesSearch =
          query.isEmpty ||
          transaction.description.toLowerCase().contains(query) ||
          transaction.category.toLowerCase().contains(query) ||
          transaction.notes.toLowerCase().contains(query);
      return matchesType &&
          matchesSearch &&
          (_category == null || transaction.category == _category);
    }).toList();
    if (_sort == 'Oldest first') {
      items = items.reversed.toList();
    }

    final categories = items.map((item) => item.category).toSet().toList()
      ..sort();
    final filteredSummary = finance.summarizeTransactions(items);
    final incomeByCurrency = filteredSummary.incomeByCurrency;
    final expensesByCurrency = filteredSummary.expensesByCurrency;

    final grouped = <DateTime, List<FinancialTransaction>>{};
    for (final item in items) {
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

    return GlassScaffold(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: ScreenHeader(
              title: 'Transactions',
              subtitle: 'Income, expenses and transfers in one place.',
              trailing: IconButton(
                tooltip: 'Export CSV',
                onPressed: items.isEmpty
                    ? null
                    : () async {
                        try {
                          final path = await context
                              .read<FinanceController>()
                              .exportTransactionsCsv(items);
                          if (context.mounted) {
                            showAppMessage(context, 'CSV exported to $path');
                          }
                        } catch (error) {
                          if (context.mounted) {
                            showAppMessage(
                              context,
                              'Export failed: $error',
                              isError: true,
                            );
                          }
                        }
                      },
                icon: const Icon(Icons.file_download_outlined),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: GlassTextField(
              controller: _search,
              label: 'Search transactions',
              icon: Icons.search_rounded,
              onChanged: (_) => setState(() {}),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 45,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final value in [
                    'All',
                    'Income',
                    'Expenses',
                    'Transfers',
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 7, top: 9),
                      child: ChoiceChip(
                        label: Text(value),
                        selected: _filter == value,
                        onSelected: (_) => setState(() => _filter = value),
                      ),
                    ),
                  if (categories.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 9),
                      child: PopupMenuButton<String?>(
                        tooltip: 'Filter category',
                        onSelected: (value) =>
                            setState(() => _category = value),
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
            child: Row(
              children: [
                Expanded(
                  child: _SummaryPill(
                    label: 'Income',
                    values: incomeByCurrency,
                    color: AppColors.income,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SummaryPill(
                    label: 'Expenses',
                    values: expensesByCurrency,
                    color: AppColors.expense,
                  ),
                ),
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  tooltip: 'Sort transactions',
                  onSelected: (value) => setState(() => _sort = value),
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
          if (items.isEmpty)
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
