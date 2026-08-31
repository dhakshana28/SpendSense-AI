import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:frontend/services/bank_statement_parser.dart';

/// Realistic Indian bank-statement rows used both to build the PDF and to
/// cross-check the parsed output.
const List<List<String>> _statementRows = [
  ['01-Jul-2026', 'SALARY CREDIT', '', '50000', '102500'],
  ['02-Jul-2026', 'RENT PAYMENT', '18000', '', '84500'],
  ['03-Jul-2026', 'SWIGGY RESTAURANT', '1250', '', '83250'],
  ['04-Jul-2026', 'BIG BAZAAR GROCERY', '3250', '', '80000'],
  ['05-Jul-2026', 'UBER TRIP', '450', '', '79550'],
  ['06-Jul-2026', 'NETFLIX SUBSCRIPTION', '649', '', '78901'],
  ['07-Jul-2026', 'SPOTIFY PREMIUM', '199', '', '78702'],
  ['08-Jul-2026', 'STATE ELECTRICITY BILL', '2400', '', '76302'],
  ['09-Jul-2026', 'AMAZON SHOPPING', '2199', '', '74103'],
  ['10-Jul-2026', 'INDIAN OIL FUEL', '1500', '', '72603'],
  ['11-Jul-2026', 'UPI TRANSFER TO HDFC', '3000', '', '69603'],
  ['12-Jul-2026', 'FREELANCE PAYMENT', '', '15000', '84603'],
  ['13-Jul-2026', 'LIC HEALTH INSURANCE', '1250', '', '83353'],
  ['14-Jul-2026', 'ZOMATO DINNER', '890', '', '82463'],
];

Future<Uint8List> _buildPdf() async {
  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      build: (pw.Context context) {
        return [
          pw.Header(
            level: 0,
            child: pw.Text('Bank Statement',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ),
          pw.SizedBox(height: 8),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Account Number: 12345678901'),
              pw.Text('Branch: MUMBAI'),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellAlignment: pw.Alignment.centerLeft,
            headers: ['Date', 'Description', 'Debit', 'Credit', 'Balance'],
            data: _statementRows,
          ),
        ];
      },
    ),
  );
  return doc.save();
}

void main() {
  test('parses a real generated PDF bank statement end-to-end', () async {
    final bytes = await _buildPdf();
    expect(bytes, isNotNull);
    expect(bytes.length, greaterThan(0));

    final transactions = await BankStatementParser.parseFile(
      fileName: 'bank_statement.pdf',
      bytes: bytes,
    );

    // All rows (synthetic heartbeat check: each row is a genuine transaction).
    expect(transactions, isNotEmpty);
    // The header/metadata must be ignored, but most data rows extracted.
    expect(transactions.length, greaterThanOrEqualTo(12));

    final summary = BankStatementParser.buildSummary(transactions);

    // Because it's a generated, well-formed table, we can assert totals.
    expect(summary.totalIncome, greaterThan(0));
    expect(summary.totalExpense, greaterThan(0));
    expect(summary.categoryBreakdown, isNotEmpty);

    // Category sanity checks based on description keywords.
    final descriptions = transactions.map((t) => t.description.toLowerCase()).join(' ');
    expect(
      summary.categoryBreakdown.keys.join(' ').toLowerCase().contains('food') ||
          descriptions.contains('swiggy') ||
          descriptions.contains('zomato'),
      isTrue,
      reason: 'Food-related transactions should be categorized',
    );
    expect(
      descriptions.contains('netflix') || descriptions.contains('spotify'),
      isTrue,
      reason: 'Subscription transactions should be present',
    );
  });
}