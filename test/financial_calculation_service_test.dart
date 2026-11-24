import 'package:flutter_test/flutter_test.dart';
import 'package:moneywise/core/services/financial_calculation_service.dart';
import 'package:moneywise/data/models/finance_models.dart';

void main() {
  const calculations = FinancialCalculationService();

  group('balances and summaries', () {
    test('keeps currencies separate and excludes transfers from cash flow', () {
      final cash = _account(
        id: 'cash',
        currency: 'UGX',
        openingBalance: 100000,
      );
      final dollars = _account(
        id: 'dollars',
        currency: 'USD',
        openingBalance: 1000,
      );
      final transactions = [
        _transaction(
          id: 'income-ugx',
          type: TransactionType.income,
          amount: 200000,
        ),
        _transaction(
          id: 'expense-ugx',
          type: TransactionType.expense,
          amount: 75000,
        ),
        _transaction(
          id: 'refund-ugx',
          type: TransactionType.refund,
          amount: 5000,
        ),
        _transaction(
          id: 'transfer',
          type: TransactionType.transfer,
          amount: 10000,
          destinationAccountId: 'dollars',
          destinationAmount: 3000,
        ),
        _transaction(
          id: 'income-usd',
          type: TransactionType.income,
          amount: 5000,
          currency: 'USD',
          accountId: 'dollars',
        ),
        _transaction(
          id: 'voided-expense',
          type: TransactionType.expense,
          amount: 90000,
          status: 'voided',
        ),
      ];

      final summary = calculations.summarize(
        accounts: [cash, dollars],
        transactions: transactions,
      );

      expect(summary.incomeByCurrency, {'UGX': 200000, 'USD': 5000});
      expect(summary.expensesByCurrency, {'UGX': 70000});
      expect(summary.netCashFlowByCurrency, {'UGX': 130000, 'USD': 5000});
      expect(summary.balanceByCurrency, {'UGX': 220000, 'USD': 9000});
      expect(calculations.accountBalance(cash, transactions), 220000);
      expect(calculations.accountBalance(dollars, transactions), 9000);
    });

    test('filters period totals without rewriting lifetime balances', () {
      final account = _account(
        id: 'cash',
        currency: 'UGX',
        openingBalance: 1000,
      );
      final transactions = [
        _transaction(
          id: 'january-income',
          type: TransactionType.income,
          amount: 3000,
          occurredAt: DateTime(2025, 1, 15),
        ),
        _transaction(
          id: 'february-expense',
          type: TransactionType.expense,
          amount: 500,
          occurredAt: DateTime(2025, 2, 15),
        ),
      ];

      final summary = calculations.summarize(
        accounts: [account],
        transactions: transactions,
        from: DateTime(2025, 1),
        through: DateTime(2025, 1, 31, 23, 59, 59),
      );

      expect(summary.incomeByCurrency, {'UGX': 3000});
      expect(summary.expensesByCurrency, isEmpty);
      expect(summary.balanceByCurrency, {'UGX': 3500});
    });
  });

  group('budgets', () {
    final budget = FinancialBudget(
      id: 'food-budget',
      userId: 'user-1',
      name: 'Food',
      limitMinor: 100000,
      currencyCode: 'UGX',
      startDate: DateTime(2025, 1),
      endDate: DateTime(2025, 1, 31, 23, 59, 59),
      categoryIds: const ['Food'],
    );

    test('counts only active matching category, currency and period', () {
      final progress = calculations.budgetProgress(
        budget: budget,
        transactions: [
          _transaction(
            id: 'food',
            type: TransactionType.expense,
            amount: 65000,
            category: 'Food',
            occurredAt: DateTime(2025, 1, 15),
          ),
          _transaction(
            id: 'food-refund',
            type: TransactionType.refund,
            amount: 5000,
            category: 'Food',
            occurredAt: DateTime(2025, 1, 16),
          ),
          _transaction(
            id: 'transport',
            type: TransactionType.expense,
            amount: 20000,
            category: 'Transport',
            occurredAt: DateTime(2025, 1, 17),
          ),
          _transaction(
            id: 'other-currency',
            type: TransactionType.expense,
            amount: 500,
            currency: 'USD',
            category: 'Food',
            occurredAt: DateTime(2025, 1, 18),
          ),
          _transaction(
            id: 'next-month',
            type: TransactionType.expense,
            amount: 10000,
            category: 'Food',
            occurredAt: DateTime(2025, 2, 1),
          ),
          _transaction(
            id: 'voided',
            type: TransactionType.expense,
            amount: 2000,
            category: 'Food',
            status: 'voided',
            occurredAt: DateTime(2025, 1, 19),
          ),
        ],
      );

      expect(progress.spentMinor, 60000);
      expect(progress.remainingMinor, 40000);
      expect(progress.usagePercent, 60);
    });

    test('reports overspending rather than hiding a negative remainder', () {
      final progress = calculations.budgetProgress(
        budget: budget,
        transactions: [
          _transaction(
            id: 'over-budget',
            type: TransactionType.expense,
            amount: 120000,
            category: 'Food',
            occurredAt: DateTime(2025, 1, 15),
          ),
        ],
      );

      expect(progress.spentMinor, 120000);
      expect(progress.remainingMinor, -20000);
      expect(progress.usagePercent, 120);
    });
  });

  test('savings withdrawals reduce only their own goal total', () {
    final contributions = [
      SavingsContribution(
        id: 'one',
        userId: 'user-1',
        goalId: 'trip',
        amountMinor: 100000,
        currencyCode: 'UGX',
        type: 'contribution',
        occurredAt: DateTime(2025, 1),
      ),
      SavingsContribution(
        id: 'two',
        userId: 'user-1',
        goalId: 'trip',
        amountMinor: 50000,
        currencyCode: 'UGX',
        type: 'contribution',
        occurredAt: DateTime(2025, 1, 2),
      ),
      SavingsContribution(
        id: 'withdrawal',
        userId: 'user-1',
        goalId: 'trip',
        amountMinor: 25000,
        currencyCode: 'UGX',
        type: 'withdrawal',
        occurredAt: DateTime(2025, 1, 3),
      ),
      SavingsContribution(
        id: 'other-goal',
        userId: 'user-1',
        goalId: 'car',
        amountMinor: 900000,
        currencyCode: 'UGX',
        type: 'contribution',
        occurredAt: DateTime(2025, 1, 4),
      ),
    ];

    expect(calculations.savingsTotal('trip', contributions), 125000);
  });

  test('debt repayments reduce the correct debt and cannot go below zero', () {
    const debt = DebtRecord(
      id: 'loan',
      userId: 'user-1',
      personName: 'Lender',
      type: 'borrowed',
      principalMinor: 200000,
      currencyCode: 'UGX',
    );
    final payments = [
      DebtPayment(
        id: 'payment-1',
        userId: 'user-1',
        debtId: 'loan',
        amountMinor: 50000,
        paymentType: 'repayment',
        paymentDate: DateTime(2025, 1),
      ),
      DebtPayment(
        id: 'payment-2',
        userId: 'user-1',
        debtId: 'loan',
        amountMinor: 160000,
        paymentType: 'repayment',
        paymentDate: DateTime(2025, 2),
      ),
      DebtPayment(
        id: 'other-debt-payment',
        userId: 'user-1',
        debtId: 'other-loan',
        amountMinor: 100000,
        paymentType: 'repayment',
        paymentDate: DateTime(2025, 2),
      ),
    ];

    expect(calculations.outstandingDebt(debt, payments), 0);
    const settledDebt = DebtRecord(
      id: 'loan',
      userId: 'user-1',
      personName: 'Lender',
      type: 'borrowed',
      principalMinor: 200000,
      currencyCode: 'UGX',
      status: 'settled',
    );
    expect(calculations.outstandingDebt(settledDebt, const []), 0);
  });

  test('ranks category spending after refunds and filters by currency', () {
    final categories = calculations.categorySpending([
      _transaction(
        id: 'food',
        type: TransactionType.expense,
        amount: 60000,
        category: 'Food',
      ),
      _transaction(
        id: 'food-refund',
        type: TransactionType.refund,
        amount: 10000,
        category: 'Food',
      ),
      _transaction(
        id: 'transport',
        type: TransactionType.expense,
        amount: 40000,
        category: 'Transport',
      ),
      _transaction(
        id: 'usd-food',
        type: TransactionType.expense,
        amount: 500,
        currency: 'USD',
        category: 'Food',
      ),
    ], currencyCode: 'UGX');

    expect(
      categories.map((item) => (item.category, item.amountMinor)).toList(),
      [('Food', 50000), ('Transport', 40000)],
    );
  });
}

FinancialAccount _account({
  required String id,
  required String currency,
  required int openingBalance,
}) => FinancialAccount(
  id: id,
  userId: 'user-1',
  name: id,
  type: 'Cash',
  currencyCode: currency,
  openingBalanceMinor: openingBalance,
);

FinancialTransaction _transaction({
  required String id,
  required TransactionType type,
  required int amount,
  String currency = 'UGX',
  String accountId = 'cash',
  String category = 'Food',
  DateTime? occurredAt,
  String? destinationAccountId,
  int? destinationAmount,
  String status = 'active',
}) => FinancialTransaction(
  id: id,
  userId: 'user-1',
  accountId: accountId,
  type: type,
  amountMinor: amount,
  currencyCode: currency,
  category: category,
  description: id,
  occurredAt: occurredAt ?? DateTime(2025, 1, 15),
  destinationAccountId: destinationAccountId,
  destinationAmountMinor: destinationAmount,
  status: status,
);
