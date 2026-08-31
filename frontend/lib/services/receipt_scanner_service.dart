import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class ReceiptData {
  final String? merchantName;
  final double? amount;
  final DateTime? date;
  final String? suggestedCategory;
  final List<String> items;
  final String? paymentMethod;
  final String? rawText;

  const ReceiptData({
    this.merchantName,
    this.amount,
    this.date,
    this.suggestedCategory,
    this.items = const [],
    this.paymentMethod,
    this.rawText,
  });
}

class ReceiptScannerService {
  static final TextRecognizer _textRecognizer = TextRecognizer();

  static Future<ReceiptData> scanReceipt(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);

      final rawText = recognizedText.text;
      if (rawText.isEmpty) {
        return const ReceiptData(rawText: '');
      }

      final data = _parseReceiptText(rawText);
      return data;
    } catch (e) {
      debugPrint('ReceiptScannerService: Error: $e');
      return ReceiptData(rawText: 'Error: $e');
    }
  }

  static ReceiptData _parseReceiptText(String text) {
    final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();
    final lowerText = text.toLowerCase();

    double? amount;
    final amountPatterns = [
      RegExp(r'total[:\s]+₹?\s*([0-9,]+\.?[0-9]*)', caseSensitive: false),
      RegExp(r'amount[:\s]+₹?\s*([0-9,]+\.?[0-9]*)', caseSensitive: false),
      RegExp(r'₹\s*([0-9,]+\.?[0-9]*)'),
      RegExp(r'([0-9,]+\.?[0-9]*)\s*inr', caseSensitive: false),
    ];

    for (final pattern in amountPatterns) {
      final match = pattern.firstMatch(lowerText);
      if (match != null) {
        final amountStr = match.group(1)?.replaceAll(',', '') ?? '';
        amount = double.tryParse(amountStr);
        if (amount != null && amount > 0) break;
      }
    }

    DateTime? date;
    final datePatterns = [
      RegExp(r'(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})'),
      RegExp(r'(\d{4}-\d{2}-\d{2})'),
      RegExp(r'(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\s+\d{1,2},?\s+\d{4}', caseSensitive: false),
    ];

    for (final pattern in datePatterns) {
      final match = pattern.firstMatch(lowerText);
      if (match != null) {
        date = _parseDate(match.group(0) ?? '');
        if (date != null) break;
      }
    }

    String? merchantName;
    if (lines.isNotEmpty) {
      final firstLine = lines.first.trim();
      if (firstLine.length > 2 && firstLine.length < 50) {
        merchantName = firstLine;
      }
    }

    final items = <String>[];
    final itemPattern = RegExp(r'^[A-Za-z].*[0-9]', multiLine: false);
    for (final line in lines.skip(1)) {
      if (itemPattern.hasMatch(line) && line.length < 100) {
        items.add(line.trim());
      }
    }

    String? suggestedCategory;
    if (merchantName != null) {
      final m = merchantName.toLowerCase();
      if (m.contains('restaurant') || m.contains('cafe') || m.contains('hotel') || m.contains('kitchen')) {
        suggestedCategory = 'Food';
      } else if (m.contains('uber') || m.contains('ola') || m.contains('cab') || m.contains('travel')) {
        suggestedCategory = 'Transport';
      } else if (m.contains('amazon') || m.contains('flipkart') || m.contains('store') || m.contains('shop')) {
        suggestedCategory = 'Shopping';
      } else if (m.contains('pizza') || m.contains('burger') || m.contains('dominos') || m.contains('mcdonalds')) {
        suggestedCategory = 'Food';
      } else if (m.contains('movie') || m.contains('cinema') || m.contains('theatre')) {
        suggestedCategory = 'Entertainment';
      } else if (m.contains('hospital') || m.contains('pharmacy') || m.contains('clinic')) {
        suggestedCategory = 'Health';
      } else if (m.contains('petrol') || m.contains('fuel') || m.contains('gas')) {
        suggestedCategory = 'Transport';
      }
    }

    String? paymentMethod;
    if (lowerText.contains('credit card')) {
      paymentMethod = 'Credit Card';
    } else if (lowerText.contains('debit card')) {
      paymentMethod = 'Debit Card';
    } else if (lowerText.contains('cash')) {
      paymentMethod = 'Cash';
    } else if (lowerText.contains('upi')) {
      paymentMethod = 'UPI';
    } else if (lowerText.contains('wallet')) {
      paymentMethod = 'Wallet';
    }

    return ReceiptData(
      merchantName: merchantName,
      amount: amount,
      date: date ?? DateTime.now(),
      suggestedCategory: suggestedCategory ?? 'Others',
      items: items.take(10).toList(),
      paymentMethod: paymentMethod,
      rawText: text,
    );
  }

  static DateTime? _parseDate(String? text) {
    if (text == null || text.isEmpty) return null;

    try {
      final clean = text.replaceAll(RegExp(r'[a-zA-Z]+'), '').trim();
      final parts = clean.split(RegExp(r'[/-]'));

      if (parts.length == 3) {
        final a = int.tryParse(parts[0]) ?? 0;
        final b = int.tryParse(parts[1]) ?? 0;
        final c = int.tryParse(parts[2]) ?? 0;

        if (c > 1000) return DateTime(c, a > 12 ? b : a, a > 12 ? a : b);
        if (a > 1000) return DateTime(a, b, c);
        return DateTime(c, a, b);
      }
    } catch (_) {}
    return null;
  }

  static void dispose() {
    _textRecognizer.close();
  }
}