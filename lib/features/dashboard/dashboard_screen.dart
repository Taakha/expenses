import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/routes/route_names.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/finance_controller.dart';
import '../../core/services/financial_calculation_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/screen_header.dart';
import '../../data/models/finance_models.dart';
import '../../shared/components/transaction_tile.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.onNavigate});

  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceController>();
    final user = context.read<AuthService>().currentUser;
    final name = user?.displayName?.trim().split(' ').first ?? 'there';
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month);
    final monthSummary = finance.summaryFor(from: monthStart, through: now);
    final currency = finance.preferredCurrency;
    final income = monthSummary.incomeByCurrency[currency] ?? 0;
    final expenses = monthSummary.expensesByCurrency[currency] ?? 0;
    final available = finance.accounts
        .where(
          (account) => !account.isArchived && account.currencyCode == currency,
        )
        .fold<int>(
          0,
          (total, account) => total + finance.accountBalance(account),
        );
    final accountNames = {
      for (final account in finance.accounts) account.id: account.name,
    };
    final unreadCount = finance.notifications
        .where((item) => !item.isRead)
        .length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(17, 12, 17, 28),
      children: [
        Row(
          children: [
            const Icon(Icons.eco_rounded, color: AppColors.teal, size: 23),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                'Money Wise',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            IconButton(
              tooltip: 'Notifications',
              onPressed: () =>
                  Navigator.pushNamed(context, RouteNames.notifications),
              icon: Badge(
                isLabelVisible: unreadCount > 0,
                label: Text('$unreadCount'),
                child: const Icon(Icons.notifications_none_rounded),
              ),
            ),
            InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () => onNavigate(4),
              child: CircleAvatar(
                radius: 17,
                backgroundColor: AppColors.teal.withValues(alpha: 0.17),
                child: Text(
                  name.isEmpty ? 'M' : name.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.tealDark,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Good ${_greeting()}, $name 👋',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 3),
        Text(
          'Your money at a glance',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 13),
        SyncStatusCard(
          state: finance.syncState.name,
          pending: finance.pendingSyncCount,
          onTap: finance.syncNow,
        ),
        const SizedBox(height: 12),
        _BalanceSummary(
          balance: available,
          income: income,
          expenses: expenses,
          currency: currency,
        ),
        if (finance.summary.balanceByCurrency.keys.any(
          (key) => key != currency,
        ))
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Text(
              'Other accounts: ${finance.summary.balanceByCurrency.entries.where((entry) => entry.key != currency).map((entry) => formatMinorUnits(entry.value, entry.key)).join('  ·  ')}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        const SizedBox(height: 17),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Quick actions',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            TextButton(
              onPressed: () =>
                  Navigator.pushNamed(context, RouteNames.accounts),
              child: const Text('Accounts'),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            _QuickAction(
              label: 'Income',
              icon: Icons.south_west_rounded,
              color: AppColors.income,
              onTap: () => _openTransaction(context, TransactionType.income),
            ),
            _QuickAction(
              label: 'Expense',
              icon: Icons.north_east_rounded,
              color: AppColors.expense,
              onTap: () => _openTransaction(context, TransactionType.expense),
            ),
            _QuickAction(
              label: 'Budget',
              icon: Icons.pie_chart_outline,
              color: AppColors.violet,
              onTap: () => Navigator.pushNamed(context, RouteNames.budgets),
            ),
            _QuickAction(
              label: 'Savings',
              icon: Icons.savings_outlined,
              color: AppColors.amber,
              onTap: () => Navigator.pushNamed(context, RouteNames.savings),
            ),
          ],
        ),
        const SizedBox(height: 17),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('This month', style: Theme.of(context).textTheme.titleMedium),
            TextButton(
              onPressed: () => onNavigate(3),
              child: const Text('Reports'),
            ),
          ],
        ),
        _MonthlyChart(
          finance: finance,
          transactions: finance.transactions,
          currency: currency,
        ),
        const SizedBox(height: 17),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Budget progress',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            TextButton(
              onPressed: () => onNavigate(2),
              child: const Text('See all'),
            ),
          ],
        ),
        if (finance.budgets.isEmpty)
          GlassEmptyState(
            title: 'No budgets yet',
            message: 'Set a monthly limit to keep spending on track.',
            icon: Icons.savings_outlined,
            action: TextButton(
              onPressed: () => Navigator.pushNamed(context, RouteNames.budgets),
              child: const Text('Create a budget'),
            ),
          )
        else
          ...finance.budgets
              .take(2)
              .map(
                (budget) => _BudgetPreview(
                  budget: budget,
                  progress: finance.budgetProgress(budget),
                ),
              ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent transactions',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            TextButton(
              onPressed: () => onNavigate(1),
              child: const Text('View all'),
            ),
          ],
        ),
        if (finance.transactions.isEmpty)
          GlassEmptyState(
            title: 'A fresh start',
            message: 'Add your first income or expense to see your activity.',
            icon: Icons.receipt_long_outlined,
            action: TextButton(
              onPressed: () =>
                  _openTransaction(context, TransactionType.expense),
              child: const Text('Add a transaction'),
            ),
          )
        else
          ...finance.transactions
              .take(4)
              .map(
                (transaction) => TransactionTile(
                  transaction: transaction,
                  accountName: accountNames[transaction.accountId],
                ),
              ),
        if (finance.syncError != null) ...[
          const SizedBox(height: 8),
          Text(
            finance.syncError!,
            style: const TextStyle(color: AppColors.expense, fontSize: 11),
          ),
        ],
      ],
    );
  }

  static void _openTransaction(BuildContext context, TransactionType type) {
    Navigator.pushNamed(context, RouteNames.transactionAdd, arguments: type);
  }
}

class _BalanceSummary extends StatelessWidget {
  const _BalanceSummary({
    required this.balance,
    required this.income,
    required this.expenses,
    required this.currency,
  });

  final int balance;
  final int income;
  final int expenses;
  final String currency;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(17),
      radius: 23,
      gradient: const LinearGradient(
        colors: [Color(0xE70B8D7E), Color(0xE906565D)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderColor: Colors.white.withValues(alpha: 0.42),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'TOTAL BALANCE',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                currency,
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            formatMinorUnits(balance, currency),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 27,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _SummaryStat(
                  label: 'Income',
                  amount: income,
                  currency: currency,
                  icon: Icons.south_west_rounded,
                  color: const Color(0xFF75E8C4),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _SummaryStat(
                  label: 'Expenses',
                  amount: expenses,
                  currency: currency,
                  icon: Icons.north_east_rounded,
                  color: const Color(0xFFFF9B98),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
    required this.label,
    required this.amount,
    required this.currency,
    required this.icon,
    required this.color,
  });

  final String label;
  final int amount;
  final String currency;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withValues(alpha: 0.17)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                ),
                const SizedBox(height: 3),
                Text(
                  formatMinorUnits(amount, currency),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.17),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: color.withValues(alpha: 0.13)),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 5),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthlyChart extends StatelessWidget {
  const _MonthlyChart({
    required this.finance,
    required this.transactions,
    required this.currency,
  });

  final FinanceController finance;
  final List<FinancialTransaction> transactions;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final values = <({int income, int expense})>[];
    for (var offset = 5; offset >= 0; offset--) {
      final month = DateTime(now.year, now.month - offset);
      final range = finance.summarizeTransactions(
        transactions,
        from: month,
        through: DateTime(month.year, month.month + 1, 0, 23, 59, 59, 999),
      );
      values.add((
        income: range.incomeByCurrency[currency] ?? 0,
        expense: range.expensesByCurrency[currency] ?? 0,
      ));
    }
    final maxValue = values.fold<int>(
      0,
      (current, value) => [
        current,
        value.income,
        value.expense,
      ].reduce((a, b) => a > b ? a : b),
    );
    final axisMax = maxValue == 0 ? 100.0 : maxValue.toDouble();
    return GlassContainer(
      padding: const EdgeInsets.fromLTRB(12, 12, 14, 8),
      radius: 18,
      blur: 8,
      child: Column(
        children: [
          SizedBox(
            height: 150,
            child: BarChart(
              BarChartData(
                maxY: axisMax * 1.2,
                minY: 0,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 20,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= 6)
                          return const SizedBox.shrink();
                        final month = DateTime(
                          now.year,
                          now.month - (5 - index),
                        );
                        return Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Text(
                            _monthLabel(month.month),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (var index = 0; index < values.length; index++)
                    BarChartGroupData(
                      x: index,
                      barsSpace: 4,
                      barRods: [
                        BarChartRodData(
                          toY: values[index].income.toDouble(),
                          width: 7,
                          borderRadius: BorderRadius.circular(5),
                          color: AppColors.income,
                        ),
                        BarChartRodData(
                          toY: values[index].expense.toDouble(),
                          width: 7,
                          borderRadius: BorderRadius.circular(5),
                          color: AppColors.expense,
                        ),
                      ],
                    ),
                ],
              ),
              duration: const Duration(milliseconds: 320),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ChartLegend(color: AppColors.income, label: 'Income'),
              const SizedBox(width: 16),
              _ChartLegend(color: AppColors.expense, label: 'Expenses'),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _BudgetPreview extends StatelessWidget {
  const _BudgetPreview({required this.budget, required this.progress});

  final FinancialBudget budget;
  final BudgetProgress progress;

  @override
  Widget build(BuildContext context) {
    final ratio = budget.limitMinor <= 0
        ? 0.0
        : (progress.spentMinor / budget.limitMinor).clamp(0, 1).toDouble();
    final color = progress.usagePercent >= 100
        ? AppColors.expense
        : progress.usagePercent >= 90
        ? AppColors.amber
        : AppColors.teal;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassContainer(
        padding: const EdgeInsets.all(13),
        radius: 17,
        blur: 8,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    budget.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  '${progress.usagePercent}%',
                  style: TextStyle(color: color, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 7,
                backgroundColor: color.withValues(alpha: 0.12),
                color: color,
              ),
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Spent ${formatMinorUnits(progress.spentMinor, budget.currencyCode)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                Text(
                  '${formatMinorUnits(progress.remainingMinor, budget.currencyCode)} left',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _monthLabel(int month) => const [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
][month - 1];

String _greeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'morning';
  if (hour < 17) return 'afternoon';
  return 'evening';
}
