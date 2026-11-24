import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneywise/core/services/finance_controller.dart';
import 'package:moneywise/core/services/financial_calculation_service.dart';
import 'package:moneywise/core/theme/app_theme.dart';
import 'package:moneywise/data/models/finance_models.dart';
import 'package:moneywise/data/repositories/finance_repository.dart';
import 'package:moneywise/features/transactions/transaction_form_screen.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('rejects zero amounts and missing descriptions', (tester) async {
    _configureTestViewport(tester);
    final finance = _FakeFinanceController([_cashAccount()]);
    await tester.pumpWidget(_app(finance));
    await tester.tap(find.text('Open expense form'));
    await tester.pumpAndSettle();

    await tester.enterText(_field('Amount (UGX)'), '0');
    await tester.enterText(_field('Description'), '');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await tester.ensureVisible(find.text('Save expense'));
    await tester.tap(find.text('Save expense'));
    await tester.pumpAndSettle();

    expect(find.text('Amount must be greater than zero.'), findsOneWidget);
    expect(find.text('Description is required.'), findsOneWidget);
    expect(finance.savedTransaction, isNull);
  });

  testWidgets('saves an expense using exact minor units and its account', (
    tester,
  ) async {
    _configureTestViewport(tester);
    final finance = _FakeFinanceController([_cashAccount()]);
    await tester.pumpWidget(_app(finance));
    await tester.tap(find.text('Open expense form'));
    await tester.pumpAndSettle();

    await tester.enterText(_field('Amount (UGX)'), '20000');
    await tester.enterText(_field('Description'), 'Groceries');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await tester.ensureVisible(find.text('Save expense'));
    await tester.tap(find.text('Save expense'));
    await tester.pumpAndSettle();

    final saved = finance.savedTransaction;
    expect(saved, isNotNull);
    expect(saved!.type, TransactionType.expense);
    expect(saved.amountMinor, 20000);
    expect(saved.currencyCode, 'UGX');
    expect(saved.accountId, 'cash');
    expect(saved.category, 'Food');
    expect(saved.description, 'Groceries');
    expect(find.text('No matching budget'), findsOneWidget);
  });

  testWidgets('editing preserves the transaction ID and updates its amount', (
    tester,
  ) async {
    _configureTestViewport(tester);
    final existing = FinancialTransaction(
      id: 'existing-expense',
      userId: 'user-1',
      accountId: 'cash',
      type: TransactionType.expense,
      amountMinor: 1000,
      currencyCode: 'UGX',
      category: 'Food',
      description: 'Lunch',
      occurredAt: DateTime(2025, 1, 15),
    );
    final finance = _FakeFinanceController([_cashAccount()]);
    await tester.pumpWidget(_app(finance, existing: existing));
    await tester.tap(find.text('Open expense form'));
    await tester.pumpAndSettle();

    await tester.enterText(_field('Amount (UGX)'), '2500');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    final saved = finance.savedTransaction;
    expect(saved, isNotNull);
    expect(saved!.id, 'existing-expense');
    expect(saved.amountMinor, 2500);
    expect(saved.description, 'Lunch');
  });
}

void _configureTestViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _app(_FakeFinanceController finance, {FinancialTransaction? existing}) {
  return ChangeNotifierProvider<FinanceController>.value(
    value: finance,
    child: MaterialApp(
      theme: AppTheme.light(),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => TransactionFormScreen(existing: existing),
                ),
              ),
              child: const Text('Open expense form'),
            ),
          ),
        ),
      ),
    ),
  );
}

Finder _field(String label) {
  final decoration = find.byWidgetPredicate(
    (widget) =>
        widget is InputDecorator && widget.decoration.labelText == label,
  );
  return find
      .ancestor(of: decoration, matching: find.byType(TextFormField))
      .first;
}

FinancialAccount _cashAccount() => const FinancialAccount(
  id: 'cash',
  userId: 'user-1',
  name: 'Cash',
  type: 'Cash',
  currencyCode: 'UGX',
  openingBalanceMinor: 0,
);

class _FakeFinanceController extends Fake implements FinanceController {
  _FakeFinanceController(this.accounts);

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}

  @override
  final List<FinancialAccount> accounts;
  FinancialTransaction? savedTransaction;

  @override
  FinanceSnapshot? get snapshot => FinanceSnapshot(
    accounts: accounts,
    budgets: const [],
    goals: const [],
    contributions: const [],
    debts: const [],
    debtPayments: const [],
    recurringRules: const [],
    notifications: const [],
    categories: const [],
    recentTransactions: const [],
    summary: const FinancialSummary(
      incomeByCurrency: {},
      expensesByCurrency: {},
      balanceByCurrency: {},
    ),
    currentMonthSummary: const FinancialSummary(
      incomeByCurrency: {},
      expensesByCurrency: {},
      balanceByCurrency: {},
    ),
    monthlySummaries: const {},
    accountBalances: const {},
    budgetProgress: const {},
  );

  @override
  List<FinancialAccount> get activeAccounts => accounts;

  @override
  List<Map<String, Object?>> get categories => const [];

  @override
  String preferredCurrency = 'UGX';

  @override
  String? userId = 'user-1';

  @override
  Future<void> saveTransaction(
    FinancialTransaction transaction, {
    List<ReceiptAttachment> receipts = const [],
  }) async {
    savedTransaction = transaction;
  }

  @override
  Future<List<ReceiptAttachment>> loadTransactionReceipts(
    String transactionId,
  ) async => const [];
}
