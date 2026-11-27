import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/routes/route_names.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_icons.dart';
import '../../core/services/finance_controller.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/glass_container.dart';
import '../../data/models/finance_models.dart';

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
    final categoryIconKey = context.select<FinanceController, String?>(
      (finance) => finance.categories
          .where((category) => category['id'] == transaction.categoryId)
          .map((category) => category['icon'] as String?)
          .firstOrNull,
    );
    final style = CategoryStyle.forName(
      transaction.category,
      income:
          transaction.type == TransactionType.income ||
          transaction.type == TransactionType.refund,
    );
    final incoming =
        transaction.type == TransactionType.income ||
        transaction.type == TransactionType.refund;
    final isTransfer = transaction.type == TransactionType.transfer;
    final prefix = isTransfer
        ? ''
        : incoming
        ? '+'
        : '−';

    final IconData tileIcon = isTransfer
        ? AppIcons.transfer
        : categoryIconKey == null
        ? style.icon
        : AppIcons.forCategoryKey(categoryIconKey);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassContainer(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        radius: 16,
        blur: 6,
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: style.color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(tileIcon, color: style.color, size: 19),
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
              MaterialLocalizations.of(context)
                  .formatShortDate(transaction.occurredAt),
            ].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
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
                      : isTransfer
                      ? Theme.of(context).colorScheme.onSurface
                      : Theme.of(context).colorScheme.error,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Inter',
                ),
              ),
              if (isTransfer)
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
