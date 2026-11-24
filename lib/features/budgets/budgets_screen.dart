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

class BudgetsScreen extends StatelessWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceController>();
    final totals = <String, ({int limit, int spent})>{};
    final today = DateTime.now();
    for (final budget in finance.budgets) {
      if (today.isBefore(budget.startDate) || today.isAfter(budget.endDate)) {
        continue;
      }
      final progress = finance.budgetProgress(budget);
      final previous = totals[budget.currencyCode] ?? (limit: 0, spent: 0);
      totals[budget.currencyCode] = (
        limit: previous.limit + budget.limitMinor,
        spent: previous.spent + progress.spentMinor,
      );
    }

    return GlassScaffold(
      padding: const EdgeInsets.symmetric(horizontal: 17),
      child: ListView(
        padding: const EdgeInsets.only(top: 10, bottom: 28),
        children: [
          ScreenHeader(
            title: 'My Budgets',
            subtitle: 'Make a plan for what matters.',
            trailing: IconButton.filled(
              tooltip: 'Create budget',
              onPressed: () => _editBudget(context),
              icon: const Icon(Icons.add_rounded),
            ),
          ),
          if (totals.isNotEmpty)
            ...totals.entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: _BudgetSummary(
                  currency: entry.key,
                  limit: entry.value.limit,
                  spent: entry.value.spent,
                ),
              ),
            ),
          if (finance.budgets.isEmpty)
            GlassEmptyState(
              title: 'Create your first budget',
              message: 'Set monthly or custom date ranges for the categories you want to manage.',
              icon: Icons.pie_chart_outline_rounded,
              action: GlassButton(
                label: 'Create budget',
                icon: Icons.add,
                onPressed: () => _editBudget(context),
              ),
            )
          else
            ...finance.budgets.map(
              (budget) => _BudgetCard(
                budget: budget,
                progress: finance.budgetProgress(budget),
                onEdit: () => _editBudget(context, budget),
                onDelete: () => _deleteBudget(context, budget),
              ),
            ),
          const SizedBox(height: 8),
          const _BudgetRuleNote(),
        ],
      ),
    );
  }
}

class _BudgetSummary extends StatelessWidget {
  const _BudgetSummary({
    required this.currency,
    required this.limit,
    required this.spent,
  });

  final String currency;
  final int limit;
  final int spent;

  @override
  Widget build(BuildContext context) {
    final remaining = limit - spent;
    return GlassContainer(
      padding: const EdgeInsets.all(14),
      radius: 17,
      blur: 7,
      child: Row(
        children: [
          const CircleAvatar(
            radius: 19,
            backgroundColor: Color(0x1F0BA98D),
            child: Icon(Icons.pie_chart_outline_rounded, color: AppColors.tealDark, size: 20),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Active allocation · $currency', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 3),
                Text('${formatMinorUnits(spent, currency)} spent of ${formatMinorUnits(limit, currency)}', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          Text(
            '${formatMinorUnits(remaining, currency)} left',
            textAlign: TextAlign.end,
            style: TextStyle(
              color: remaining < 0 ? AppColors.expense : AppColors.tealDark,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({
    required this.budget,
    required this.progress,
    required this.onEdit,
    required this.onDelete,
  });

  final FinancialBudget budget;
  final BudgetProgress progress;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final color = progress.usagePercent >= 100
        ? AppColors.expense
        : progress.usagePercent >= 90
        ? AppColors.amber
        : AppColors.teal;
    final ratio = budget.limitMinor == 0
        ? 0.0
        : (progress.spentMinor / budget.limitMinor).clamp(0, 1).toDouble();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassContainer(
        padding: const EdgeInsets.all(15),
        radius: 19,
        blur: 8,
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 43,
                  height: 43,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.pie_chart_outline_rounded, color: color),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(budget.name, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        budget.categoryIds.isEmpty
                            ? 'All expense categories'
                            : budget.categoryIds.join(', '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') onEdit();
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit budget')),
                    PopupMenuItem(value: 'delete', child: Text('Archive budget')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 13),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    formatMinorUnits(progress.spentMinor, budget.currencyCode),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Text('of ${formatMinorUnits(budget.limitMinor, budget.currencyCode)}', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(width: 6),
                Text('${progress.usagePercent}%', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 8,
                color: color,
                backgroundColor: color.withValues(alpha: 0.13),
              ),
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                Expanded(
                  child: Text(
                    progress.usagePercent >= 100
                        ? 'Budget exceeded'
                        : progress.usagePercent >= 90
                        ? 'Almost exhausted'
                        : progress.usagePercent >= budget.alertPercentage
                        ? 'Spending is approaching your limit'
                        : 'Remaining',
                    style: TextStyle(
                      color: progress.usagePercent >= budget.alertPercentage
                          ? color
                          : Theme.of(context).textTheme.bodySmall?.color,
                      fontSize: 11,
                      fontWeight: FontWeight.w650,
                    ),
                  ),
                ),
                Text(
                  formatMinorUnits(progress.remainingMinor, budget.currencyCode),
                  style: TextStyle(
                    color: progress.remainingMinor < 0
                        ? AppColors.expense
                        : Theme.of(context).colorScheme.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${_date(budget.startDate)} – ${_date(budget.endDate)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BudgetRuleNote extends StatelessWidget {
  const _BudgetRuleNote();

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(12),
      radius: 15,
      blur: 5,
      child: Text(
        'Only expenses in the selected categories count toward a budget. Transfers are excluded and refunds reduce eligible spending.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

Future<void> _editBudget(
  BuildContext context, [
  FinancialBudget? existing,
]) async {
  final finance = context.read<FinanceController>();
  final name = TextEditingController(text: existing?.name ?? '');
  final limit = TextEditingController(
    text: existing == null
        ? ''
        : _moneyInput(existing.limitMinor, existing.currencyCode),
  );
  final formKey = GlobalKey<FormState>();
  var currency = existing?.currencyCode ?? finance.preferredCurrency;
  var selectedCategories = <String>{...?existing?.categoryIds};
  var alertPercentage = existing?.alertPercentage ?? 70;
  var start = existing?.startDate ?? DateTime(DateTime.now().year, DateTime.now().month);
  var end = existing?.endDate ?? DateTime(DateTime.now().year, DateTime.now().month + 1, 0);
  final availableCategories = finance.categories
      .where((item) => item['type'] == 'expense' && (item['is_active'] as int? ?? 1) == 1)
      .map((item) => item['name']! as String)
      .toList();
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(existing == null ? 'Create budget' : 'Edit budget'),
        content: SizedBox(
          width: 440,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GlassTextField(controller: name, label: 'Budget name', icon: Icons.edit_outlined, validator: (value) => Validators.required(value, 'Budget name')),
                  const SizedBox(height: 10),
                  GlassTextField(
                    controller: limit,
                    label: 'Limit ($currency)',
                    icon: Icons.payments_outlined,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      try {
                        parseMinorUnits(value ?? '', currency);
                        return null;
                      } on FormatException catch (error) {
                        return error.message;
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: currency,
                    decoration: const InputDecoration(labelText: 'Budget currency'),
                    items: AppConstants.supportedCurrencies.keys.map((code) => DropdownMenuItem(value: code, child: Text(code))).toList(),
                    onChanged: (value) => setState(() => currency = value ?? currency),
                  ),
                  const SizedBox(height: 14),
                  Align(alignment: Alignment.centerLeft, child: Text('Categories · leave empty for all', style: Theme.of(context).textTheme.titleMedium)),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 5,
                    children: availableCategories.map((category) => FilterChip(
                      label: Text(category),
                      selected: selectedCategories.contains(category),
                      onSelected: (selected) => setState(() {
                        if (selected) {
                          selectedCategories.add(category);
                        } else {
                          selectedCategories.remove(category);
                        }
                      }),
                    )).toList(),
                  ),
                  DropdownButtonFormField<int>(
                    initialValue: alertPercentage,
                    decoration: const InputDecoration(labelText: 'Alert me at'),
                    items: const [
                      DropdownMenuItem(value: 70, child: Text('70% · approaching limit')),
                      DropdownMenuItem(value: 90, child: Text('90% · almost exhausted')),
                    ],
                    onChanged: (value) => setState(() => alertPercentage = value ?? alertPercentage),
                  ),
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      Expanded(child: OutlinedButton.icon(onPressed: () async {
                        final value = await showDatePicker(context: context, initialDate: start, firstDate: DateTime(2000), lastDate: DateTime.now().add(const Duration(days: 3660)));
                        if (value != null) setState(() => start = value);
                      }, icon: const Icon(Icons.calendar_today_outlined, size: 16), label: Text('From ${_date(start)}'))),
                      const SizedBox(width: 7),
                      Expanded(child: OutlinedButton.icon(onPressed: () async {
                        final value = await showDatePicker(context: context, initialDate: end.isBefore(start) ? start : end, firstDate: start, lastDate: DateTime.now().add(const Duration(days: 3660)));
                        if (value != null) setState(() => end = value);
                      }, icon: const Icon(Icons.event_outlined, size: 16), label: Text('To ${_date(end)}'))),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              try {
                final now = DateTime.now();
                await finance.saveBudget(FinancialBudget(
                  id: existing?.id ?? FinanceRepository.createId(),
                  userId: finance.userId!,
                  name: name.text.trim(),
                  limitMinor: parseMinorUnits(limit.text, currency),
                  currencyCode: currency,
                  startDate: start,
                  endDate: end,
                  categoryIds: selectedCategories.toList()..sort(),
                  alertPercentage: alertPercentage,
                  createdAt: existing?.createdAt ?? now,
                  updatedAt: now,
                ));
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                if (context.mounted) showAppMessage(context, 'Budget saved.');
              } catch (error) {
                if (dialogContext.mounted) showAppMessage(dialogContext, error.toString(), isError: true);
              }
            },
            child: Text(existing == null ? 'Create budget' : 'Save changes'),
          ),
        ],
      ),
    ),
  );
  name.dispose();
  limit.dispose();
}

Future<void> _deleteBudget(BuildContext context, FinancialBudget budget) async {
  final confirmed = await confirmAction(
    context,
    title: 'Archive this budget?',
    message: 'Past transactions remain unchanged.',
    confirmLabel: 'Archive',
  );
  if (!confirmed || !context.mounted) return;
  try {
    await context.read<FinanceController>().deleteBudget(budget.id);
    if (context.mounted) showAppMessage(context, 'Budget archived.');
  } catch (error) {
    if (context.mounted) showAppMessage(context, error.toString(), isError: true);
  }
}

String _date(DateTime date) => '${date.day}/${date.month}/${date.year}';

String _moneyInput(int minor, String currency) {
  final scale = currencyFractionDigits(currency);
  final multiplier = scale == 0 ? 1 : 100;
  final whole = minor ~/ multiplier;
  final fraction = minor % multiplier;
  return scale == 0 ? '$whole' : '$whole.${fraction.toString().padLeft(scale, '0')}';
}
