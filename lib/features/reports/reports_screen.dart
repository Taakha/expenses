import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_icons.dart';
import '../../core/services/finance_controller.dart';
import '../../core/services/financial_calculation_service.dart';
import '../../core/services/report_export_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/glass_button.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/screen_header.dart';
import '../../data/models/finance_models.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _period = 'monthly';
  DateTime? _customFrom;
  DateTime? _customThrough;
  String? _currency;
  String? _accountId;
  bool _exporting = false;
  final _exports = const ReportExportService();
  String? _reportKey;
  Future<_ReportData>? _reportFuture;

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceController>();
    final currency = _currency ?? finance.preferredCurrency;
    final now = DateTime.now();
    final range = _reportRange(_period, now, _customFrom, _customThrough);
    final from = range.from;
    final through = range.through;
    final reportKey =
        '$_period|$currency|$_accountId|${from.millisecondsSinceEpoch}|${through.millisecondsSinceEpoch}|${identityHashCode(finance.snapshot)}';
    if (_reportKey != reportKey) {
      _reportKey = reportKey;
      _reportFuture = _loadReport(
        finance,
        currency,
        from,
        through,
        _accountId,
        _period,
      );
    }
    final visibleCurrencies = {
      ...finance.accounts.map((account) => account.currencyCode),
      finance.preferredCurrency,
    }.toList()..sort();

    return FutureBuilder<_ReportData>(
      future: _reportFuture,
      builder: (context, reportState) {
        if (reportState.hasError) {
          return GlassScaffold(
            child: Center(
              child: Text('Could not load report: ${reportState.error}'),
            ),
          );
        }
        if (!reportState.hasData) {
          return const GlassScaffold(
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final data = reportState.data!;
        final summary = data.summary;
        final income = summary.incomeByCurrency[currency] ?? 0;
        final expenses = summary.expensesByCurrency[currency] ?? 0;
        final scopedAccount = _accountId == null
            ? null
            : finance.accounts
                  .where(
                    (account) =>
                        account.id == _accountId &&
                        account.currencyCode == currency,
                  )
                  .firstOrNull;
        final balance = scopedAccount == null
            ? finance.summary.balanceByCurrency[currency] ?? 0
            : finance.accountBalance(scopedAccount);
        final categories = data.categories;
        final categoryTotal = categories.fold<int>(
          0,
          (total, item) => total + item.amountMinor,
        );
        final categoryItems = [
          for (final item in categories)
            CategorySpendingItem(
              category: item.category,
              amountMinor: item.amountMinor,
              sharePercent: categoryTotal == 0
                  ? 0
                  : item.amountMinor * 100 ~/ categoryTotal,
            ),
        ];
        return GlassScaffold(
          padding: const EdgeInsets.symmetric(horizontal: 17),
          child: ListView(
            padding: const EdgeInsets.only(top: 10, bottom: 28),
            children: [
              const ScreenHeader(
                title: 'Reports',
                subtitle: 'Understand where your money goes.',
              ),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _period,
                      decoration: const InputDecoration(labelText: 'Period'),
                      items: const [
                        DropdownMenuItem(
                          value: 'weekly',
                          child: Text('Weekly'),
                        ),
                        DropdownMenuItem(
                          value: 'monthly',
                          child: Text('Monthly'),
                        ),
                        DropdownMenuItem(
                          value: 'yearly',
                          child: Text('Yearly'),
                        ),
                        DropdownMenuItem(
                          value: 'custom',
                          child: Text('Custom range'),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _period = value ?? _period),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: visibleCurrencies.contains(currency)
                          ? currency
                          : finance.preferredCurrency,
                      decoration: const InputDecoration(labelText: 'Currency'),
                      items: visibleCurrencies
                          .map(
                            (code) => DropdownMenuItem(
                              value: code,
                              child: Text(code),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() => _currency = value),
                    ),
                  ),
                ],
              ),
              if (_period == 'custom') ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final selected = await showDatePicker(
                            context: context,
                            initialDate: _customFrom ?? from,
                            firstDate: DateTime(2000),
                            lastDate: now,
                          );
                          if (selected != null) {
                            setState(() {
                              _customFrom = selected;
                              if (_customThrough != null &&
                                  _customThrough!.isBefore(selected)) {
                                _customThrough = selected;
                              }
                            });
                          }
                        },
                        child: Text('From ${_date(from)}'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final selected = await showDatePicker(
                            context: context,
                            initialDate: _customThrough ?? now,
                            firstDate: _customFrom ?? DateTime(2000),
                            lastDate: now,
                          );
                          if (selected != null) {
                            setState(() => _customThrough = selected);
                          }
                        },
                        child: Text('To ${_date(through)}'),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _accountId ?? '__all_accounts__',
                decoration: const InputDecoration(labelText: 'Account'),
                items: [
                  const DropdownMenuItem(
                    value: '__all_accounts__',
                    child: Text('All accounts'),
                  ),
                  ...finance.accounts.map(
                    (account) => DropdownMenuItem(
                      value: account.id,
                      child: Text(account.name),
                    ),
                  ),
                ],
                onChanged: (value) => setState(
                  () => _accountId = value == '__all_accounts__' ? null : value,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _ReportMetric(
                      label: 'Income',
                      value: income,
                      currency: currency,
                      color: AppColors.income,
                      icon: AppIcons.income,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ReportMetric(
                      label: 'Expenses',
                      value: expenses,
                      currency: currency,
                      color: AppColors.expense,
                      icon: AppIcons.expense,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              GlassContainer(
                padding: const EdgeInsets.all(14),
                radius: 17,
                blur: 7,
                child: Row(
                  children: [
                    const Icon(AppIcons.cashFlow, color: AppColors.tealDark),
                    const SizedBox(width: 9),
                    Flexible(
                      fit: FlexFit.loose,
                      child: Text(
                        'Net cash flow · ${income - expenses < 0 ? 'negative' : 'positive'}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Text(
                      formatMinorUnits(income - expenses, currency),
                      style: TextStyle(
                        color: income - expenses < 0
                            ? AppColors.expense
                            : AppColors.income,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              GlassContainer(
                padding: const EdgeInsets.all(14),
                radius: 17,
                blur: 7,
                child: Row(
                  children: [
                    const Icon(AppIcons.savingsGoal, color: AppColors.tealDark),
                    const SizedBox(width: 9),
                    Flexible(
                      fit: FlexFit.loose,
                      child: Text(
                        'Savings goals',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Text(
                      formatMinorUnits(
                        finance.goals
                            .where(
                              (goal) =>
                                  goal.status == 'active' &&
                                  goal.currencyCode == currency,
                            )
                            .fold<int>(
                              0,
                              (total, goal) =>
                                  total + finance.savingsTotal(goal),
                            ),
                        currency,
                      ),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              GlassContainer(
                padding: const EdgeInsets.all(14),
                radius: 17,
                blur: 7,
                child: Row(
                  children: [
                    const Icon(AppIcons.savingsGoal, color: AppColors.tealDark),
                    const SizedBox(width: 9),
                    Flexible(
                      fit: FlexFit.loose,
                      child: Text(
                        'Current account balance',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Text(
                      formatMinorUnits(balance, currency),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _MonthlyReportChart(
                buckets: data.monthlySummaries,
                finance: finance,
                currency: currency,
                accountId: _accountId,
                period: _period,
                from: from,
                through: through,
              ),
              const SizedBox(height: 10),
              _SpendingTrendChart(
                buckets: data.monthlySummaries,
                currency: currency,
                period: _period,
                from: from,
                through: through,
              ),
              const SizedBox(height: 10),
              _CategoryReport(
                categories: categories,
                currency: currency,
                total: categoryTotal,
                finance: finance,
                from: from,
                through: through,
                accountId: _accountId,
              ),
              const SizedBox(height: 10),
              _BudgetReport(
                finance: finance,
                currency: currency,
                accountId: _accountId,
              ),
              const SizedBox(height: 10),
              _SavingsReport(finance: finance),
              const SizedBox(height: 10),
              _RecentActivityReport(transactions: data.recentTransactions),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: GlassButton(
                      label: 'Export CSV',
                      icon: AppIcons.exportCsv,
                      onPressed: _exporting
                          ? null
                          : () => _exportCsv(
                              finance,
                              currency,
                              from,
                              through,
                              _accountId,
                            ),
                      isLoading: _exporting,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: GlassButton(
                      label: 'Share PDF',
                      icon: AppIcons.exportPdf,
                      onPressed: _exporting
                          ? null
                          : () => _exportPdf(
                              currency,
                              income,
                              expenses,
                              balance,
                              categoryItems,
                              finance,
                              from,
                              through,
                              _accountId,
                            ),
                      isLoading: _exporting,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              GlassContainer(
                padding: const EdgeInsets.all(12),
                radius: 15,
                blur: 5,
                child: Text(
                  'Reports preserve transaction currencies. Amounts in different currencies are never combined or converted without an exchange rate.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<_ReportData> _loadReport(
    FinanceController finance,
    String currency,
    DateTime from,
    DateTime through,
    String? accountId,
    String period,
  ) async {
    final summaryFuture = finance.summaryFor(
      from: from,
      through: through,
      accountId: accountId,
    );
    final categoriesFuture = finance.categorySpending(
      currencyCode: currency,
      from: from,
      through: through,
      accountId: accountId,
    );
    final bucketStarts = _bucketStarts(period, from, through);
    final monthlySummaries = await Future.wait(
      bucketStarts.map(
        (month) => finance.summaryFor(
          from: month,
          through: _bucketEnd(period, month, from, through),
          accountId: accountId,
        ),
      ),
    );
    final recent = await finance.loadTransactionPage(
      pageSize: 5,
      currencyCode: currency,
      from: from,
      through: through,
      accountId: accountId,
    );
    return _ReportData(
      summary: await summaryFuture,
      categories: await categoriesFuture,
      monthlySummaries: [
        for (var index = 0; index < bucketStarts.length; index++)
          (month: bucketStarts[index], summary: monthlySummaries[index]),
      ],
      recentTransactions: recent.transactions,
    );
  }

  Future<void> _exportCsv(
    FinanceController finance,
    String currency,
    DateTime from,
    DateTime through,
    String? accountId,
  ) async {
    setState(() => _exporting = true);
    try {
      final path = await finance.exportTransactionsCsv(
        currencyCode: currency,
        from: from,
        through: through,
        accountId: accountId,
      );
      if (mounted) showAppMessage(context, 'CSV saved to $path');
    } catch (error) {
      if (mounted) {
        showAppMessage(context, 'Could not export CSV: $error', isError: true);
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _exportPdf(
    String currency,
    int income,
    int expenses,
    int balance,
    List<CategorySpendingItem> categories,
    FinanceController finance,
    DateTime from,
    DateTime through,
    String? accountId,
  ) async {
    setState(() => _exporting = true);
    try {
      final transactions = await finance
          .streamTransactions(
            currencyCode: currency,
            from: from,
            through: through,
            accountId: accountId,
          )
          .toList();
      await _exports.shareReportPdf(
        periodLabel: '${_date(from)} - ${_date(through)}',
        currencyCode: currency,
        incomeMinor: income,
        expenseMinor: expenses,
        balanceMinor: balance,
        categories: categories,
        transactions: transactions,
      );
    } catch (error) {
      if (mounted) {
        showAppMessage(
          context,
          'Could not create PDF report: $error',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }
}

class _ReportMetric extends StatelessWidget {
  const _ReportMetric({
    required this.label,
    required this.value,
    required this.currency,
    required this.color,
    required this.icon,
  });

  final String label;
  final int value;
  final String currency;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(13),
      radius: 16,
      blur: 6,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatMinorUnits(value, currency),
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthlyReportChart extends StatelessWidget {
  const _MonthlyReportChart({
    required this.buckets,
    required this.finance,
    required this.currency,
    required this.accountId,
    required this.period,
    required this.from,
    required this.through,
  });

  final List<({DateTime month, FinancialSummary summary})> buckets;
  final FinanceController finance;
  final String currency;
  final String? accountId;
  final String period;
  final DateTime from;
  final DateTime through;

  @override
  Widget build(BuildContext context) {
    final data = <({DateTime month, int income, int expense})>[];
    var maxAmount = 0;
    for (final bucket in buckets) {
      final income = bucket.summary.incomeByCurrency[currency] ?? 0;
      final expense = bucket.summary.expensesByCurrency[currency] ?? 0;
      data.add((month: bucket.month, income: income, expense: expense));
      maxAmount = math.max(maxAmount, math.max(income, expense));
    }
    return GlassContainer(
      padding: const EdgeInsets.fromLTRB(13, 14, 14, 9),
      radius: 18,
      blur: 8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Income vs expenses',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 13),
          if (maxAmount == 0)
            const SizedBox(
              height: 150,
              child: Center(
                child: Text('Add a transaction to see your income trends.'),
              ),
            )
          else
            SizedBox(
              height: 190,
              child: BarChart(
                BarChartData(
                  maxY: maxAmount.toDouble() * 1.18,
                  barGroups: [
                    for (var index = 0; index < data.length; index++)
                      BarChartGroupData(
                        x: index,
                        barsSpace: 3,
                        barRods: [
                          BarChartRodData(
                            toY: data[index].income.toDouble(),
                            color: AppColors.income,
                            width: 7,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          BarChartRodData(
                            toY: math.max(0, data[index].expense).toDouble(),
                            color: AppColors.expense,
                            width: 7,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      ),
                  ],
                  barTouchData: BarTouchData(
                    touchCallback: (event, response) {
                      final spot = response?.spot;
                      if (event is! FlTapUpEvent || spot == null) return;
                      final index = spot.touchedBarGroupIndex;
                      final rod = spot.touchedRodDataIndex;
                      if (index < 0 ||
                          index >= data.length ||
                          rod < 0 ||
                          rod > 1) {
                        return;
                      }
                      final bucket = data[index];
                      final bucketFrom = bucket.month;
                      final bucketThrough = _bucketEnd(
                        period,
                        bucketFrom,
                        from,
                        through,
                      );
                      final type = rod == 0 ? 'income' : 'expense';
                      final amount = rod == 0 ? bucket.income : bucket.expense;
                      _showReportTransactions(
                        context,
                        finance: finance,
                        title:
                            '${_bucketLabel(period, bucket.month, from, through)} $type · ${formatMinorUnits(amount, currency)}',
                        currency: currency,
                        from: bucketFrom,
                        through: bucketThrough,
                        accountId: accountId,
                        type: type,
                      );
                    },
                  ),
                  gridData: const FlGridData(
                    show: true,
                    drawVerticalLine: false,
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= data.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: Text(
                              _bucketLabel(
                                period,
                                data[index].month,
                                from,
                                through,
                              ),
                              style: const TextStyle(fontSize: 9),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                duration: const Duration(milliseconds: 350),
              ),
            ),
          const SizedBox(height: 3),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendDot(color: AppColors.income, label: 'Income'),
              SizedBox(width: 14),
              _LegendDot(color: AppColors.expense, label: 'Expenses'),
            ],
          ),
        ],
      ),
    );
  }
}

class _SpendingTrendChart extends StatelessWidget {
  const _SpendingTrendChart({
    required this.buckets,
    required this.currency,
    required this.period,
    required this.from,
    required this.through,
  });

  final List<({DateTime month, FinancialSummary summary})> buckets;
  final String currency;
  final String period;
  final DateTime from;
  final DateTime through;

  @override
  Widget build(BuildContext context) {
    final incomes = [
      for (var index = 0; index < buckets.length; index++)
        FlSpot(
          index.toDouble(),
          (buckets[index].summary.incomeByCurrency[currency] ?? 0).toDouble(),
        ),
    ];
    final expenses = [
      for (var index = 0; index < buckets.length; index++)
        FlSpot(
          index.toDouble(),
          (buckets[index].summary.expensesByCurrency[currency] ?? 0).toDouble(),
        ),
    ];
    final maxAmount = [
      ...incomes.map((spot) => spot.y),
      ...expenses.map((spot) => spot.y),
    ].fold<double>(0, (current, value) => value > current ? value : current);
    return GlassContainer(
      padding: const EdgeInsets.fromLTRB(13, 14, 14, 9),
      radius: 18,
      blur: 8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Spending trends',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 13),
          if (maxAmount == 0)
            const SizedBox(
              height: 150,
              child: Center(
                child: Text('Add a transaction to see your spending trends.'),
              ),
            )
          else
            SizedBox(
              height: 180,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: maxAmount * 1.18,
                  gridData: const FlGridData(
                    show: true,
                    drawVerticalLine: false,
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= buckets.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: Text(
                              _bucketLabel(
                                period,
                                buckets[index].month,
                                from,
                                through,
                              ),
                              style: const TextStyle(fontSize: 9),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  lineBarsData: [
                    _trendLine(incomes, AppColors.income),
                    _trendLine(expenses, AppColors.expense),
                  ],
                ),
                duration: const Duration(milliseconds: 350),
              ),
            ),
          const SizedBox(height: 3),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendDot(color: AppColors.income, label: 'Income'),
              SizedBox(width: 14),
              _LegendDot(color: AppColors.expense, label: 'Expenses'),
            ],
          ),
        ],
      ),
    );
  }

  LineChartBarData _trendLine(List<FlSpot> spots, Color color) =>
      LineChartBarData(
        spots: spots,
        isCurved: true,
        color: color,
        barWidth: 2.5,
        dotData: const FlDotData(show: false),
      );
}

class _CategoryReport extends StatelessWidget {
  const _CategoryReport({
    required this.categories,
    required this.currency,
    required this.total,
    required this.finance,
    required this.from,
    required this.through,
    required this.accountId,
  });

  final List<CategorySpending> categories;
  final String currency;
  final int total;
  final FinanceController finance;
  final DateTime from;
  final DateTime through;
  final String? accountId;

  static const _colors = [
    AppColors.teal,
    AppColors.income,
    AppColors.expense,
    AppColors.amber,
    Color(0xFF6377D8),
    Color(0xFFAA68C7),
    Color(0xFF4F9B8A),
    Color(0xFFCC765B),
  ];

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(14),
      radius: 18,
      blur: 8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Spending by category',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (categories.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 22),
              child: Center(child: Text('No spending in this period.')),
            )
          else ...[
            SizedBox(
              height: 180,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      centerSpaceRadius: 44,
                      sectionsSpace: 3,
                      sections: [
                        for (var index = 0; index < categories.length; index++)
                          PieChartSectionData(
                            value: categories[index].amountMinor.toDouble(),
                            color: _colors[index % _colors.length],
                            radius: 35,
                            title: total > 0
                                ? '${categories[index].amountMinor * 100 ~/ total}%'
                                : '',
                            titleStyle: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                      ],
                    ),
                    duration: const Duration(milliseconds: 350),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Total',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        formatMinorUnits(total, currency),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            ...categories.take(7).toList().asMap().entries.map((entry) {
              final item = entry.value;
              return InkWell(
                borderRadius: BorderRadius.circular(9),
                onTap: () => _showReportTransactions(
                  context,
                  finance: finance,
                  title:
                      '${item.category} · ${formatMinorUnits(item.amountMinor, currency)} · ${item.transactionCount} transactions',
                  currency: currency,
                  from: from,
                  through: through,
                  accountId: accountId,
                  category: item.category,
                  type: 'expense',
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      _LegendDot(
                        color: _colors[entry.key % _colors.length],
                        label: item.category,
                      ),
                      const Spacer(),
                      Text(
                        formatMinorUnits(item.amountMinor, currency),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

Future<void> _showReportTransactions(
  BuildContext context, {
  required FinanceController finance,
  required String title,
  required String currency,
  required DateTime from,
  required DateTime through,
  String? accountId,
  String? category,
  String? type,
}) async {
  final future = finance.loadTransactionPage(
    pageSize: 50,
    currencyCode: currency,
    from: from,
    through: through,
    accountId: accountId,
    category: category,
    type: type,
  );
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Expanded(
                child: FutureBuilder(
                  future: future,
                  builder: (context, state) {
                    if (state.hasError) {
                      return Center(
                        child: Text(
                          'Could not load transactions: ${state.error}',
                        ),
                      );
                    }
                    if (!state.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final page = state.data!;
                    if (page.transactions.isEmpty) {
                      return const Center(
                        child: Text('No transactions in this selection.'),
                      );
                    }
                    return ListView(
                      children: [
                        ...page.transactions.map(
                          (transaction) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              transaction.type == TransactionType.income
                                  ? AppIcons.income
                                  : transaction.type == TransactionType.refund
                                  ? AppIcons.refund
                                  : AppIcons.expense,
                              color:
                                  transaction.type == TransactionType.income ||
                                      transaction.type == TransactionType.refund
                                  ? AppColors.income
                                  : AppColors.expense,
                            ),
                            title: Text(transaction.description),
                            subtitle: Text(
                              '${transaction.category} · ${_date(transaction.occurredAt)}',
                            ),
                            trailing: Text(
                              formatMinorUnits(
                                transaction.amountMinor *
                                    (transaction.type == TransactionType.expense
                                        ? -1
                                        : 1),
                                transaction.currencyCode,
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        if (page.hasMore)
                          const Padding(
                            padding: EdgeInsets.all(12),
                            child: Text(
                              'Showing the first 50 matching transactions.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _BudgetReport extends StatelessWidget {
  const _BudgetReport({
    required this.finance,
    required this.currency,
    required this.accountId,
  });

  final FinanceController finance;
  final String currency;
  final String? accountId;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final activeBudgets = finance.budgets.where((budget) {
      final endOfDay = DateTime(
        budget.endDate.year,
        budget.endDate.month,
        budget.endDate.day,
        23,
        59,
        59,
        999,
      );
      return !budget.isArchived &&
          budget.currencyCode == currency &&
          (accountId == null ||
              budget.accountId == null ||
              budget.accountId == accountId) &&
          !today.isBefore(budget.startDate) &&
          !today.isAfter(endOfDay);
    }).toList();
    return GlassContainer(
      padding: const EdgeInsets.all(14),
      radius: 18,
      blur: 8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Budget performance',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (activeBudgets.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Text('No active budgets for this period.'),
            )
          else
            ...activeBudgets.map((budget) {
              final progress = finance.budgetProgress(budget);
              final color = progress.remainingMinor < 0
                  ? AppColors.expense
                  : progress.usagePercent >= budget.alertPercentage
                  ? AppColors.amber
                  : AppColors.income;
              final ratio = budget.limitMinor <= 0
                  ? 0.0
                  : (progress.spentMinor / budget.limitMinor)
                        .clamp(0, 1)
                        .toDouble();
              return Padding(
                padding: const EdgeInsets.only(top: 11),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(budget.name)),
                        Text(
                          progress.remainingMinor < 0
                              ? '${formatMinorUnits(progress.remainingMinor.abs(), budget.currencyCode)} over'
                              : '${formatMinorUnits(progress.remainingMinor, budget.currencyCode)} left',
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: ratio,
                      color: color,
                      backgroundColor: color.withValues(alpha: 0.14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${formatMinorUnits(progress.spentMinor, budget.currencyCode)} of ${formatMinorUnits(budget.limitMinor, budget.currencyCode)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _SavingsReport extends StatelessWidget {
  const _SavingsReport({required this.finance});

  final FinanceController finance;

  @override
  Widget build(BuildContext context) {
    final goals = finance.goals
        .where((goal) => goal.status == 'active')
        .toList();
    return GlassContainer(
      padding: const EdgeInsets.all(14),
      radius: 18,
      blur: 8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Savings progress',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (goals.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Text('Add a savings goal to track your progress here.'),
            )
          else
            ...goals.map((goal) {
              final saved = finance.savingsTotal(goal);
              final ratio = goal.targetMinor <= 0
                  ? 0.0
                  : (saved / goal.targetMinor).clamp(0, 1).toDouble();
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: SizedBox(
                  width: 42,
                  height: 42,
                  child: CircularProgressIndicator(
                    value: ratio,
                    backgroundColor: AppColors.teal.withValues(alpha: 0.15),
                    color: AppColors.teal,
                  ),
                ),
                title: Text(goal.name),
                subtitle: Text(
                  '${formatMinorUnits(saved, goal.currencyCode)} of ${formatMinorUnits(goal.targetMinor, goal.currencyCode)}',
                ),
                trailing: Text('${(ratio * 100).round()}%'),
              );
            }),
        ],
      ),
    );
  }
}

class _RecentActivityReport extends StatelessWidget {
  const _RecentActivityReport({required this.transactions});

  final List<FinancialTransaction> transactions;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(14),
      radius: 18,
      blur: 8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent activity',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (transactions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Text('No financial activity in this period.'),
            )
          else
            ...transactions.map(
              (transaction) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  transaction.type == TransactionType.income
                      ? AppIcons.income
                      : AppIcons.expense,
                  color: transaction.type == TransactionType.income
                      ? AppColors.income
                      : AppColors.expense,
                ),
                title: Text(transaction.description),
                subtitle: Text(
                  '${transaction.category} · ${_date(transaction.occurredAt)}',
                ),
                trailing: Text(
                  formatMinorUnits(
                    transaction.amountMinor *
                        (transaction.type == TransactionType.expense ? -1 : 1),
                    transaction.currencyCode,
                  ),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _ReportData {
  const _ReportData({
    required this.summary,
    required this.categories,
    required this.monthlySummaries,
    required this.recentTransactions,
  });

  final FinancialSummary summary;
  final List<CategorySpending> categories;
  final List<({DateTime month, FinancialSummary summary})> monthlySummaries;
  final List<FinancialTransaction> recentTransactions;
}

({DateTime from, DateTime through}) _reportRange(
  String period,
  DateTime now,
  DateTime? customFrom,
  DateTime? customThrough,
) {
  switch (period) {
    case 'weekly':
      final start = DateTime(
        now.year,
        now.month,
        now.day - (now.weekday - DateTime.monday),
      );
      return (from: start, through: now);
    case 'yearly':
      return (from: DateTime(now.year), through: now);
    case 'custom':
      final start = customFrom ?? DateTime(now.year, now.month, 1);
      final end = customThrough ?? now;
      return (
        from: DateTime(start.year, start.month, start.day),
        through: DateTime(end.year, end.month, end.day, 23, 59, 59, 999),
      );
    default:
      return (from: DateTime(now.year, now.month, 1), through: now);
  }
}

List<DateTime> _bucketStarts(String period, DateTime from, DateTime through) {
  if (period == 'weekly') {
    return [
      for (
        var date = from;
        !date.isAfter(through);
        date = date.add(const Duration(days: 1))
      )
        DateTime(date.year, date.month, date.day),
    ];
  }
  final useYears = _usesYearBuckets(period, from, through);
  if (useYears) {
    return [
      for (var year = from.year; year <= through.year; year++)
        year == from.year ? from : DateTime(year),
    ];
  }
  final firstMonth = DateTime(from.year, from.month);
  return [
    for (
      var month = firstMonth;
      !month.isAfter(DateTime(through.year, through.month));
      month = DateTime(month.year, month.month + 1)
    )
      month == firstMonth ? from : month,
  ];
}

DateTime _bucketEnd(
  String period,
  DateTime start,
  DateTime rangeStart,
  DateTime rangeEnd,
) {
  if (period == 'weekly') {
    final end = DateTime(start.year, start.month, start.day, 23, 59, 59, 999);
    return end.isAfter(rangeEnd) ? rangeEnd : end;
  }
  final end = _usesYearBuckets(period, rangeStart, rangeEnd)
      ? DateTime(start.year + 1, 1)
      : DateTime(start.year, start.month + 1);
  final endOfBucket = end.subtract(const Duration(milliseconds: 1));
  return endOfBucket.isAfter(rangeEnd) ? rangeEnd : endOfBucket;
}

bool _usesYearBuckets(String period, DateTime from, DateTime through) {
  if (period == 'yearly') return true;
  if (period != 'custom') return false;
  final monthCount =
      (through.year - from.year) * 12 + through.month - from.month + 1;
  return monthCount > 24;
}

String _bucketLabel(
  String period,
  DateTime date,
  DateTime rangeStart,
  DateTime rangeEnd,
) {
  if (period == 'weekly') return '${date.day}';
  if (_usesYearBuckets(period, rangeStart, rangeEnd)) return '${date.year}';
  return _monthLabel(date);
}

String _monthLabel(DateTime month) => const [
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
][month.month - 1];

String _date(DateTime date) => '${date.day}/${date.month}/${date.year}';
