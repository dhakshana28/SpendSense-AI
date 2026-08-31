import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

import '../models/bank_statement_model.dart';
import '../models/expense_model.dart';
import '../models/income_model.dart';
import '../providers/expense_provider.dart';
import '../providers/income_provider.dart';
import '../providers/budget_provider.dart';
import '../providers/goal_provider.dart';
import '../providers/ai_provider.dart';
import '../providers/user_provider.dart';
import '../services/bank_statement_parser.dart';
import '../widgets/glass_card.dart';

class BankStatementImportScreen extends StatefulWidget {
  const BankStatementImportScreen({super.key});

  @override
  State<BankStatementImportScreen> createState() => _BankStatementImportScreenState();
}

class _BankStatementImportScreenState extends State<BankStatementImportScreen> {
  final _uuid = const Uuid();
  final TextEditingController _csvController = TextEditingController();
  final ScrollController _previewScrollController = ScrollController();

  // State
  bool _isLoading = false;
  bool _isImporting = false;
  bool _isParsing = false;
  String? _progressMessage;
  bool _hasExtractedText = false;
  String? _error;
  String? _fileName;
  Uint8List? _fileBytes;
  String? _extractedTextPreview;
  BankStatementSummary? _summary;
  List<BankTransaction> _transactions = [];
  final Set<String> _selectedIds = {};

  @override
  void dispose() {
    _csvController.dispose();
    _previewScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Import Bank Statement'),
          centerTitle: true,
        ),
        body: SafeArea(
          child: _isLoading
              ? _buildLoadingOverlay()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildUploadCard(context),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        _buildErrorCard(context, _error!),
                      ],
                      if (_fileName != null && !_hasExtractedText) ...[
                        const SizedBox(height: 16),
                        _buildFileInfoCard(context),
                      ],
                      if (_extractedTextPreview != null) ...[
                        const SizedBox(height: 16),
                        _buildTextPreviewCard(context),
                      ],
                      if (_summary != null) ...[
                        const SizedBox(height: 20),
                        _buildSummaryCard(context, _summary!, Theme.of(context).brightness == Brightness.dark),
                        const SizedBox(height: 20),
                        _buildTransactionList(context, Theme.of(context).brightness == Brightness.dark),
                        const SizedBox(height: 20),
                        _buildImportButton(context),
                      ],
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(_progressMessage ?? 'Processing...'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUploadCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C63FF).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.upload_file, color: Color(0xFF6C63FF), size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Upload Bank Statement',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('Supports PDF, CSV, and Excel (.xlsx)',
                        style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isImporting ? null : () async {
                  // CRITICAL: Wrap entire file picker in try/catch to prevent screen from exiting
                  try {
                    await _pickFile();
                  } catch (e, stackTrace) {
                    debugPrint('❌ BankStatementImport: Unhandled error in file picker: $e');
                    debugPrint('❌ BankStatementImport: Stack trace: $stackTrace');
                    if (!mounted) return;
                    _showError('An unexpected error occurred: $e');
                  }
                },
                icon: const Icon(Icons.folder_open),
                label: const Text('Choose File'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Text('Optional: Paste CSV instead',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _csvController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Paste CSV content here...',
                filled: true,
                fillColor: isDark ? const Color(0xFF2A2A3E) : const Color(0xFFF0F0F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isImporting ? null : _parsePressed,
                icon: const Icon(Icons.analytics),
                label: const Text('Parse & Analyze'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileInfoCard(BuildContext context) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.description, color: Color(0xFF6C63FF)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_fileName!, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('Ready to parse', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            if (_isLoading)
              const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            else
              TextButton.icon(
                onPressed: _processFile,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Parse'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextPreviewCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.text_snippet, color: Color(0xFF6C63FF)),
                const SizedBox(width: 8),
                Text('Extracted Text Preview', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1A2E) : const Color(0xFFF0F0F5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Scrollbar(
                controller: _previewScrollController,
                child: SingleChildScrollView(
                  controller: _previewScrollController,
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _extractedTextPreview!,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _processFile,
                    icon: const Icon(Icons.check),
                    label: const Text('Parse Transactions'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFile() async {
    debugPrint('📎 BankStatementImport: Opening file picker...');

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx', 'xls', 'pdf'],
        withData: true,  // Required for Web to get file bytes
      );

      debugPrint('📎 BankStatementImport: File picker returned: ${result != null ? "file selected" : "cancelled"}');

      if (result == null || result.files.isEmpty) {
        debugPrint('📎 BankStatementImport: No file selected');
        return;
      }

      final file = result.files.first;
      final filePath = file.path;
      final fileBytes = file.bytes;

      debugPrint('📎 BankStatementImport: Selected file: ${file.name}');
      debugPrint('📎 BankStatementImport: File size: ${file.size} bytes');
      debugPrint('📎 BankStatementImport: Extension: ${file.extension}');
      debugPrint('📎 BankStatementImport: filePath: $filePath');
      debugPrint('📎 BankStatementImport: bytes available: ${fileBytes != null}');

      if (filePath == null && fileBytes == null) {
        debugPrint('❌ BankStatementImport: Both filePath and bytes are null');
        _showError('Unable to read file. Please try again.');
        return;
      }

      setState(() {
        _fileName = file.name;
        _fileBytes = fileBytes;
        _error = null;
        _hasExtractedText = false;
        _extractedTextPreview = null;
        _summary = null;
        _transactions = [];
        _selectedIds.clear();
      });

      debugPrint('📎 BankStatementImport: Stored ${_fileBytes?.length} bytes in state');
    } catch (e) {
      debugPrint('❌ BankStatementImport: File picker error: $e');
      debugPrint('❌ BankStatementImport: Stack trace: ${StackTrace.current}');
      _showError('Failed to select file: $e');
    }
  }

  Future<void> _processFile() async {
    if (_fileName == null) return;
    // Prevent duplicate parse requests from repeated button taps.
    if (_isParsing) return;

    setState(() {
      _isParsing = true;
      _isLoading = true;
      _error = null;
      _progressMessage = 'Reading bank statement...';
    });

    try {
      debugPrint('[PDF_IMPORT] Processing file: $_fileName');
      final fileBytes = _fileBytes;
      if (fileBytes == null) {
        throw FormatException('Unable to read the selected file data. Please select the file again.');
      }
      debugPrint('[PDF_IMPORT] File bytes available, size: ${fileBytes.length}');

      final ext = _fileName!.split('.').last.toLowerCase();
      // All file types (PDF/CSV/XLSX) are parsed here — PDF never returns early.
      setState(() => _progressMessage =
          ext == 'pdf' ? 'Extracting transactions from PDF...' : 'Parsing transactions...');

      final transactions = await BankStatementParser.parseFile(
        fileName: _fileName!,
        bytes: fileBytes,
      );
      debugPrint('[PDF_PARSE] Parsed transactions: ${transactions.length}');

      setState(() => _progressMessage = 'Categorizing transactions...');
      final summary = BankStatementParser.buildSummary(transactions);
      debugPrint('[CATEGORIZE] Categorized ${transactions.length} transactions');
      debugPrint('[CATEGORIZE] Top categories: ${summary.categoryBreakdown.length}');

      if (!mounted) {
        debugPrint('❌ BankStatementImport: Widget not mounted after parsing');
        return;
      }

      setState(() {
        _transactions = transactions;
        _summary = summary;
        _selectedIds.addAll(transactions.map((t) => t.id));
        _hasExtractedText = false;
        _extractedTextPreview = null;
        _isParsing = false;
        _isLoading = false;
        _progressMessage = null;
      });

      debugPrint('✅ BankStatementImport: UI updated with ${transactions.length} transactions');
    } catch (e) {
      debugPrint('❌ BankStatementImport: Processing failed: $e');
      if (mounted) {
        setState(() {
          _isParsing = false;
          _isLoading = false;
          _progressMessage = null;
        });
        _showError(_friendlyError(e));
      }
    }
  }

  /// Translate raw parser exceptions into clear, user-friendly messages.
  String _friendlyError(Object e) {
    final msg = e.toString().replaceAll('FormatException: ', '');
    if (msg.contains('scanned') || msg.contains('image-based')) {
      return 'This PDF appears to be scanned/image-based. OCR is required to extract transactions.';
    }
    if (msg.contains('Unsupported file format')) {
      return 'Please select a PDF, CSV, or XLSX bank statement.';
    }
    if (msg.contains('Unable to read')) {
      return 'Unable to read the selected file. Please select it again.';
    }
    if (msg.contains('No transaction')) {
      return 'No transaction rows were detected. The statement may be scanned or use an unsupported layout.';
    }
    return msg.isNotEmpty ? msg : 'An unexpected error occurred.';
  }


  /// Dispatch parsing based on what's available — file or pasted CSV.
  Future<void> _parsePressed() async {
    if (_fileName != null && _fileBytes != null) {
      await _processFile();
    } else if (_csvController.text.trim().isNotEmpty) {
      await _parsePastedCsv();
    } else {
      _showError('Please select a file or paste CSV data.');
    }
  }

  Future<void> _parsePastedCsv() async {
    final csvText = _csvController.text.trim();
    if (csvText.isEmpty) {
      _showError('Please paste CSV data first.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _hasExtractedText = false;
      _extractedTextPreview = null;
      _summary = null;
      _transactions = [];
      _selectedIds.clear();
    });

    try {
      final transactions = await BankStatementParser.parseCsvText(csvText);
      final summary = BankStatementParser.buildSummary(transactions);

      setState(() {
        _transactions = transactions;
        _summary = summary;
        _selectedIds.addAll(transactions.map((t) => t.id));
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ BankStatementImport: CSV parsing failed: $e');
      _showError(e.toString().replaceAll('FormatException: ', ''));
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() => _error = message);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFFF4757),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  Widget _buildErrorCard(BuildContext context, String error) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFF4757).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFF4757).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFFF4757), size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(error, style: const TextStyle(color: Color(0xFFFF4757)))),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, BankStatementSummary summary, bool isDark) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Statement Summary',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildSummaryItem(context, 'Total Income', '₹${summary.totalIncome.toStringAsFixed(0)}', const Color(0xFF00D9A6)),
                const SizedBox(width: 8),
                _buildSummaryItem(context, 'Total Expense', '₹${summary.totalExpense.toStringAsFixed(0)}', const Color(0xFFFF6584)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildSummaryItem(context, 'Net Savings', '₹${summary.netSavings.toStringAsFixed(0)}',
                  summary.netSavings >= 0 ? const Color(0xFF00D9A6) : const Color(0xFFFF4757)),
                const SizedBox(width: 8),
                _buildSummaryItem(context, 'Transactions', '${summary.totalTransactions}', const Color(0xFF6C63FF)),
              ],
            ),
            if (summary.categoryBreakdown.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Top Categories', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ..._buildTopCategories(context, summary.categoryBreakdown),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buildTopCategories(BuildContext context, Map<String, double> breakdown) {
    final sorted = breakdown.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(5).map((e) => Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(child: Text(e.key, style: Theme.of(context).textTheme.bodySmall)),
          Text('₹${e.value.toStringAsFixed(0)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    )).toList();
  }

  Widget _buildSummaryItem(BuildContext context, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionList(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Transactions',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const Spacer(),
            TextButton(
              onPressed: () {
                setState(() {
                  if (_selectedIds.length == _transactions.length) {
                    _selectedIds.clear();
                  } else {
                    _selectedIds.addAll(_transactions.map((t) => t.id));
                  }
                });
              },
              child: Text(_selectedIds.length == _transactions.length ? 'Deselect All' : 'Select All'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ..._transactions.take(50).map((t) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GlassCard(
            child: CheckboxListTile(
              value: _selectedIds.contains(t.id),
              onChanged: (checked) {
                setState(() {
                  if (checked == true) {
                    _selectedIds.add(t.id);
                  } else {
                    _selectedIds.remove(t.id);
                  }
                });
              },
              title: Text(t.description, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                '${t.date.day}/${t.date.month}/${t.date.year} • ${t.category}'
                '${t.merchant.isNotEmpty ? ' • ${t.merchant}' : ''}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              controlAffinity: ListTileControlAffinity.leading,
              secondary: Text(
                '${t.isExpense ? '-' : '+'}₹${t.amount.toStringAsFixed(0)}',
                style: TextStyle(
                  color: t.isExpense ? const Color(0xFFFF6584) : const Color(0xFF00D9A6),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        )),
        if (_transactions.length > 50)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Center(
              child: Text('Showing first 50 of ${_transactions.length} transactions',
                style: Theme.of(context).textTheme.bodySmall),
            ),
          ),
      ],
    );
  }

  Widget _buildImportButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isImporting || _selectedIds.isEmpty ? null : _importSelected,
        icon: _isImporting
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.cloud_upload),
        label: Text(_isImporting
            ? 'Importing...'
            : 'Import ${_selectedIds.length} Selected Transactions'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00D9A6),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Future<void> _importSelected() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showError('User not authenticated');
      return;
    }

    setState(() => _isImporting = true);

    try {
      debugPrint('📤 BankStatementImport: Starting import of ${_selectedIds.length} transactions');
      
      final expenseProvider = context.read<ExpenseProvider>();
      final incomeProvider = context.read<IncomeProvider>();
      final aiProvider = context.read<AIProvider>();

      final selected = _transactions.where((t) => _selectedIds.contains(t.id)).toList();
      int expenseCount = 0;
      int incomeCount = 0;

      for (final t in selected) {
        if (t.isExpense) {
          final expense = ExpenseModel(
            id: _uuid.v4(),
            userId: user.uid,
            amount: t.amount,
            category: t.category,
            paymentMethod: 'Bank Statement',
            description: t.description,
            date: t.date,
            createdAt: DateTime.now(),
          );
          await expenseProvider.addExpense(expense);
          expenseCount++;
        } else if (t.isIncome) {
          final income = IncomeModel(
            id: _uuid.v4(),
            userId: user.uid,
            amount: t.amount,
            category: 'Salary',
            source: t.merchant,
            description: t.description,
            date: t.date,
            createdAt: DateTime.now(),
          );
          await incomeProvider.addIncome(income);
          incomeCount++;
        }
      }

      debugPrint('✅ BankStatementImport: Imported $expenseCount expenses and $incomeCount incomes');

      if (!mounted) return;

      // Trigger AI analysis
      final incomeProvider2 = context.read<IncomeProvider>();
      final expenseProvider2 = context.read<ExpenseProvider>();
      final budgetProvider = context.read<BudgetProvider>();
      final goalProvider = context.read<GoalProvider>();
      final userProvider = context.read<UserProvider>();

      debugPrint('🤖 BankStatementImport: Running AI analysis...');
      aiProvider.runFullAnalysis(
        incomes: incomeProvider2.incomeList,
        expenses: expenseProvider2.expenses,
        budgets: budgetProvider.budgets,
        goals: goalProvider.goals,
        financialPersona: userProvider.persona,
      );
      debugPrint('✅ BankStatementImport: AI analysis completed');

      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Imported $expenseCount expenses and $incomeCount incomes successfully!'),
          backgroundColor: const Color(0xFF00D9A6),
          duration: const Duration(seconds: 3),
        ),
      );

      setState(() {
        _isImporting = false;
        _summary = null;
        _transactions = [];
        _selectedIds.clear();
        _csvController.clear();
        _fileName = null;
        _extractedTextPreview = null;
        _hasExtractedText = false;
      });
    } catch (e) {
      debugPrint('❌ BankStatementImport: Import failed: $e');
      debugPrint('❌ BankStatementImport: Stack trace: ${StackTrace.current}');
      _showError('Import failed: $e');
      setState(() => _isImporting = false);
    }
  }
}
