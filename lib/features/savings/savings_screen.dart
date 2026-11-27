import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/routes/route_names.dart';
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

class SavingsScreen extends StatelessWidget {
  const SavingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceController>();
    final totals = <String, int>{};
    for (final goal in finance.goals) {
      totals[goal.currencyCode] =
          (totals[goal.currencyCode] ?? 0) + finance.savingsTotal(goal);
    }
    return GlassScaffold(
      padding: const EdgeInsets.symmetric(horizontal: 17),
      child: ListView(
        padding: const EdgeInsets.only(top: 10, bottom: 25),
        children: [
          ScreenHeader(
            title: 'Savings Goals',
            subtitle: 'Small steps add up to big things.',
            trailing: IconButton.filled(
              tooltip: 'Add savings goal',
              onPressed: () =>
                  Navigator.pushNamed(context, RouteNames.savingsGoalAdd),
              icon: const Icon(Icons.add_rounded),
            ),
          ),
          if (totals.isNotEmpty)
            ...totals.entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GlassContainer(
                  padding: const EdgeInsets.all(14),
                  radius: 17,
                  blur: 7,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.savings_outlined,
                        color: AppColors.tealDark,
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Text(
                          'Total savings · ${entry.key}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      Text(
                        formatMinorUnits(entry.value, entry.key),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.tealDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (finance.goals.isEmpty)
            GlassEmptyState(
              title: 'Start a savings goal',
              message: 'Save toward an emergency fund, tuition, a trip or something special.',
              icon: Icons.flag_outlined,
              action: GlassButton(
                label: 'Add goal',
                icon: Icons.add,
                onPressed: () =>
                    Navigator.pushNamed(context, RouteNames.savingsGoalAdd),
              ),
            )
          else
            ...finance.goals.map(
              (goal) => _GoalCard(
                goal: goal,
                savedMinor: finance.savingsTotal(goal),
                onContribute: () => _showContribution(context, goal, false),
                onWithdraw: () => _showContribution(context, goal, true),
                onEdit: () => Navigator.pushNamed(
                  context,
                  RouteNames.savingsGoalAdd,
                  arguments: goal,
                ),
                onPause: () => _pauseGoal(context, goal),
              ),
            ),
          const SizedBox(height: 8),
          const _SavingsAccountingNote(),
        ],
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.goal,
    required this.savedMinor,
    required this.onContribute,
    required this.onWithdraw,
    required this.onEdit,
    required this.onPause,
  });

  final SavingsGoal goal;
  final int savedMinor;
  final VoidCallback onContribute;
  final VoidCallback onWithdraw;
  final VoidCallback onEdit;
  final VoidCallback onPause;

  @override
  Widget build(BuildContext context) {
    final ratio = goal.targetMinor <= 0
        ? 0.0
        : (savedMinor / goal.targetMinor).clamp(0, 1).toDouble();
    final percent = goal.targetMinor <= 0
        ? 0
        : savedMinor * 100 ~/ goal.targetMinor;
    final completed = savedMinor >= goal.targetMinor;
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: GlassContainer(
        padding: const EdgeInsets.all(15),
        radius: 20,
        blur: 8,
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 47,
                  height: 47,
                  decoration: BoxDecoration(
                    color: completed ? AppColors.tealDark : AppColors.accent,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    completed ? Icons.celebration_rounded : Icons.flag_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goal.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        completed
                            ? 'Goal reached!'
                            : 'Target ${_date(goal.targetDate)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') onEdit();
                    if (value == 'pause') onPause();
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit goal')),
                    PopupMenuItem(value: 'pause', child: Text('Pause goal')),
                  ],
                ),
              ],
            ),
            if (goal.description.isNotEmpty) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  goal.description,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
            const SizedBox(height: 13),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    formatMinorUnits(savedMinor, goal.currencyCode),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Text(
                  'of ${formatMinorUnits(goal.targetMinor, goal.currencyCode)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(width: 6),
                Text(
                  '$percent%',
                  style: const TextStyle(
                    color: AppColors.tealDark,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 8,
                color: completed ? AppColors.income : AppColors.teal,
                backgroundColor: AppColors.teal.withValues(alpha: 0.13),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onWithdraw,
                    icon: const Icon(Icons.south_west_rounded, size: 16),
                    label: const Text('Withdraw'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onContribute,
                    icon: const Icon(Icons.add_rounded, size: 17),
                    label: const Text('Add savings'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class SavingsGoalFormScreen extends StatefulWidget {
  const SavingsGoalFormScreen({super.key, this.existing});

  final SavingsGoal? existing;

  @override
  State<SavingsGoalFormScreen> createState() => _SavingsGoalFormScreenState();
}

class _SavingsGoalFormScreenState extends State<SavingsGoalFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _target;
  late final TextEditingController _description;
  late String _currency;
  late DateTime _date;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final goal = widget.existing;
    _name = TextEditingController(text: goal?.name ?? '');
    _target = TextEditingController(
      text: goal == null
          ? ''
          : _moneyInput(goal.targetMinor, goal.currencyCode),
    );
    _description = TextEditingController(text: goal?.description ?? '');
    _currency = goal?.currencyCode ?? 'UGX';
    _date = goal?.targetDate ?? DateTime.now().add(const Duration(days: 90));
  }

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final finance = context.read<FinanceController>();
      final now = DateTime.now();
      await finance.saveGoal(
        SavingsGoal(
          id: widget.existing?.id ?? FinanceRepository.createId(),
          userId: finance.userId!,
          name: _name.text.trim(),
          targetMinor: parseMinorUnits(_target.text, _currency),
          currencyCode: _currency,
          targetDate: _date,
          description: _description.text.trim(),
          status: widget.existing?.status ?? 'active',
          createdAt: widget.existing?.createdAt ?? now,
          updatedAt: now,
        ),
      );
      if (!mounted) return;
      showAppMessage(context, 'Savings goal saved.');
      Navigator.pop(context);
    } catch (error) {
      if (mounted) showAppMessage(context, error.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      padding: const EdgeInsets.symmetric(horizontal: 17),
      child: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 25),
        children: [
          ScreenHeader(
            title: widget.existing == null
                ? 'Create savings goal'
                : 'Edit savings goal',
            subtitle: 'Choose a target and a date that works for you.',
            showBack: true,
          ),
          GlassContainer(
            padding: const EdgeInsets.all(16),
            radius: 21,
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 78,
                      height: 78,
                      decoration: BoxDecoration(
                        color: AppColors.teal.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: const Icon(
                        Icons.track_changes_rounded,
                        color: AppColors.teal,
                        size: 40,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  GlassTextField(
                    controller: _name,
                    label: 'Goal name',
                    icon: Icons.flag_outlined,
                    validator: (value) =>
                        Validators.required(value, 'Goal name'),
                  ),
                  const SizedBox(height: 11),
                  GlassTextField(
                    controller: _target,
                    label: 'Target amount ($_currency)',
                    icon: Icons.payments_outlined,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (value) {
                      try {
                        parseMinorUnits(value ?? '', _currency);
                        return null;
                      } on FormatException catch (error) {
                        return error.message;
                      }
                    },
                  ),
                  const SizedBox(height: 11),
                  DropdownButtonFormField<String>(
                    initialValue: _currency,
                    decoration: const InputDecoration(labelText: 'Currency'),
                    items: AppConstants.supportedCurrencies.keys
                        .map(
                          (code) =>
                              DropdownMenuItem(value: code, child: Text(code)),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _currency = value ?? _currency),
                  ),
                  const SizedBox(height: 11),
                  GlassTextField(
                    controller: _description,
                    label: 'Goal description (optional)',
                    icon: Icons.notes_outlined,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 6),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_outlined),
                    title: const Text('Target date'),
                    subtitle: Text(
                      MaterialLocalizations.of(context).formatMediumDate(_date),
                    ),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _date,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(
                          const Duration(days: 3650),
                        ),
                      );
                      if (date != null) setState(() => _date = date);
                    },
                  ),
                  GlassButton(
                    label: widget.existing == null
                        ? 'Create Goal'
                        : 'Save changes',
                    onPressed: _busy ? null : _save,
                    isLoading: _busy,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SavingsAccountingNote extends StatelessWidget {
  const _SavingsAccountingNote();

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(12),
      radius: 15,
      blur: 5,
      child: Text(
        'Goal contributions are tracked separately and do not change account balances. Use a transfer to move real money between accounts.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

Future<void> _showContribution(
  BuildContext context,
  SavingsGoal goal,
  bool withdrawal,
) async {
  final controller = TextEditingController();
  final formKey = GlobalKey<FormState>();
  final finance = context.read<FinanceController>();
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(withdrawal ? 'Withdraw from goal' : 'Add to savings'),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Current savings: ${formatMinorUnits(finance.savingsTotal(goal), goal.currencyCode)}',
            ),
            const SizedBox(height: 12),
            GlassTextField(
              controller: controller,
              label: 'Amount (${goal.currencyCode})',
              icon: Icons.payments_outlined,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (value) {
                try {
                  parseMinorUnits(value ?? '', goal.currencyCode);
                  return null;
                } on FormatException catch (error) {
                  return error.message;
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            if (!formKey.currentState!.validate()) return;
            try {
              await finance.contribute(
                goalId: goal.id,
                amountMinor: parseMinorUnits(
                  controller.text,
                  goal.currencyCode,
                ),
                currencyCode: goal.currencyCode,
                withdrawal: withdrawal,
              );
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              if (context.mounted) {
                showAppMessage(
                  context,
                  withdrawal
                      ? 'Withdrawal recorded.'
                      : 'Savings contribution recorded.',
                );
              }
            } catch (error) {
              if (dialogContext.mounted) {
                showAppMessage(dialogContext, error.toString(), isError: true);
              }
            }
          },
          child: Text(withdrawal ? 'Withdraw' : 'Add savings'),
        ),
      ],
    ),
  );
  controller.dispose();
}

Future<void> _pauseGoal(BuildContext context, SavingsGoal goal) async {
  final confirmed = await confirmAction(
    context,
    title: 'Pause this goal?',
    message: 'Your savings history will be kept.',
    confirmLabel: 'Pause',
  );
  if (!confirmed || !context.mounted) return;
  try {
    await context.read<FinanceController>().pauseGoal(goal.id);
    if (context.mounted) {
      showAppMessage(context, 'Goal paused.');
    }
  } catch (error) {
    if (context.mounted) {
      showAppMessage(context, error.toString(), isError: true);
    }
  }
}

String _date(DateTime date) => '${date.day}/${date.month}/${date.year}';

String _moneyInput(int minor, String currency) {
  final scale = currencyFractionDigits(currency);
  final multiplier = scale == 0 ? 1 : 100;
  final whole = minor ~/ multiplier;
  final fraction = minor % multiplier;
  return scale == 0
      ? '$whole'
      : '$whole.${fraction.toString().padLeft(scale, '0')}';
}
