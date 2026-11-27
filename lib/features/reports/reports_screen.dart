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
    final range = _reportRange(_period, now);
    final from = range.from;
    final through = range.through;
    final reportKey =
        '$_period|$currency|$_accountId|${from.millisecondsSinceEpoch}|${through.millisecondsSinceEpoch}|${identityHashCode(finance.snapshot)}';
    if (_reportKey != reportKey) {
      _reportKey = reportKey;
      _reportFuture = _loadReport(finance, currency, from, through, _accountId);
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
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'weekly', label: Text('Week')),
                        ButtonSegment(value: 'monthly', label: Text('Month')),
                        ButtonSegment(value: 'yearly', label: Text('Year')),
                      ],
                      selected: {_period},
                      showSelectedIcon: false,
                      onSelectionChanged: (value) =>
                          setState(() => _period = value.first),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
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
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
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
                        () => _accountId = value == '__all_accounts__'
                            ? null
                            : value,
                      ),
                    ),
                  ),
                ],
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
    final now = DateTime.now();
    final bucketStarts = [
      for (var offset = 11; offset >= 0; offset--)
        DateTime(now.year, now.month - offset),
    ];
    final monthlySummaries = await Future.wait(
      bucketStarts.map(
        (month) => finance.summaryFor(
          from: month,
          through: DateTime(
            month.year,
            month.month + 1,
          ).subtract(const Duration(milliseconds: 1)),
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
        periodStart: from,
        currencyCode: currency,
        incomeMinor: income,
        expenseMinor: expenses,
        balanceMinor: balance,
        categories: categories,
        transactions: transactions,
        accountNames: {
          for (final account in finance.accounts) account.id: account.name,
        },
        accountLabel: accountId == null
            ? 'All wallets'
            : finance.accounts
                  .where((account) => account.id == accountId)
                  .map((account) => account.name)
                  .firstOrNull,
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

class _MonthlyReportChart extends StatefulWidget {
  const _MonthlyReportChart({
    required this.buckets,
    required this.finance,
    required this.currency,
    required this.accountId,
  });

  final List<({DateTime month, FinancialSummary summary})> buckets;
  final FinanceController finance;
  final String currency;
  final String? accountId;

  @override
  State<_MonthlyReportChart> createState() => _MonthlyReportChartState();
}

class _MonthlyReportChartState extends State<_MonthlyReportChart> {
  int _rangeMonths = 6;
  int _selectedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final data = <({DateTime month, int income, int expense})>[];
    var maxAmount = 0;
    for (final bucket in widget.buckets.skip(
      math.max(0, widget.buckets.length - _rangeMonths),
    )) {
      final income = bucket.summary.incomeByCurrency[widget.currency] ?? 0;
      final expense = bucket.summary.expensesByCurrency[widget.currency] ?? 0;
      data.add((month: bucket.month, income: income, expense: expense));
      maxAmount = math.max(maxAmount, math.max(income, expense));
    }
    if (data.isEmpty) return const SizedBox.shrink();
    final selectedIndex = _selectedIndex < 0 || _selectedIndex >= data.length
        ? data.length - 1
        : _selectedIndex;
    final selected = data[selectedIndex];
    final net = selected.income - selected.expense;
    return GlassContainer(
      padding: const EdgeInsets.fromLTRB(13, 14, 14, 9),
      radius: 18,
      blur: 8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Income vs expenses',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 5,
              children: [
                for (final months in [3, 6, 12])
                  ChoiceChip(
                    label: Text(months == 12 ? '1Y' : '${months}M'),
                    selected: _rangeMonths == months,
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) => setState(() {
                      _rangeMonths = months;
                      _selectedIndex = -1;
                    }),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withValues(
                alpha: Theme.of(context).brightness == Brightness.dark
                    ? 0.75
                    : 0.9,
              ),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_monthLabel(selected.month)} · Net saved',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                Text(
                  '${net < 0 ? '-' : '+'}${formatMinorUnits(net.abs(), widget.currency)}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: net < 0 ? AppColors.expense : AppColors.income,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Income  +${formatMinorUnits(selected.income, widget.currency)}',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: AppColors.income),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Expenses  -${formatMinorUnits(selected.expense, widget.currency)}',
                        textAlign: TextAlign.end,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: AppColors.expense),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 13),
          if (maxAmount == 0)
            const SizedBox(
              height: 135,
              child: Center(
                child: Text(
                  'Add your first transaction to see trends.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            SizedBox(
              height: 194,
              child: BarChart(
                BarChartData(
                  maxY: maxAmount.toDouble() * 1.2,
                  minY: 0,
                  alignment: BarChartAlignment.spaceAround,
                  barGroups: [
                    for (var index = 0; index < data.length; index++)
                      BarChartGroupData(
                        x: index,
                        barsSpace: 3,
                        barRods: [
                          BarChartRodData(
                            toY: data[index].income == 0
                                ? 0
                                : math
                                      .max(
                                        data[index].income,
                                        maxAmount * 0.015,
                                      )
                                      .toDouble(),
                            color: index == selectedIndex
                                ? AppColors.income
                                : AppColors.income.withValues(alpha: 0.48),
                            width: 7,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          BarChartRodData(
                            toY: data[index].expense == 0
                                ? 0
                                : math
                                      .max(
                                        data[index].expense,
                                        maxAmount * 0.015,
                                      )
                                      .toDouble(),
                            color: index == selectedIndex
                                ? AppColors.expense
                                : AppColors.expense.withValues(alpha: 0.48),
                            width: 7,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      ),
                  ],
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final amount = rodIndex == 0
                            ? data[groupIndex].income
                            : data[groupIndex].expense;
                        return BarTooltipItem(
                          formatMinorUnits(amount, widget.currency),
                          const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        );
                      },
                    ),
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
                      setState(() => _selectedIndex = index);
                      final bucket = data[index];
                      final bucketFrom = bucket.month;
                      final bucketThrough = DateTime(
                        bucketFrom.year,
                        bucketFrom.month + 1,
                      ).subtract(const Duration(milliseconds: 1));
                      final type = rod == 0 ? 'income' : 'expense';
                      final amount = rod == 0 ? bucket.income : bucket.expense;
                      _showReportTransactions(
                        context,
                        finance: widget.finance,
                        title:
                            '${_monthLabel(bucket.month)} $type · ${formatMinorUnits(amount, widget.currency)}',
                        currency: widget.currency,
                        from: bucketFrom,
                        through: bucketThrough,
                        accountId: widget.accountId,
                        type: type,
                      );
                    },
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxAmount / 3,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: Theme.of(context).dividerColor
                          .withValues(alpha: 0.18),
                      strokeWidth: 0.7,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 46,
                        interval: maxAmount / 3,
                        getTitlesWidget: (value, meta) => Text(
                          _compactChartAmount(value, widget.currency),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(fontSize: 8),
                        ),
                      ),
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
                              _monthLabel(data[index].month),
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
          Text(
            'Tap a bar for the exact amount and transactions.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
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
    AppColors.teal,
    AppColors.accent,
    AppColors.tealDark,
    AppColors.amber,
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
              height: 174,
              child: BarChart(
                BarChartData(
                  maxY:
                      categories
                          .map((item) => item.amountMinor)
                          .fold<int>(0, math.max)
                          .toDouble() *
                      1.18,
                  minY: 0,
                  alignment: BarChartAlignment.spaceAround,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: total / 3,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: Theme.of(context).dividerColor
                          .withValues(alpha: 0.18),
                      strokeWidth: 0.7,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: [
                    for (var index = 0; index < categories.length; index++)
                      BarChartGroupData(
                        x: index,
                        barRods: [
                          BarChartRodData(
                            toY: categories[index].amountMinor.toDouble(),
                            color: _colors[index % _colors.length],
                            width: 18,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      ),
                  ],
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                          BarTooltipItem(
                            formatMinorUnits(
                              categories[groupIndex].amountMinor,
                              currency,
                            ),
                            const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                    ),
                    touchCallback: (event, response) {
                      final spot = response?.spot;
                      if (event is! FlTapUpEvent || spot == null) return;
                      final index = spot.touchedBarGroupIndex;
                      if (index < 0 || index >= categories.length) return;
                      final item = categories[index];
                      _showReportTransactions(
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
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 42,
                        interval: total / 3,
                        getTitlesWidget: (value, meta) => Text(
                          _compactChartAmount(value, currency),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(fontSize: 8),
                        ),
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 23,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= categories.length) {
                            return const SizedBox.shrink();
                          }
                          final name = categories[index].category;
                          return Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: Text(
                              name.length > 7
                                  ? '${name.substring(0, 6)}…'
                                  : name,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(fontSize: 8),
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

({DateTime from, DateTime through}) _reportRange(String period, DateTime now) {
  switch (period) {
    case 'weekly':
      final start = DateTime(
        now.year,
        now.month,
        now.day - (now.weekday - DateTime.monday),
      );
      return (from: start, through: now);
    case 'monthly':
      return (from: DateTime(now.year, now.month), through: now);
    case 'yearly':
      return (from: DateTime(now.year), through: now);
    default:
      return (from: DateTime(now.year, now.month, 1), through: now);
  }
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

String _compactChartAmount(double amount, String currency) {
  final absolute = amount.abs();
  final compact = absolute >= 1000000000
      ? '${(amount / 1000000000).toStringAsFixed(1)}B'
      : absolute >= 1000000
      ? '${(amount / 1000000).toStringAsFixed(1)}M'
      : absolute >= 1000
      ? '${(amount / 1000).toStringAsFixed(0)}K'
      : amount.toStringAsFixed(0);
  return '$currency $compact';
}
