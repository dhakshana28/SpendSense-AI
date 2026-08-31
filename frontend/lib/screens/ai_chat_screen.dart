import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/ai_provider.dart';
import '../providers/income_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/budget_provider.dart';
import '../providers/goal_provider.dart';
import '../providers/user_provider.dart';

class AIChatScreen extends StatefulWidget {
  const AIChatScreen({super.key});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatBubble> _messages = [];
  AIProvider? _aiProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadHistory();
    });
  }

  @override
  void dispose() {
    _aiProvider?.removeListener(_onProviderChanged);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _loadHistory() {
    final aiProvider = context.read<AIProvider>();
    _aiProvider = aiProvider;
    aiProvider.subscribeToChatHistory();
    aiProvider.addListener(_onProviderChanged);
    _checkAndLoadHistory(aiProvider);
  }

  void _onProviderChanged() {
    if (!mounted) return;
    _checkAndLoadHistory(context.read<AIProvider>());
  }

  void _checkAndLoadHistory(AIProvider aiProvider) {
    if (!mounted) return;
    final history = aiProvider.chatHistory;
    if (history.isNotEmpty && _messages.isEmpty) {
      setState(() {
        // History is stored newest-first; reverse to show oldest first.
        final reversed = history.reversed.toList();
        for (final msg in reversed) {
          _messages.add(_ChatBubble(
            text: msg.question,
            isUser: true,
            timestamp: msg.timestamp,
          ));
          _messages.add(_ChatBubble(
            text: msg.response,
            isUser: false,
            timestamp: msg.timestamp,
          ));
        }
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage({String? retryText}) async {
    final text = (retryText ?? _messageController.text).trim();
    if (text.isEmpty) return;

    // Prevent duplicate requests while a previous message is still processing.
    if (context.read<AIProvider>().isChatLoading) return;

    // If retrying, remove the previous failed exchange (user msg + AI response)
    if (retryText != null && _messages.length >= 2) {
      setState(() {
        _messages.removeLast(); // AI response
        _messages.removeLast(); // User question
      });
    }

    _messageController.clear();

    final aiProvider = context.read<AIProvider>();
    final incomeProvider = context.read<IncomeProvider>();
    final expenseProvider = context.read<ExpenseProvider>();
    final budgetProvider = context.read<BudgetProvider>();
    final goalProvider = context.read<GoalProvider>();
    final userProvider = context.read<UserProvider>();

    final now = DateTime.now();
    setState(() {
      _messages.add(_ChatBubble(text: text, isUser: true, timestamp: now));
      _messages.add(const _ChatBubble(
        text: '',
        isUser: false,
        isLoading: true,
      ));
    });
    _scrollToBottom();

    final response = await aiProvider.sendChatMessage(
      message: text,
      incomes: incomeProvider.incomeList,
      expenses: expenseProvider.expenses,
      budgets: budgetProvider.budgets,
      goals: goalProvider.goals,
      financialPersona: userProvider.persona,
    );

    if (!mounted) return;

    setState(() {
      _messages.removeLast();
      _messages.add(_ChatBubble(
        text: response,
        isUser: false,
        timestamp: DateTime.now(),
        isFromFallback: aiProvider.isUsingLocalFallback,
      ));
    });
    _scrollToBottom();
  }

  void _copyMessage(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard'), duration: Duration(seconds: 1)),
    );
  }

  /// Finds the user message that preceded this AI response for retry.
  String? _findUserQuestionFor(_ChatBubble aiBubble) {
    final index = _messages.indexOf(aiBubble);
    if (index >= 1) {
      final prev = _messages[index - 1];
      if (prev.isUser) return prev.text;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final aiProvider = context.watch<AIProvider>();

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('AI Assistant'),
        actions: [
          if (aiProvider.chatHistory.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_all),
              tooltip: 'Clear history',
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Clear History'),
                    content: const Text('Delete all chat history?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Clear', style: TextStyle(color: Colors.red))),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await aiProvider.clearChatHistory();
                  setState(() => _messages.clear());
                }
              },
            ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'View history',
            onPressed: () => _showHistory(context, aiProvider),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
          // Local AI fallback banner
          if (aiProvider.isUsingLocalFallback)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: isDark ? const Color(0xFF3A2E1A) : const Color(0xFFFFF3CD),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: isDark ? const Color(0xFFFFC107) : const Color(0xFF856404)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Using Local AI temporarily.',
                      style: TextStyle(
                        color: isDark ? const Color(0xFFFFC107) : const Color(0xFF856404),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _messages.isEmpty
                ? _buildWelcomeScreen(isDark)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) => _buildMessageBubble(_messages[index], isDark),
                  ),
          ),
          Container(
            padding: EdgeInsets.only(
              left: 16, right: 16, top: 8,
              bottom: MediaQuery.of(context).padding.bottom + 8,
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: InputDecoration(
                      hintText: 'Ask me anything about your finances...',
                      filled: true,
                      fillColor: isDark ? const Color(0xFF2A2A3E) : const Color(0xFFF0F0F5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF6C63FF), Color(0xFF8B7FFF)],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildWelcomeScreen(bool isDark) {
    final suggestions = [
      'How can I save more?',
      'Where am I overspending?',
      'Can I buy a laptop next month?',
      'What is my biggest expense?',
      'Suggest a monthly budget.',
      'How should I start investing?',
      'What are the basics of income tax?',
      'How do mutual funds work?',
      'Should I get health insurance?',
      'How do I plan for a loan EMI?',
      'Which subscriptions should I cancel?',
      'How should I use my credit card wisely?',
    ];

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFF8B7FFF)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 20),
            Text(
              'SpendSense AI Assistant',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ask me anything about your finances.\nI\'ll analyze your data and give personalized advice.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            ...suggestions.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () {
                  _messageController.text = s;
                  _sendMessage();
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2A2A3E) : const Color(0xFFF0F0F5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(s, style: Theme.of(context).textTheme.bodyMedium),
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(_ChatBubble message, bool isDark) {
    if (message.isLoading) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2A2A3E) : const Color(0xFFF0F0F5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: 12),
              Text('Gemini AI is analyzing...'),
            ],
          ),
        ),
      );
    }

    final timeStr = message.timestamp != null
        ? DateFormat('h:mm a').format(message.timestamp!)
        : '';

    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: message.isUser
              ? const LinearGradient(colors: [Color(0xFF6C63FF), Color(0xFF8B7FFF)])
              : null,
          color: message.isUser ? null : (isDark ? const Color(0xFF2A2A3E) : const Color(0xFFF0F0F5)),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(message.isUser ? 16 : 4),
            bottomRight: Radius.circular(message.isUser ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.isUser)
              Text(
                message.text,
                style: const TextStyle(color: Colors.white),
              )
            else
              MarkdownBody(
                data: message.text,
                selectable: true,
                styleSheet: MarkdownStyleSheet(
                  p: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 14,
                    height: 1.4,
                  ),
                  strong: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                  listBullet: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                  code: TextStyle(
                    backgroundColor: isDark ? const Color(0xFF1A1A2E) : const Color(0xFFE8E8EE),
                    color: isDark ? const Color(0xFF8B7FFF) : const Color(0xFF6C63FF),
                    fontFamily: 'monospace',
                    fontSize: 13,
                  ),
                  codeblockDecoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1A1A2E) : const Color(0xFFE8E8EE),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  tableHead: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  tableBorder: TableBorder.all(
                    color: isDark ? Colors.white24 : Colors.black26,
                  ),
                ),
              ),
            if (timeStr.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  timeStr,
                  style: TextStyle(
                    fontSize: 11,
                    color: message.isUser ? Colors.white70 : (isDark ? Colors.white38 : Colors.black38),
                  ),
                ),
              ),
            if (!message.isUser) ...[
              if (message.isFromFallback)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '⚠️ Local AI response',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? const Color(0xFFFFC107) : const Color(0xFF856404),
                    ),
                  ),
                ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: () => _copyMessage(message.text),
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Icon(
                        Icons.copy,
                        size: 14,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      final question = _findUserQuestionFor(message);
                      if (question != null) {
                        _sendMessage(retryText: question);
                      }
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Icon(
                        Icons.refresh,
                        size: 14,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showHistory(BuildContext context, AIProvider aiProvider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text('Chat History', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Divider(),
            Expanded(
              child: aiProvider.chatHistory.isEmpty
                  ? Center(child: Text('No chat history', style: Theme.of(context).textTheme.bodyMedium))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: aiProvider.chatHistory.length,
                      itemBuilder: (_, i) {
                        final msg = aiProvider.chatHistory[i];
                        return Dismissible(
                          key: Key(msg.id),
                          direction: DismissDirection.endToStart,
                          onDismissed: (_) => aiProvider.deleteChatMessage(msg.id),
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            color: Colors.red,
                            child: const Icon(Icons.delete, color: Colors.white),
                          ),
                          child: Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(msg.question, maxLines: 2, overflow: TextOverflow.ellipsis),
                              subtitle: Text(msg.response, maxLines: 2, overflow: TextOverflow.ellipsis),
                              trailing: Text(
                                '${msg.timestamp.day}/${msg.timestamp.month}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatBubble {
  final String text;
  final bool isUser;
  final bool isLoading;
  final DateTime? timestamp;
  final bool isFromFallback;

  const _ChatBubble({
    required this.text,
    required this.isUser,
    this.isLoading = false,
    this.timestamp,
    this.isFromFallback = false,
  });
}