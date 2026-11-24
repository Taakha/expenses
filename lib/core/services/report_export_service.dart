import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
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
    List<FinancialTransaction> transactions,
    Map<String, String> accountNames,
  ) async {
    final rows = <List<dynamic>>[
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
      for (final entry in transactions)
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
    ];
    final csv = CsvEncoder(addBom: true).convert(rows);
    final directory = await _exportDirectory();
    final filename =
        'moneywise_transactions_${DateTime.now().millisecondsSinceEpoch}.csv';
    final file = File(path.join(directory.path, filename));
    await file.writeAsString(csv, flush: true);
    return file.path;
  }

  Future<void> shareReportPdf({
    required String periodLabel,
    required String currencyCode,
    required int incomeMinor,
    required int expenseMinor,
    required int balanceMinor,
    required List<CategorySpendingItem> categories,
    required List<FinancialTransaction> transactions,
  }) async {
    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Text(
            'Money Wise - Financial Report',
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 5),
          pw.Text('$periodLabel · $currencyCode'),
          pw.SizedBox(height: 20),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            children: [
              _summaryRow(
                'Income',
                formatMinorUnits(incomeMinor, currencyCode),
              ),
              _summaryRow(
                'Expenses',
                formatMinorUnits(expenseMinor, currencyCode),
              ),
              _summaryRow(
                'Net cash flow',
                formatMinorUnits(incomeMinor - expenseMinor, currencyCode),
              ),
              _summaryRow(
                'Current balance',
                formatMinorUnits(balanceMinor, currencyCode),
              ),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Text('Spending by category', style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 7),
          if (categories.isEmpty)
            pw.Text('No expenses were recorded in this period.')
          else
            pw.TableHelper.fromTextArray(
              headers: const ['Category', 'Amount', 'Share'],
              data: [
                for (final item in categories)
                  [
                    item.category,
                    formatMinorUnits(item.amountMinor, currencyCode),
                    '${item.sharePercent}%',
                  ],
              ],
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            ),
          pw.SizedBox(height: 20),
          pw.Text('Transactions', style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 7),
          if (transactions.isEmpty)
            pw.Text('No transactions were recorded in this period.')
          else
            pw.TableHelper.fromTextArray(
              headers: const ['Date', 'Description', 'Type', 'Amount'],
              data: [
                for (final entry in transactions)
                  [
                    '${entry.occurredAt.day}/${entry.occurredAt.month}/${entry.occurredAt.year}',
                    entry.description,
                    entry.type.name,
                    formatMinorUnits(entry.amountMinor, entry.currencyCode),
                  ],
              ],
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
              cellStyle: const pw.TextStyle(fontSize: 8),
            ),
          pw.SizedBox(height: 15),
          pw.Text(
            "Values are reported in each transaction's original currency. Transfers are excluded from income and expense totals.",
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
        ],
      ),
    );
    final bytes = await document.save();
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'moneywise_report_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  Future<Directory> _exportDirectory() async {
    final base = await getApplicationDocumentsDirectory();
    final directory = Directory(path.join(base.path, 'moneywise', 'exports'));
    if (!await directory.exists()) await directory.create(recursive: true);
    return directory;
  }

  static pw.TableRow _summaryRow(String label, String value) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(label),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(value),
        ),
      ],
    );
  }
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
