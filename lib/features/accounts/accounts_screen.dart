import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/finance_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/money.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/glass_text_field.dart';
import '../../core/widgets/screen_header.dart';
import '../../data/models/finance_models.dart';
import '../../data/repositories/finance_repository.dart';

class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceController>();
    final active = finance.accounts.where((account) => !account.isArchived);
    final archived = finance.accounts.where((account) => account.isArchived);
    return GlassScaffold(
      padding: const EdgeInsets.symmetric(horizontal: 17),
      child: ListView(
        padding: const EdgeInsets.only(top: 10, bottom: 24),
        children: [
          ScreenHeader(
            title: 'Accounts',
            subtitle: 'Keep your money in the right places.',
            trailing: IconButton.filled(
              tooltip: 'Add account',
              onPressed: () => _editAccount(context),
              icon: const Icon(Icons.add_rounded),
            ),
          ),
          if (finance.accounts.isEmpty)
            const GlassEmptyState(
              title: 'Add your first account',
              message: 'Create a cash, bank, mobile money or savings account.',
              icon: Icons.account_balance_wallet_outlined,
            )
          else ...[
            ...active.map(
              (account) => _AccountCard(
                account: account,
                balanceMinor: finance.accountBalance(account),
                onEdit: () => _editAccount(context, account),
                onArchive: () => _archiveAccount(context, account),
              ),
            ),
            if (archived.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Archived', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ...archived.map(
                (account) => _AccountCard(
                  account: account,
                  balanceMinor: finance.accountBalance(account),
                  archived: true,
                ),
              ),
            ],
          ],
          const SizedBox(height: 10),
          const _CurrencySafetyNote(),
        ],
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.account,
    required this.balanceMinor,
    this.onEdit,
    this.onArchive,
    this.archived = false,
  });

  final FinancialAccount account;
  final int balanceMinor;
  final VoidCallback? onEdit;
  final VoidCallback? onArchive;
  final bool archived;

  @override
  Widget build(BuildContext context) {
    final icon = switch (account.type) {
      'Cash' => Icons.account_balance_wallet_outlined,
      'Bank' => Icons.account_balance_outlined,
      'Mobile Money' => Icons.phone_android_rounded,
      'Savings' => Icons.savings_outlined,
      _ => Icons.wallet_outlined,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassContainer(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        radius: 19,
        blur: 8,
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.teal.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: AppColors.tealDark, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(child: Text(account.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium)),
                      if (archived) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.archive_outlined, size: 13),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text('${account.type} · ${account.currencyCode}', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 5),
                  Text(
                    formatMinorUnits(balanceMinor, account.currencyCode),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
            if (!archived)
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') onEdit?.call();
                  if (value == 'archive') onArchive?.call();
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit account')),
                  PopupMenuItem(value: 'archive', child: Text('Archive account')),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _CurrencySafetyNote extends StatelessWidget {
  const _CurrencySafetyNote();

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(13),
      radius: 16,
      blur: 5,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 18, color: AppColors.tealDark),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'Accounts keep their original currencies. Money Wise never adds different currencies together without an exchange rate.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _editAccount(
  BuildContext context, [
  FinancialAccount? existing,
]) async {
  final controller = context.read<FinanceController>();
  final name = TextEditingController(text: existing?.name ?? '');
  final balance = TextEditingController(
    text: existing == null
        ? '0'
        : _formattedInput(existing.openingBalanceMinor, existing.currencyCode),
  );
  final formKey = GlobalKey<FormState>();
  var accountType = existing?.type ?? 'Cash';
  var currency = existing?.currencyCode ?? controller.preferredCurrency;
  var overdraft = existing?.allowOverdraft ?? false;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(existing == null ? 'New account' : 'Edit account'),
        content: SizedBox(
          width: 420,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GlassTextField(
                    controller: name,
                    label: 'Account name',
                    icon: Icons.wallet_outlined,
                    validator: (value) => Validators.required(value, 'Account name'),
                  ),
                  const SizedBox(height: 11),
                  DropdownButtonFormField<String>(
                    initialValue: accountType,
                    decoration: const InputDecoration(labelText: 'Account type'),
                    items: AppConstants.accountTypes
                        .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                        .toList(),
                    onChanged: (value) => setState(() => accountType = value ?? accountType),
                  ),
                  const SizedBox(height: 11),
                  DropdownButtonFormField<String>(
                    initialValue: currency,
                    decoration: const InputDecoration(labelText: 'Currency'),
                    items: AppConstants.supportedCurrencies.keys
                        .map((code) => DropdownMenuItem(value: code, child: Text('$code · ${AppConstants.supportedCurrencies[code]}')))
                        .toList(),
                    onChanged: existing == null
                        ? (value) => setState(() => currency = value ?? currency)
                        : null,
                  ),
                  const SizedBox(height: 11),
                  GlassTextField(
                    controller: balance,
                    label: existing == null ? 'Opening balance' : 'Opening balance',
                    icon: Icons.payments_outlined,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      try {
                        parseMinorUnits(value ?? '', currency, allowZero: true);
                        return null;
                      } on FormatException catch (error) {
                        return error.message;
                      }
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: overdraft,
                    onChanged: (value) => setState(() => overdraft = value),
                    title: const Text('Allow overdraft'),
                    subtitle: const Text('Permit this account to go below zero'),
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
              final now = DateTime.now();
              try {
                await controller.saveAccount(
                  FinancialAccount(
                    id: existing?.id ?? FinanceRepository.createId(),
                    userId: controller.userId!,
                    name: name.text.trim(),
                    type: accountType,
                    currencyCode: currency,
                    openingBalanceMinor: parseMinorUnits(balance.text, currency, allowZero: true),
                    allowOverdraft: overdraft,
                    createdAt: existing?.createdAt ?? now,
                    updatedAt: now,
                  ),
                );
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                if (context.mounted) showAppMessage(context, 'Account saved on this device.');
              } catch (error) {
                if (dialogContext.mounted) showAppMessage(dialogContext, error.toString(), isError: true);
              }
            },
            child: Text(existing == null ? 'Create account' : 'Save changes'),
          ),
        ],
      ),
    ),
  );
  name.dispose();
  balance.dispose();
}

Future<void> _archiveAccount(
  BuildContext context,
  FinancialAccount account,
) async {
  final confirmed = await confirmAction(
    context,
    title: 'Archive account?',
    message: 'It will remain visible in historical transactions but cannot be used for new activity.',
    confirmLabel: 'Archive',
  );
  if (!confirmed || !context.mounted) return;
  try {
    await context.read<FinanceController>().archiveAccount(account.id);
    if (context.mounted) showAppMessage(context, 'Account archived.');
  } catch (error) {
    if (context.mounted) showAppMessage(context, error.toString(), isError: true);
  }
}

String _formattedInput(int minor, String currency) {
  final scale = currencyFractionDigits(currency);
  final multiplier = scale == 0 ? 1 : 100;
  final whole = minor ~/ multiplier;
  final fraction = minor % multiplier;
  return scale == 0
      ? '$whole'
      : '$whole.${fraction.toString().padLeft(scale, '0')}';
}
