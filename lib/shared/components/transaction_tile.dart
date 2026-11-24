import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/glass_container.dart';
import '../../data/models/finance_models.dart';
import '../../app/routes/route_names.dart';

class TransactionTile extends StatelessWidget {
  const TransactionTile({
    required this.transaction,
    super.key,
    this.accountName,
    this.onEdit,
  });

  final FinancialTransaction transaction;
  final String? accountName;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final style = CategoryStyle.forName(
      transaction.category,
      income: transaction.type == TransactionType.income ||
          transaction.type == TransactionType.refund,
    );
    final incoming = transaction.type == TransactionType.income ||
        transaction.type == TransactionType.refund;
    final prefix = transaction.type == TransactionType.transfer
        ? ''
        : incoming
        ? '+'
        : '−';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassContainer(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        radius: 17,
        blur: 7,
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: style.color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              transaction.type == TransactionType.transfer
                  ? Icons.swap_horiz_rounded
                  : style.icon,
              color: style.color,
              size: 20,
            ),
          ),
          title: Text(
            transaction.description,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          subtitle: Text(
            [
              transaction.category,
              accountName ?? transaction.paymentMethod,
              MaterialLocalizations.of(context).formatShortDate(transaction.occurredAt),
            ].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$prefix${formatMinorUnits(transaction.amountMinor, transaction.currencyCode)}',
                style: TextStyle(
                  color: incoming
                      ? Theme.of(context).colorScheme.primary
                      : transaction.type == TransactionType.transfer
                      ? Theme.of(context).colorScheme.onSurface
                      : Theme.of(context).colorScheme.error,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (transaction.type == TransactionType.transfer)
                Text('Transfer', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          onTap: () => Navigator.pushNamed(
            context,
            RouteNames.transactionDetails,
            arguments: transaction,
          ),
        ),
      ),
    );
  }
}
