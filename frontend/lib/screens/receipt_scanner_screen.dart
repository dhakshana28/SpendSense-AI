import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/receipt_scanner_service.dart';

class ReceiptScannerScreen extends StatefulWidget {
  const ReceiptScannerScreen({super.key});

  @override
  State<ReceiptScannerScreen> createState() => _ReceiptScannerScreenState();
}

class _ReceiptScannerScreenState extends State<ReceiptScannerScreen> {
  final ImagePicker _picker = ImagePicker();
  ReceiptData? _receiptData;
  bool _isScanning = false;

  Future<void> _pickImage(ImageSource source) async {
    final XFile? photo = await _picker.pickImage(source: source, imageQuality: 80);
    if (photo == null) return;

    setState(() {
      _isScanning = true;
      _receiptData = null;
    });

    final data = await ReceiptScannerService.scanReceipt(photo.path);

    setState(() {
      _receiptData = data;
      _isScanning = false;
    });
  }

  Future<void> _addExpenseFromReceipt() async {
    if (_receiptData == null || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Expense from Receipt'),
        content: Text('Add Rs. ${_receiptData!.amount?.toStringAsFixed(0) ?? "0"} for ${_receiptData!.suggestedCategory ?? "Others"}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expense added successfully!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt Scanner'),
        actions: [
          if (_receiptData != null)
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _addExpenseFromReceipt,
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Camera'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Gallery'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (_isScanning)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Scanning receipt...'),
                    ],
                  ),
                ),
              ),
            if (_receiptData != null && !_isScanning)
              Expanded(
                child: SingleChildScrollView(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Receipt Details', style: Theme.of(context).textTheme.titleLarge),
                          const Divider(),
                          if (_receiptData!.merchantName != null)
                            _buildRow('Merchant', _receiptData!.merchantName!, isDark),
                          if (_receiptData!.amount != null)
                            _buildRow('Amount', 'Rs. ${_receiptData!.amount!.toStringAsFixed(2)}', isDark),
                          if (_receiptData!.date != null)
                            _buildRow('Date', _receiptData!.date!.toIso8601String().split('T')[0], isDark),
                          if (_receiptData!.suggestedCategory != null)
                            _buildRow('Category', _receiptData!.suggestedCategory!, isDark),
                          if (_receiptData!.paymentMethod != null)
                            _buildRow('Payment', _receiptData!.paymentMethod!, isDark),
                          if (_receiptData!.items.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Text('Items:', style: Theme.of(context).textTheme.titleSmall),
                            ..._receiptData!.items.map((item) => Padding(
                              padding: const EdgeInsets.only(left: 16, top: 4),
                              child: Text(item, style: Theme.of(context).textTheme.bodySmall),
                            )),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}