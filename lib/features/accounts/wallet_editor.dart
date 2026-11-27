import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/finance_controller.dart';
import '../../core/utils/money.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/glass_text_field.dart';
import '../../data/models/finance_models.dart';
import '../../data/repositories/finance_repository.dart';

Future<FinancialAccount?> showWalletEditor(BuildContext context) async {
  final finance = context.read<FinanceController>();
  final name = TextEditingController();
  final openingBalance = TextEditingController(text: '0');
  final formKey = GlobalKey<FormState>();
  var type = 'Cash';
  var currency = finance.preferredCurrency;

  final result = await showDialog<FinancialAccount>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Add wallet'),
        content: SizedBox(
          width: 400,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GlassTextField(
                  controller: name,
                  label: 'Wallet name',
                  icon: Icons.account_balance_wallet_outlined,
                  validator: (value) =>
                      Validators.required(value, 'Wallet name'),
                ),
                const SizedBox(height: 11),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'Wallet type'),
                  items: AppConstants.accountTypes
                      .map(
                        (item) =>
                            DropdownMenuItem(value: item, child: Text(item)),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => type = value ?? type),
                ),
                const SizedBox(height: 11),
                DropdownButtonFormField<String>(
                  initialValue: currency,
                  decoration: const InputDecoration(labelText: 'Currency'),
                  items: AppConstants.supportedCurrencies.keys
                      .map(
                        (code) => DropdownMenuItem(
                          value: code,
                          child: Text(
                            '$code · ${AppConstants.supportedCurrencies[code]}',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => currency = value ?? currency),
                ),
                const SizedBox(height: 11),
                GlassTextField(
                  controller: openingBalance,
                  label: 'Opening balance',
                  icon: Icons.payments_outlined,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (value) {
                    try {
                      parseMinorUnits(value ?? '', currency, allowZero: true);
                      return null;
                    } on FormatException catch (error) {
                      return error.message;
                    }
                  },
                ),
              ],
            ),
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
              final now = DateTime.now();
              final account = FinancialAccount(
                id: FinanceRepository.createId(),
                userId: finance.userId!,
                name: name.text.trim(),
                type: type,
                currencyCode: currency,
                openingBalanceMinor: parseMinorUnits(
                  openingBalance.text,
                  currency,
                  allowZero: true,
                ),
                createdAt: now,
                updatedAt: now,
              );
              try {
                await finance.saveAccount(account);
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext, account);
                }
              } catch (error) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext)
                      .showSnackBar(SnackBar(content: Text(error.toString())));
                }
              }
            },
            child: const Text('Create wallet'),
          ),
        ],
      ),
    ),
  );
  name.dispose();
  openingBalance.dispose();
  return result;
}
