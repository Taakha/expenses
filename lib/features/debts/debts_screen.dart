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

class DebtsScreen extends StatelessWidget {
  const DebtsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceController>();
    final totals = <String, ({int borrowed, int lent})>{};
    for (final debt in finance.debts.where((item) => item.status != 'settled')) {
      final previous = totals[debt.currencyCode] ?? (borrowed: 0, lent: 0);
      totals[debt.currencyCode] = debt.type == 'borrowed'
          ? (borrowed: previous.borrowed + finance.debtOutstanding(debt), lent: previous.lent)
          : (borrowed: previous.borrowed, lent: previous.lent + finance.debtOutstanding(debt));
    }

    return GlassScaffold(
      padding: const EdgeInsets.symmetric(horizontal: 17),
      child: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 26),
        children: [
          ScreenHeader(
            title: 'Debts',
            subtitle: 'Keep track of what is owed.',
            trailing: IconButton.filled(
              tooltip: 'Add debt',
              onPressed: () => _showDebtForm(context),
              icon: const Icon(Icons.add_rounded),
            ),
            showBack: true,
          ),
          if (totals.isNotEmpty)
            ...totals.entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GlassContainer(
                  padding: const EdgeInsets.all(13),
                  radius: 16,
                  blur: 6,
                  child: Row(
                    children: [
                      const Icon(Icons.handshake_outlined, color: AppColors.tealDark),
                      const SizedBox(width: 9),
                      Expanded(child: Text(entry.key, style: Theme.of(context).textTheme.titleMedium)),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Owed by you ${formatMinorUnits(entry.value.borrowed, entry.key)}', style: const TextStyle(fontSize: 10, color: AppColors.expense)),
                          Text('Owed to you ${formatMinorUnits(entry.value.lent, entry.key)}', style: const TextStyle(fontSize: 10, color: AppColors.income)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (finance.debts.isEmpty)
            GlassEmptyState(
              title: 'No debt records',
              message: 'Track a loan, repayment or money owed to you.',
              icon: Icons.handshake_outlined,
              action: GlassButton(
                label: 'Add debt',
                icon: Icons.add,
                onPressed: () => _showDebtForm(context),
              ),
            )
          else
            ...finance.debts.map(
              (debt) => _DebtCard(
                debt: debt,
                remaining: finance.debtOutstanding(debt),
                onPayment: () => _showPaymentDialog(context, debt),
              ),
            ),
          const SizedBox(height: 7),
          GlassContainer(
            padding: const EdgeInsets.all(12),
            radius: 15,
            blur: 5,
            child: Text(
              'Recording a repayment or collection against an account also creates the matching expense or income entry in your ledger.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _DebtCard extends StatelessWidget {
  const _DebtCard({
    required this.debt,
    required this.remaining,
    required this.onPayment,
  });

  final DebtRecord debt;
  final int remaining;
  final VoidCallback onPayment;

  @override
  Widget build(BuildContext context) {
    final settled = remaining == 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: GlassContainer(
        padding: const EdgeInsets.all(14),
        radius: 18,
        blur: 7,
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: (settled ? AppColors.income : AppColors.amber).withValues(alpha: 0.15),
              child: Icon(
                debt.type == 'borrowed' ? Icons.call_made_rounded : Icons.call_received_rounded,
                color: settled ? AppColors.income : AppColors.amber,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(debt.personName, style: Theme.of(context).textTheme.titleMedium),
                  Text(
                    '${debt.type == 'borrowed' ? 'Owed by you' : 'Owed to you'}${debt.dueDate == null ? '' : ' · due ${_date(debt.dueDate!)}'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (debt.notes.isNotEmpty)
                    Text(debt.notes, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatMinorUnits(remaining, debt.currencyCode),
                  style: TextStyle(
                    color: settled ? AppColors.income : AppColors.tealDark,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(settled ? 'Settled' : 'remaining', style: Theme.of(context).textTheme.bodySmall),
                if (!settled)
                  TextButton(
                    onPressed: onPayment,
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: EdgeInsets.zero),
                    child: Text(debt.type == 'borrowed' ? 'Repay' : 'Collect'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showDebtForm(BuildContext context) async {
  final formKey = GlobalKey<FormState>();
  final person = TextEditingController();
  final amount = TextEditingController();
  final notes = TextEditingController();
  var type = 'borrowed';
  var currency = context.read<FinanceController>().preferredCurrency;
  DateTime? dueDate;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Add a debt'),
        content: SizedBox(
          width: 420,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GlassTextField(controller: person, label: 'Person or institution', icon: Icons.person_outline, validator: (value) => Validators.required(value, 'Name')),
                  const SizedBox(height: 9),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'borrowed', label: Text('I owe')),
                      ButtonSegment(value: 'lent', label: Text('Owed to me')),
                    ],
                    selected: {type},
                    onSelectionChanged: (value) => setState(() => type = value.first),
                  ),
                  const SizedBox(height: 9),
                  DropdownButtonFormField<String>(
                    initialValue: currency,
                    decoration: const InputDecoration(labelText: 'Currency'),
                    items: AppConstants.supportedCurrencies.keys.map((code) => DropdownMenuItem(value: code, child: Text(code))).toList(),
                    onChanged: (value) => setState(() => currency = value ?? currency),
                  ),
                  const SizedBox(height: 9),
                  GlassTextField(
                    controller: amount,
                    label: 'Principal ($currency)',
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
                  const SizedBox(height: 9),
                  GlassTextField(controller: notes, label: 'Notes (optional)', icon: Icons.notes_outlined, maxLines: 2),
                  TextButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: dueDate ?? DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 3650)),
                      );
                      if (picked != null) setState(() => dueDate = picked);
                    },
                    icon: const Icon(Icons.event_outlined),
                    label: Text(dueDate == null ? 'Set due date (optional)' : 'Due ${_date(dueDate!)}'),
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
                final finance = context.read<FinanceController>();
                final now = DateTime.now();
                await finance.saveDebt(DebtRecord(
                  id: FinanceRepository.createId(),
                  userId: finance.userId!,
                  personName: person.text.trim(),
                  type: type,
                  principalMinor: parseMinorUnits(amount.text, currency),
                  currencyCode: currency,
                  dueDate: dueDate,
                  notes: notes.text.trim(),
                  createdAt: now,
                  updatedAt: now,
                ));
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                if (context.mounted) showAppMessage(context, 'Debt record saved.');
              } catch (error) {
                if (dialogContext.mounted) showAppMessage(dialogContext, error.toString(), isError: true);
              }
            },
            child: const Text('Save debt'),
          ),
        ],
      ),
    ),
  );
  person.dispose();
  amount.dispose();
  notes.dispose();
}

Future<void> _showPaymentDialog(BuildContext context, DebtRecord debt) async {
  final finance = context.read<FinanceController>();
  final amount = TextEditingController();
  final formKey = GlobalKey<FormState>();
  final matchingAccounts = finance.activeAccounts
      .where((account) => account.currencyCode == debt.currencyCode)
      .toList();
  var accountId = '';
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(debt.type == 'borrowed' ? 'Record repayment' : 'Record collection'),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Outstanding: ${formatMinorUnits(finance.debtOutstanding(debt), debt.currencyCode)}'),
            const SizedBox(height: 10),
            GlassTextField(
              controller: amount,
              label: 'Amount (${debt.currencyCode})',
              icon: Icons.payments_outlined,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                try {
                  parseMinorUnits(value ?? '', debt.currencyCode);
                  return null;
                } on FormatException catch (error) {
                  return error.message;
                }
              },
            ),
            const SizedBox(height: 9),
            DropdownButtonFormField<String>(
              initialValue: '',
              decoration: const InputDecoration(labelText: 'Account (optional)'),
              items: [
                const DropdownMenuItem(value: '', child: Text('Track only; no account movement')),
                ...matchingAccounts.map((account) => DropdownMenuItem(value: account.id, child: Text(account.name))),
              ],
              onChanged: (value) => accountId = value ?? '',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
        FilledButton(
          onPressed: () async {
            if (!formKey.currentState!.validate()) return;
            try {
              await finance.recordDebtPayment(
                debtId: debt.id,
                amountMinor: parseMinorUnits(amount.text, debt.currencyCode),
                paymentType: debt.type == 'borrowed' ? 'repayment' : 'collection',
                accountId: accountId.isEmpty ? null : accountId,
              );
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              if (context.mounted) showAppMessage(context, 'Payment recorded.');
            } catch (error) {
              if (dialogContext.mounted) showAppMessage(dialogContext, error.toString(), isError: true);
            }
          },
          child: const Text('Record'),
        ),
      ],
    ),
  );
  amount.dispose();
}

String _date(DateTime date) => '${date.day}/${date.month}/${date.year}';
