import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:moneywise/core/services/report_export_service.dart';
import 'package:moneywise/data/models/finance_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('builds a printable statement PDF for a transaction period', () async {
    final service = const ReportExportService();
    final bytes = await service.buildReportPdf(
      periodLabel: '01/11/2026 - 30/11/2026',
      periodStart: DateTime(2026, 11),
      currencyCode: 'UGX',
      incomeMinor: 1200000,
      expenseMinor: 450000,
      balanceMinor: 2800000,
      categories: const [
        CategorySpendingItem(
          category: 'Food',
          amountMinor: 250000,
          sharePercent: 56,
        ),
      ],
      transactions: [
        FinancialTransaction(
          id: 'transaction-1',
          userId: 'user-1',
          accountId: 'wallet-1',
          type: TransactionType.expense,
          amountMinor: 250000,
          currencyCode: 'UGX',
          category: 'Food',
          description: 'Café groceries',
          occurredAt: DateTime(2026, 11, 12),
        ),
      ],
      accountNames: const {'wallet-1': 'Cash'},
      generatedAt: DateTime(2026, 11, 30),
    );

    expect(utf8.decode(bytes.take(5).toList()), '%PDF-');
  });
}
