import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneywise/core/services/finance_controller.dart';
import 'package:moneywise/core/theme/app_theme.dart';
import 'package:moneywise/data/models/finance_models.dart';
import 'package:moneywise/features/transactions/transaction_form_screen.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('rejects zero amounts and missing descriptions', (tester) async {
    final finance = _FakeFinanceController([_cashAccount()]);
    await tester.pumpWidget(_app(finance));
    await tester.tap(find.text('Open expense form'));
    await tester.pumpAndSettle();

    await tester.enterText(_field('Amount (UGX)'), '0');
    await tester.enterText(_field('Description'), '');
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
    final finance = _FakeFinanceController([_cashAccount()]);
    await tester.pumpWidget(_app(finance));
    await tester.tap(find.text('Open expense form'));
    await tester.pumpAndSettle();

    await tester.enterText(_field('Amount (UGX)'), '20000');
    await tester.enterText(_field('Description'), 'Groceries');
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
  });

  testWidgets('editing preserves the transaction ID and updates its amount', (
    tester,
  ) async {
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

Widget _app(_FakeFinanceController finance, {FinancialTransaction? existing}) {
  return Provider<FinanceController>.value(
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
  final List<FinancialAccount> accounts;
  FinancialTransaction? savedTransaction;

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
}
