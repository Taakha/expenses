import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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

class RecurringScreen extends StatelessWidget {
  const RecurringScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceController>();
    final rules = finance.recurringRules;
    return GlassScaffold(
      padding: const EdgeInsets.symmetric(horizontal: 17),
      child: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 25),
        children: [
          ScreenHeader(
            title: 'Recurring',
            subtitle: 'Review scheduled income and expenses.',
            trailing: IconButton.filled(
              tooltip: 'Add recurring transaction',
              onPressed: () => _showRecurringForm(context),
              icon: const Icon(Icons.add_rounded),
            ),
            showBack: true,
          ),
          if (rules.isEmpty)
            GlassEmptyState(
              title: 'No recurring transactions',
              message: 'Set up rent, subscriptions, bills or regular income.',
              icon: Icons.autorenew_rounded,
              action: GlassButton(
                label: 'Add schedule',
                icon: Icons.add,
                onPressed: () => _showRecurringForm(context),
              ),
            )
          else
            ...rules.map((rule) => _RecurringCard(rule: rule)),
          const SizedBox(height: 8),
          GlassContainer(
            padding: const EdgeInsets.all(12),
            radius: 15,
            blur: 5,
            child: Text(
              'Due entries are created locally when you open the app. Each occurrence has a stable ID to prevent duplicates after a restart.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecurringCard extends StatelessWidget {
  const _RecurringCard({required this.rule});

  final RecurringRule rule;

  @override
  Widget build(BuildContext context) {
    final finance = context.read<FinanceController>();
    final account = finance.accounts.where((item) => item.id == rule.accountId).firstOrNull;
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: GlassContainer(
        padding: const EdgeInsets.all(14),
        radius: 18,
        blur: 7,
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: (rule.isActive ? AppColors.teal : AppColors.amber).withValues(alpha: 0.15),
              child: Icon(
                rule.type == 'income' ? Icons.south_west_rounded : Icons.autorenew_rounded,
                color: rule.isActive ? AppColors.tealDark : AppColors.amber,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(rule.description, style: Theme.of(context).textTheme.titleMedium),
                  Text(
                    '${rule.frequency} · ${rule.category} · ${account?.name ?? 'Account unavailable'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    rule.isActive ? 'Next ${_date(rule.nextOccurrence)}' : 'Paused',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: rule.isActive ? AppColors.tealDark : AppColors.amber,
                        ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(formatMinorUnits(rule.amountMinor, rule.currencyCode), style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(rule.type, style: Theme.of(context).textTheme.bodySmall),
                TextButton(
                  onPressed: () async {
                    try {
                      await finance.saveRecurring(RecurringRule(
                        id: rule.id,
                        userId: rule.userId,
                        accountId: rule.accountId,
                        type: rule.type,
                        amountMinor: rule.amountMinor,
                        currencyCode: rule.currencyCode,
                        category: rule.category,
                        description: rule.description,
                        frequency: rule.frequency,
                        nextOccurrence: rule.nextOccurrence,
                        endDate: rule.endDate,
                        isActive: !rule.isActive,
                        createdAt: rule.createdAt,
                        updatedAt: DateTime.now(),
                      ));
                      if (context.mounted) showAppMessage(context, rule.isActive ? 'Schedule paused.' : 'Schedule resumed.');
                    } catch (error) {
                      if (context.mounted) showAppMessage(context, error.toString(), isError: true);
                    }
                  },
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: EdgeInsets.zero),
                  child: Text(rule.isActive ? 'Pause' : 'Resume'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showRecurringForm(BuildContext context) async {
  final finance = context.read<FinanceController>();
  final formKey = GlobalKey<FormState>();
  final description = TextEditingController();
  final amount = TextEditingController();
  var type = 'expense';
  var frequency = 'monthly';
  String? accountId = finance.activeAccounts.firstOrNull?.id;
  String? category;
  DateTime nextDate = DateTime.now();
  DateTime? endDate;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) {
        final account = finance.activeAccounts
            .where((item) => item.id == accountId)
            .firstOrNull;
        final categories = finance.categories
            .where((item) => item['type'] == type && (item['is_active'] as int? ?? 1) == 1)
            .map((item) => item['name']! as String)
            .toList();
        final selectedCategory = categories.contains(category) ? category : null;
        return AlertDialog(
          title: const Text('Add recurring transaction'),
          content: SizedBox(
            width: 440,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'expense', label: Text('Expense')),
                        ButtonSegment(value: 'income', label: Text('Income')),
                      ],
                      selected: {type},
                      onSelectionChanged: (value) => setState(() {
                        type = value.first;
                        category = null;
                      }),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: accountId,
                      decoration: const InputDecoration(labelText: 'Account'),
                      items: finance.activeAccounts
                          .map((item) => DropdownMenuItem(value: item.id, child: Text('${item.name} · ${item.currencyCode}')))
                          .toList(),
                      validator: (value) => value == null ? 'Add an active account first.' : null,
                      onChanged: (value) => setState(() => accountId = value),
                    ),
                    const SizedBox(height: 9),
                    GlassTextField(
                      controller: amount,
                      label: 'Amount (${account?.currencyCode ?? finance.preferredCurrency})',
                      icon: Icons.payments_outlined,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        try {
                          parseMinorUnits(value ?? '', account?.currencyCode ?? finance.preferredCurrency);
                          return null;
                        } on FormatException catch (error) {
                          return error.message;
                        }
                      },
                    ),
                    const SizedBox(height: 9),
                    GlassTextField(
                      controller: description,
                      label: 'Description',
                      icon: Icons.edit_outlined,
                      validator: (value) => Validators.required(value, 'Description'),
                    ),
                    const SizedBox(height: 9),
                    DropdownButtonFormField<String>(
                      initialValue: selectedCategory,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: categories.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
                      validator: (value) => value == null ? 'Choose a category.' : null,
                      onChanged: (value) => setState(() => category = value),
                    ),
                    const SizedBox(height: 9),
                    DropdownButtonFormField<String>(
                      initialValue: frequency,
                      decoration: const InputDecoration(labelText: 'Frequency'),
                      items: const [
                        DropdownMenuItem(value: 'daily', child: Text('Daily')),
                        DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                        DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                        DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
                      ],
                      onChanged: (value) => setState(() => frequency = value ?? frequency),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton.icon(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: nextDate,
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 3650)),
                              );
                              if (picked != null) setState(() => nextDate = picked);
                            },
                            icon: const Icon(Icons.event_outlined),
                            label: Text('Starts ${_date(nextDate)}'),
                          ),
                        ),
                        Expanded(
                          child: TextButton.icon(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: endDate == null || endDate!.isBefore(nextDate)
                                    ? nextDate
                                    : endDate!,
                                firstDate: nextDate,
                                lastDate: DateTime.now().add(const Duration(days: 3650)),
                              );
                              if (picked != null) setState(() => endDate = picked);
                            },
                            icon: const Icon(Icons.event_available_outlined),
                            label: Text(endDate == null ? 'No end date' : 'Ends ${_date(endDate!)}'),
                          ),
                        ),
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
                final selectedAccount = account;
                if (selectedAccount == null) return;
                try {
                  final now = DateTime.now();
                  await finance.saveRecurring(RecurringRule(
                    id: FinanceRepository.createId(),
                    userId: finance.userId!,
                    accountId: selectedAccount.id,
                    type: type,
                    amountMinor: parseMinorUnits(amount.text, selectedAccount.currencyCode),
                    currencyCode: selectedAccount.currencyCode,
                    category: category!,
                    description: description.text.trim(),
                    frequency: frequency,
                    nextOccurrence: nextDate,
                    endDate: endDate,
                    isActive: true,
                    createdAt: now,
                    updatedAt: now,
                  ));
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  if (context.mounted) showAppMessage(context, 'Recurring transaction saved.');
                } catch (error) {
                  if (dialogContext.mounted) showAppMessage(dialogContext, error.toString(), isError: true);
                }
              },
              child: const Text('Save schedule'),
            ),
          ],
        );
      },
    ),
  );
  description.dispose();
  amount.dispose();
}

String _date(DateTime date) => '${date.day}/${date.month}/${date.year}';
