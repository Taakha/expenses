import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../data/models/finance_models.dart';
import '../utils/money.dart';

class ReportExportService {
  const ReportExportService();

  Future<String> saveTransactionsCsv(
    Stream<FinancialTransaction> transactions,
    Map<String, String> accountNames,
  ) async {
    final directory = await _exportDirectory();
    final filename =
        'moneywise_transactions_${DateTime.now().millisecondsSinceEpoch}.csv';
    final file = File(path.join(directory.path, filename));
    final sink = file.openWrite();
    final encoder = CsvEncoder(addBom: false);
    try {
      sink.write('\uFEFF');
      sink.write(
        encoder.convert([
          [
            'Date',
            'Type',
            'Description',
            'Category',
            'Account',
            'Currency',
            'Amount in minor units',
            'Display amount',
            'Payment method',
            'Notes',
          ],
        ]),
      );
      await for (final entry in transactions) {
        sink.write(
          encoder.convert([
            [
              entry.occurredAt.toIso8601String(),
              entry.type.name,
              entry.description,
              entry.category,
              accountNames[entry.accountId] ?? entry.accountId,
              entry.currencyCode,
              entry.amountMinor,
              formatMinorUnits(entry.amountMinor, entry.currencyCode),
              entry.paymentMethod,
              entry.notes,
            ],
          ]),
        );
      }
      await sink.flush();
      await sink.close();
      return file.path;
    } on Object {
      await sink.close();
      if (await file.exists()) await file.delete();
      rethrow;
    }
  }

  Future<void> shareReportPdf({
    required String periodLabel,
    required DateTime periodStart,
    required String currencyCode,
    required int incomeMinor,
    required int expenseMinor,
    required int balanceMinor,
    required List<CategorySpendingItem> categories,
    required List<FinancialTransaction> transactions,
    required Map<String, String> accountNames,
    String? accountLabel,
  }) async {
    final bytes = await buildReportPdf(
      periodLabel: periodLabel,
      periodStart: periodStart,
      currencyCode: currencyCode,
      incomeMinor: incomeMinor,
      expenseMinor: expenseMinor,
      balanceMinor: balanceMinor,
      categories: categories,
      transactions: transactions,
      accountNames: accountNames,
      accountLabel: accountLabel,
    );
    final month = periodStart.month.toString().padLeft(2, '0');
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'moneywise_statement_${periodStart.year}-$month.pdf',
    );
  }

  Future<Uint8List> buildReportPdf({
    required String periodLabel,
    required DateTime periodStart,
    required String currencyCode,
    required int incomeMinor,
    required int expenseMinor,
    required int balanceMinor,
    required List<CategorySpendingItem> categories,
    required List<FinancialTransaction> transactions,
    required Map<String, String> accountNames,
    String? accountLabel,
    DateTime? generatedAt,
  }) async {
    final createdAt = generatedAt ?? DateTime.now();
    final orderedTransactions = [...transactions]
      ..sort((left, right) => right.occurredAt.compareTo(left.occurredAt));
    final netSaved = incomeMinor - expenseMinor;
    final reportFont = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Inter-Variable.ttf'),
    );
    final reportTheme = pw.ThemeData.withFont(
      base: reportFont,
      bold: reportFont,
      italic: reportFont,
      boldItalic: reportFont,
    );
    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        theme: reportTheme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 54, 36, 48),
        header: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'MONEY WISE',
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.teal800,
              ),
            ),
            pw.Text(
              'FINANCIAL STATEMENT',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
            ),
          ],
        ),
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Generated ${_dateLabel(createdAt)} | From data on this device',
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
            ),
            pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
            ),
          ],
        ),
        build: (context) => [
          pw.Text(
            'Financial statement',
            style: pw.TextStyle(fontSize: 21, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            '$periodLabel | $currencyCode',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
          if (accountLabel != null) ...[
            pw.SizedBox(height: 3),
            pw.Text(
              'Wallet: $accountLabel',
              style: const pw.TextStyle(fontSize: 9),
            ),
          ],
          pw.SizedBox(height: 14),
          pw.Table(
            columnWidths: const {
              0: pw.FlexColumnWidth(1),
              1: pw.FlexColumnWidth(1),
            },
            children: [
              pw.TableRow(
                children: [
                  _summaryBox(
                    'Income',
                    '+${formatMinorUnits(incomeMinor, currencyCode)}',
                    PdfColors.green800,
                  ),
                  _summaryBox(
                    'Expenses',
                    '-${formatMinorUnits(expenseMinor, currencyCode)}',
                    PdfColors.red800,
                  ),
                ],
              ),
              pw.TableRow(
                children: [
                  _summaryBox(
                    'Net saved',
                    '${netSaved < 0 ? '-' : '+'}${formatMinorUnits(netSaved.abs(), currencyCode)}',
                    netSaved < 0 ? PdfColors.red800 : PdfColors.teal800,
                  ),
                  _summaryBox(
                    'Closing balance',
                    '${balanceMinor < 0 ? '-' : '+'}${formatMinorUnits(balanceMinor.abs(), currencyCode)}',
                    PdfColors.grey900,
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            'Spending by category',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 7),
          if (categories.isEmpty)
            pw.Text(
              'No expenses were recorded in this period.',
              style: const pw.TextStyle(fontSize: 9),
            )
          else
            pw.Column(
              children: [
                for (final item in categories) _categoryRow(item, currencyCode),
              ],
            ),
          pw.SizedBox(height: 16),
          pw.Text(
            'Transactions',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 7),
          if (orderedTransactions.isEmpty)
            pw.Text(
              'No transactions were recorded in this period.',
              style: const pw.TextStyle(fontSize: 9),
            )
          else
            pw.TableHelper.fromTextArray(
              headers: const ['Date', 'Description', 'Wallet', 'Amount'],
              data: [
                for (final entry in orderedTransactions)
                  [
                    _dateLabel(entry.occurredAt),
                    entry.description,
                    accountNames[entry.accountId] ?? 'Wallet',
                    _signedAmount(entry),
                  ],
                [
                  'TOTAL',
                  '',
                  'Net saved',
                  '${netSaved < 0 ? '-' : '+'}${formatMinorUnits(netSaved.abs(), currencyCode)}',
                ],
              ],
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey200,
              ),
              cellStyle: const pw.TextStyle(fontSize: 8),
              cellPadding: const pw.EdgeInsets.symmetric(
                horizontal: 5,
                vertical: 5,
              ),
              columnWidths: const {
                0: pw.FixedColumnWidth(52),
                1: pw.FlexColumnWidth(3),
                2: pw.FlexColumnWidth(1.35),
                3: pw.FixedColumnWidth(88),
              },
              cellAlignments: const {3: pw.Alignment.centerRight},
              headerCount: 1,
              oddRowDecoration: const pw.BoxDecoration(
                color: PdfColors.grey100,
              ),
              rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
            ),
          pw.SizedBox(height: 12),
          pw.Text(
            'Income is marked + and expenses -. Transfers are excluded from income and expense totals.',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
        ],
      ),
    );
    return document.save();
  }

  Future<Directory> _exportDirectory() async {
    final base = await getApplicationDocumentsDirectory();
    final directory = Directory(path.join(base.path, 'moneywise', 'exports'));
    if (!await directory.exists()) await directory.create(recursive: true);
    return directory;
  }

  static pw.Widget _summaryBox(String label, String value, PdfColor color) =>
      pw.Container(
        margin: const pw.EdgeInsets.all(3),
        padding: const pw.EdgeInsets.all(10),
        decoration: const pw.BoxDecoration(color: PdfColors.grey100),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              label.toUpperCase(),
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      );

  static pw.Widget _categoryRow(
    CategorySpendingItem item,
    String currencyCode,
  ) {
    final percentage = (item.sharePercent.clamp(0, 100)) / 100;
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 90,
            child: pw.Text(
              item.category,
              style: const pw.TextStyle(fontSize: 8),
            ),
          ),
          pw.SizedBox(
            width: 150,
            child: pw.Row(
              children: [
                pw.Container(
                  width: 150 * percentage,
                  height: 7,
                  color: PdfColors.teal700,
                ),
                pw.Expanded(
                  child: pw.Container(height: 7, color: PdfColors.grey200),
                ),
              ],
            ),
          ),
          pw.SizedBox(
            width: 92,
            child: pw.Text(
              formatMinorUnits(item.amountMinor, currencyCode),
              textAlign: pw.TextAlign.right,
              style: const pw.TextStyle(fontSize: 8),
            ),
          ),
          pw.SizedBox(
            width: 34,
            child: pw.Text(
              '${item.sharePercent}%',
              textAlign: pw.TextAlign.right,
              style: const pw.TextStyle(fontSize: 8),
            ),
          ),
        ],
      ),
    );
  }

  static String _signedAmount(FinancialTransaction transaction) {
    final amount = formatMinorUnits(
      transaction.amountMinor.abs(),
      transaction.currencyCode,
    );
    return switch (transaction.type) {
      TransactionType.income || TransactionType.refund => '+$amount',
      TransactionType.expense => '-$amount',
      TransactionType.adjustment =>
        '${transaction.amountMinor < 0 ? '-' : '+'}$amount',
      TransactionType.transfer => amount,
    };
  }

  static String _dateLabel(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

@immutable
class CategorySpendingItem {
  const CategorySpendingItem({
    required this.category,
    required this.amountMinor,
    required this.sharePercent,
  });

  final String category;
  final int amountMinor;
  final int sharePercent;
}
