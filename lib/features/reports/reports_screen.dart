import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  int _months = 3;
  String? _currency;
  bool _exporting = false;
  final _exports = const ReportExportService();
  String? _reportKey;
  Future<_ReportData>? _reportFuture;

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceController>();
    final currency = _currency ?? finance.preferredCurrency;
    final now = DateTime.now();
    final from = DateTime(now.year, now.month - _months + 1);
    final through = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);
    final reportKey =
        '$_months|$currency|${identityHashCode(finance.snapshot)}';
    if (_reportKey != reportKey) {
      _reportKey = reportKey;
      _reportFuture = _loadReport(finance, currency, from, through);
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
        final balance = finance.summary.balanceByCurrency[currency] ?? 0;
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
                    child: DropdownButtonFormField<int>(
                      initialValue: _months,
                      decoration: const InputDecoration(labelText: 'Period'),
                      items: const [
                        DropdownMenuItem(value: 1, child: Text('This month')),
                        DropdownMenuItem(
                          value: 3,
                          child: Text('Last 3 months'),
                        ),
                        DropdownMenuItem(
                          value: 6,
                          child: Text('Last 6 months'),
                        ),
                        DropdownMenuItem(
                          value: 12,
                          child: Text('Last 12 months'),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _months = value ?? _months),
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
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _ReportMetric(
                      label: 'Income',
                      value: income,
                      currency: currency,
                      color: AppColors.income,
                      icon: Icons.south_west_rounded,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ReportMetric(
                      label: 'Expenses',
                      value: expenses,
                      currency: currency,
                      color: AppColors.expense,
                      icon: Icons.north_east_rounded,
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
                    const Icon(
                      Icons.account_balance_wallet_outlined,
                      color: AppColors.tealDark,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
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
                    const Icon(
                      Icons.savings_outlined,
                      color: AppColors.tealDark,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
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
                finance: finance,
                months: _months,
                currency: currency,
              ),
              const SizedBox(height: 10),
              _CategoryReport(
                categories: categories,
                currency: currency,
                total: categoryTotal,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: GlassButton(
                      label: 'Export CSV',
                      icon: Icons.table_view_outlined,
                      onPressed: _exporting
                          ? null
                          : () => _exportCsv(finance, currency, from, through),
                      isLoading: _exporting,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: GlassButton(
                      label: 'Share PDF',
                      icon: Icons.picture_as_pdf_outlined,
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
  ) async {
    final summaryFuture = finance.summaryFor(from: from, through: through);
    final categoriesFuture = finance.categorySpending(
      currencyCode: currency,
      from: from,
      through: through,
    );
    return _ReportData(
      summary: await summaryFuture,
      categories: await categoriesFuture,
    );
  }

  Future<void> _exportCsv(
    FinanceController finance,
    String currency,
    DateTime from,
    DateTime through,
  ) async {
    setState(() => _exporting = true);
    try {
      final path = await finance.exportTransactionsCsv(
        currencyCode: currency,
        from: from,
        through: through,
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
  ) async {
    setState(() => _exporting = true);
    try {
      final transactions = await finance
          .streamTransactions(
            currencyCode: currency,
            from: from,
            through: through,
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
    required this.finance,
    required this.months,
    required this.currency,
  });

  final FinanceController finance;
  final int months;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final data = <({DateTime month, int income, int expense})>[];
    var maxAmount = 0;
    for (var index = months - 1; index >= 0; index--) {
      final month = DateTime(now.year, now.month - index);
      final key =
          '${month.year.toString().padLeft(4, '0')}-${month.month.toString().padLeft(2, '0')}';
      final summary = finance.monthlySummaries[key];
      final income = summary?.incomeByCurrency[currency] ?? 0;
      final expense = summary?.expensesByCurrency[currency] ?? 0;
      data.add((month: month, income: income, expense: expense));
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
          SizedBox(
            height: 190,
            child: BarChart(
              BarChartData(
                maxY: maxAmount == 0 ? 1 : maxAmount.toDouble() * 1.18,
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
                gridData: const FlGridData(show: true, drawVerticalLine: false),
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
  });

  final List<CategorySpending> categories;
  final String currency;
  final int total;

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
              child: PieChart(
                PieChartData(
                  centerSpaceRadius: 40,
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
            ),
            ...categories.take(7).toList().asMap().entries.map((entry) {
              final item = entry.value;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
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
              );
            }),
          ],
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
  const _ReportData({required this.summary, required this.categories});

  final FinancialSummary summary;
  final List<CategorySpending> categories;
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
