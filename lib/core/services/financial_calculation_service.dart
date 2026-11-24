import '../../data/models/finance_models.dart';

class FinancialSummary {
  const FinancialSummary({
    required this.incomeByCurrency,
    required this.expensesByCurrency,
    required this.balanceByCurrency,
  });

  final Map<String, int> incomeByCurrency;
  final Map<String, int> expensesByCurrency;
  final Map<String, int> balanceByCurrency;

  Map<String, int> get netCashFlowByCurrency {
    final currencies = {...incomeByCurrency.keys, ...expensesByCurrency.keys};
    return {
      for (final currency in currencies)
        currency:
            (incomeByCurrency[currency] ?? 0) -
            (expensesByCurrency[currency] ?? 0),
    };
  }
}

class BudgetProgress {
  const BudgetProgress({
    required this.spentMinor,
    required this.remainingMinor,
    required this.usagePercent,
  });

  final int spentMinor;
  final int remainingMinor;
  final int usagePercent;
}

class CategorySpending {
  const CategorySpending({
    required this.category,
    required this.currencyCode,
    required this.amountMinor,
  });

  final String category;
  final String currencyCode;
  final int amountMinor;
}

class FinancialCalculationService {
  const FinancialCalculationService();

  FinancialSummary summarize({
    required List<FinancialAccount> accounts,
    required List<FinancialTransaction> transactions,
    DateTime? from,
    DateTime? through,
  }) {
    final income = <String, int>{};
    final expenses = <String, int>{};
    final balances = <String, int>{};
    final eligibleTransactions = transactions.where(
      (transaction) =>
          transaction.status == 'active' &&
          _within(transaction.occurredAt, from, through),
    );

    for (final transaction in eligibleTransactions) {
      switch (transaction.type) {
        case TransactionType.income:
          _add(income, transaction.currencyCode, transaction.amountMinor);
          break;
        case TransactionType.expense:
          _add(expenses, transaction.currencyCode, transaction.amountMinor);
          break;
        case TransactionType.refund:
          _add(expenses, transaction.currencyCode, -transaction.amountMinor);
          break;
        case TransactionType.transfer || TransactionType.adjustment:
          break;
      }
    }

    for (final account in accounts.where((account) => !account.isArchived)) {
      balances[account.currencyCode] =
          (balances[account.currencyCode] ?? 0) +
          accountBalance(account, transactions);
    }

    return FinancialSummary(
      incomeByCurrency: income,
      expensesByCurrency: expenses,
      balanceByCurrency: balances,
    );
  }

  int accountBalance(
    FinancialAccount account,
    List<FinancialTransaction> transactions,
  ) {
    var balance = account.openingBalanceMinor;
    for (final transaction in transactions) {
      if (transaction.status != 'active') continue;
      if (transaction.accountId == account.id) {
        switch (transaction.type) {
          case TransactionType.income:
          case TransactionType.refund:
          case TransactionType.adjustment:
            balance += transaction.amountMinor;
            break;
          case TransactionType.expense:
            balance -= transaction.amountMinor;
            break;
          case TransactionType.transfer:
            balance -= transaction.amountMinor;
            break;
        }
      }
      if (transaction.type == TransactionType.transfer &&
          transaction.destinationAccountId == account.id) {
        balance +=
            transaction.destinationAmountMinor ?? transaction.amountMinor;
      }
    }
    return balance;
  }

  BudgetProgress budgetProgress({
    required FinancialBudget budget,
    required List<FinancialTransaction> transactions,
  }) {
    var spent = 0;
    for (final transaction in transactions) {
      if (transaction.status != 'active' ||
          transaction.currencyCode != budget.currencyCode ||
          transaction.occurredAt.isBefore(budget.startDate) ||
          transaction.occurredAt.isAfter(budget.endDate)) {
        continue;
      }
      if (budget.categoryIds.isNotEmpty &&
          !budget.categoryIds.contains(transaction.category)) {
        continue;
      }
      if (transaction.type == TransactionType.expense) {
        spent += transaction.amountMinor;
      } else if (transaction.type == TransactionType.refund) {
        spent -= transaction.amountMinor;
      }
    }
    if (spent < 0) spent = 0;
    final usage = budget.limitMinor <= 0
        ? 0
        : (spent * 100 ~/ budget.limitMinor);
    return BudgetProgress(
      spentMinor: spent,
      remainingMinor: budget.limitMinor - spent,
      usagePercent: usage,
    );
  }

  int savingsTotal(String goalId, List<SavingsContribution> contributions) {
    var total = 0;
    for (final contribution in contributions.where(
      (item) => item.goalId == goalId,
    )) {
      if (contribution.type == 'withdrawal') {
        total -= contribution.amountMinor;
      } else {
        total += contribution.amountMinor;
      }
    }
    return total;
  }

  int outstandingDebt(
    DebtRecord debt,
    List<DebtPayment> payments,
  ) {
    if (debt.status == 'settled') return 0;
    final paid = payments
        .where((payment) => payment.debtId == debt.id)
        .fold<int>(0, (total, payment) => total + payment.amountMinor);
    final remaining = debt.principalMinor - paid;
    return remaining < 0 ? 0 : remaining;
  }

  List<CategorySpending> categorySpending(
    List<FinancialTransaction> transactions, {
    required String currencyCode,
    DateTime? from,
    DateTime? through,
  }) {
    final totals = <String, int>{};
    for (final transaction in transactions) {
      if (transaction.status != 'active' ||
          transaction.currencyCode != currencyCode ||
          !_within(transaction.occurredAt, from, through)) {
        continue;
      }
      if (transaction.type == TransactionType.expense) {
        _add(totals, transaction.category, transaction.amountMinor);
      } else if (transaction.type == TransactionType.refund) {
        _add(totals, transaction.category, -transaction.amountMinor);
      }
    }
    return [
      for (final entry in totals.entries.where((entry) => entry.value > 0))
        CategorySpending(
          category: entry.key,
          currencyCode: currencyCode,
          amountMinor: entry.value,
        ),
    ]..sort((a, b) => b.amountMinor.compareTo(a.amountMinor));
  }

  static bool _within(DateTime date, DateTime? from, DateTime? through) {
    if (from != null && date.isBefore(from)) return false;
    if (through != null && date.isAfter(through)) return false;
    return true;
  }

  static void _add(Map<String, int> target, String currency, int amount) {
    target[currency] = (target[currency] ?? 0) + amount;
  }
}
