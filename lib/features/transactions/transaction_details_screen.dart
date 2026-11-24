import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../app/routes/route_names.dart';
import '../../core/services/finance_controller.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/screen_header.dart';
import '../../data/models/finance_models.dart';

class TransactionDetailsScreen extends StatelessWidget {
  const TransactionDetailsScreen({required this.transaction, super.key});

  final FinancialTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceController>();
    final account = finance.accounts
        .where((item) => item.id == transaction.accountId)
        .firstOrNull;
    final destination = finance.accounts
        .where((item) => item.id == transaction.destinationAccountId)
        .firstOrNull;
    final isIncoming =
        transaction.type == TransactionType.income ||
        transaction.type == TransactionType.refund;
    return GlassScaffold(
      padding: const EdgeInsets.symmetric(horizontal: 17),
      child: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        children: [
          ScreenHeader(
            title: 'Transaction details',
            showBack: true,
            trailing: PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'edit') {
                  Navigator.pushNamed(
                    context,
                    RouteNames.transactionAdd,
                    arguments: TransactionFormArguments(existing: transaction),
                  );
                } else if (value == 'delete') {
                  final confirmed = await confirmAction(
                    context,
                    title: 'Delete this transaction?',
                    message: 'The transaction will be reversed from account balances and kept as an audit record.',
                    confirmLabel: 'Delete',
                    destructive: true,
                  );
                  if (!confirmed || !context.mounted) return;
                  try {
                    await context.read<FinanceController>().deleteTransaction(
                      transaction.id,
                    );
                    if (context.mounted) {
                      showAppMessage(context, 'Transaction deleted.');
                      Navigator.pop(context);
                    }
                  } catch (error) {
                    if (context.mounted) {
                      showAppMessage(context, error.toString(), isError: true);
                    }
                  }
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ),
          GlassContainer(
            padding: const EdgeInsets.all(22),
            radius: 24,
            gradient: LinearGradient(
              colors: isIncoming
                  ? const [Color(0xD60A9C7D), Color(0xE6065B59)]
                  : const [Color(0xD6548290), Color(0xE62B4B5F)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            child: Column(
              children: [
                Icon(
                  transaction.type == TransactionType.transfer
                      ? Icons.swap_horiz_rounded
                      : isIncoming
                      ? Icons.south_west_rounded
                      : Icons.north_east_rounded,
                  color: Colors.white,
                  size: 29,
                ),
                const SizedBox(height: 8),
                Text(
                  '${isIncoming
                      ? '+'
                      : transaction.type == TransactionType.transfer
                      ? ''
                      : '−'}${formatMinorUnits(transaction.amountMinor, transaction.currencyCode)}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  transaction.description,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  transaction.category,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),
          GlassContainer(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
            radius: 20,
            child: Column(
              children: [
                _DetailRow(
                  label: 'Date',
                  value: MaterialLocalizations.of(context)
                      .formatFullDate(transaction.occurredAt),
                ),
                _DetailRow(
                  label: 'Account',
                  value: account?.name ?? 'Account unavailable',
                ),
                if (destination != null)
                  _DetailRow(label: 'To account', value: destination.name),
                if (transaction.destinationAmountMinor != null &&
                    transaction.destinationCurrencyCode != null)
                  _DetailRow(
                    label: 'Received',
                    value: formatMinorUnits(
                      transaction.destinationAmountMinor!,
                      transaction.destinationCurrencyCode!,
                    ),
                  ),
                _DetailRow(
                  label: 'Payment method',
                  value: transaction.paymentMethod,
                ),
                _DetailRow(label: 'Type', value: transaction.type.name),
                if (transaction.exchangeRate != null)
                  _DetailRow(
                    label: 'Exchange rate',
                    value: transaction.exchangeRate!,
                  ),
                _DetailRow(label: 'Status', value: transaction.syncStatus.name),
              ],
            ),
          ),
          if (transaction.notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            GlassContainer(
              padding: const EdgeInsets.all(16),
              radius: 18,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Notes', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 5),
                  Text(transaction.notes),
                ],
              ),
            ),
          ],
          if (transaction.receiptPath != null) ...[
              const SizedBox(height: 12),
              FutureBuilder<List<ReceiptAttachment>>(
                future: finance.loadTransactionReceipts(transaction.id),
                builder: (context, snapshot) {
                  final receiptPaths = snapshot.data?.isNotEmpty == true
                      ? snapshot.data!.map((receipt) => receipt.localPath).toList()
                      : [transaction.receiptPath!];
                  return SizedBox(
                    height: 220,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: receiptPaths.length,
                      itemBuilder: (context, index) => Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.file(
                            File(receiptPaths[index]),
                            errorBuilder: (context, error, stackTrace) =>
                                const SizedBox(
                                  width: 220,
                                  child: Center(
                                    child: Icon(Icons.broken_image_outlined),
                                  ),
                                ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ],
      ),
    );
  }
}
