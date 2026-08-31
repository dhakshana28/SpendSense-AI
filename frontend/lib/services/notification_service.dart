import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'spendsense_alerts',
    'SpendSense AI Alerts',
    description: 'Budget alerts, wallet alerts, and financial notifications',
    importance: Importance.high,
  );

  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      // Initialize timezone data
      tz.initializeTimeZones();

      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (response) {
          debugPrint('Notification tapped: ${response.payload}');
        },
      );

      // Create the notification channel
      await _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);

      // Request permissions on Android 13+
      await _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();

      debugPrint('NotificationService: Initialized successfully');
    } catch (e) {
      debugPrint('NotificationService: Initialization failed: $e');
    }
  }

  static Future<void> showNotification({
    required int notificationId,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      if (!_initialized) {
        await initialize();
      }

      final androidDetails = AndroidNotificationDetails(
        _channel.id,
        _channel.name,
        channelDescription: _channel.description,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        styleInformation: const DefaultStyleInformation(true, true),
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.show(
        id: notificationId,
        title: title,
        body: body,
        notificationDetails: details,
        payload: payload,
      );

      debugPrint('NotificationService: Shown notification #$notificationId: $title');
    } catch (e) {
      debugPrint('NotificationService: Failed to show notification: $e');
    }
  }

  /// Schedule a notification for a specific time.
  static Future<void> scheduleNotification({
    required int notificationId,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
  }) async {
    try {
      if (!_initialized) {
        await initialize();
      }

      final androidDetails = AndroidNotificationDetails(
        _channel.id,
        _channel.name,
        channelDescription: _channel.description,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.zonedSchedule(
        id: notificationId,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.from(scheduledTime, tz.local),
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: payload,
      );

      debugPrint('NotificationService: Scheduled notification #$notificationId at $scheduledTime');
    } catch (e) {
      debugPrint('NotificationService: Failed to schedule notification: $e');
    }
  }

  /// Cancel a specific notification.
  static Future<void> cancelNotification(int notificationId) async {
    try {
      await _notifications.cancel(id: notificationId);
    } catch (e) {
      debugPrint('NotificationService: Failed to cancel notification: $e');
    }
  }

  static Future<void> cancelAll() async {
    try {
      await _notifications.cancelAll();
      debugPrint('NotificationService: All notifications cancelled');
    } catch (e) {
      debugPrint('NotificationService: Failed to cancel all notifications: $e');
    }
  }

  // ===== CONVENIENCE METHODS =====

  /// Budget alert notification.
  static Future<void> showBudgetAlert({
    required String category,
    required double spent,
    required double budget,
    required double percentage,
  }) async {
    final id = 'budget_${category.hashCode}'.hashCode.abs() % 100000;
    final overBy = spent - budget;

    String title;
    String body;

    if (percentage >= 100) {
      title = '🚫 $category Budget Exceeded';
      body = 'You have spent ₹${spent.toStringAsFixed(0)} of your ₹${budget.toStringAsFixed(0)} budget. '
          'Over by ₹${overBy.toStringAsFixed(0)}.';
    } else if (percentage >= 90) {
      title = '⚠️ $category Budget at ${percentage.toStringAsFixed(0)}%';
      body = 'You have used ${percentage.toStringAsFixed(0)}% of your $category budget. '
          'Only ₹${(budget - spent).toStringAsFixed(0)} remaining.';
    } else {
      title = 'ℹ️ $category Budget at ${percentage.toStringAsFixed(0)}%';
      body = 'You have used ${percentage.toStringAsFixed(0)}% of your $category budget. '
          '₹${(budget - spent).toStringAsFixed(0)} remaining.';
    }

    await showNotification(
      notificationId: id,
      title: title,
      body: body,
      payload: 'budget_alert_$category',
    );
  }

  /// Wallet low balance notification.
  static Future<void> showWalletLowBalanceAlert({
    required String walletName,
    required double balance,
  }) async {
    final id = 'wallet_low_${walletName.hashCode}'.hashCode.abs() % 100000;
    await showNotification(
      notificationId: id,
      title: '⚠️ Low Wallet Balance',
      body: 'Your $walletName wallet balance is ₹${balance.toStringAsFixed(0)}. '
          'Consider adding funds or reducing spending.',
      payload: 'wallet_low_$walletName',
    );
  }

  /// Wallet limit exceeded notification.
  static Future<void> showWalletLimitAlert({
    required String walletName,
    required double spent,
    required double limit,
  }) async {
    final id = 'wallet_limit_${walletName.hashCode}'.hashCode.abs() % 100000;
    await showNotification(
      notificationId: id,
      title: '🚫 Wallet Spending Limit Exceeded',
      body: 'Your $walletName wallet has spent ₹${spent.toStringAsFixed(0)} '
          'exceeding the monthly limit of ₹${limit.toStringAsFixed(0)}.',
      payload: 'wallet_limit_$walletName',
    );
  }

  /// Goal deadline notification.
  static Future<void> showGoalDeadlineAlert({
    required String goalTitle,
    required DateTime deadline,
    required double progress,
  }) async {
    final id = 'goal_deadline_${goalTitle.hashCode}'.hashCode.abs() % 100000;
    final daysLeft = deadline.difference(DateTime.now()).inDays;
    await showNotification(
      notificationId: id,
      title: '🎯 Goal Deadline Approaching',
      body: 'Your "$goalTitle" goal is ${(progress * 100).toStringAsFixed(0)}% complete '
          'with $daysLeft days remaining.',
      payload: 'goal_deadline_$goalTitle',
    );
  }

  /// Savings milestone notification.
  static Future<void> showSavingsMilestoneAlert({
    required double amount,
    required String message,
  }) async {
    final id = 'savings_milestone_${amount.toInt()}'.hashCode.abs() % 100000;
    await showNotification(
      notificationId: id,
      title: '🎉 Savings Milestone Reached!',
      body: message,
      payload: 'savings_milestone',
    );
  }

  /// Monthly report available notification.
  static Future<void> showMonthlyReportAlert() async {
    await showNotification(
      notificationId: 9001,
      title: '📊 Monthly Report Available',
      body: 'Your monthly financial report is ready. Check the Reports section for insights.',
      payload: 'monthly_report',
    );
  }

  /// Subscription renewal notification.
  static Future<void> showSubscriptionRenewalAlert({
    required String subscriptionName,
    required double amount,
  }) async {
    final id = 'subscription_${subscriptionName.hashCode}'.hashCode.abs() % 100000;
    await showNotification(
      notificationId: id,
      title: '💳 Subscription Renewal',
      body: 'Your $subscriptionName subscription of ₹${amount.toStringAsFixed(0)} '
          'is due for renewal soon.',
      payload: 'subscription_$subscriptionName',
    );
  }

  /// Large expense notification.
  static Future<void> showLargeExpenseAlert({
    required double amount,
    required String category,
    required String description,
  }) async {
    final id = 'large_expense_${amount.toInt()}'.hashCode.abs() % 100000;
    await showNotification(
      notificationId: id,
      title: '🔔 Large Expense Detected',
      body: '₹${amount.toStringAsFixed(0)} spent on $category'
          '${description.isNotEmpty ? ' - $description' : ''}.',
      payload: 'large_expense',
    );
  }

  /// Daily spending summary notification.
  static Future<void> showDailySpendingSummary({
    required double todaySpent,
    required double yesterdaySpent,
    required int transactionCount,
  }) async {
    final change = yesterdaySpent > 0
        ? ((todaySpent - yesterdaySpent) / yesterdaySpent * 100)
        : 0.0;
    final trend = change > 0
        ? 'up ${change.toStringAsFixed(0)}% from yesterday'
        : change < 0
            ? 'down ${change.abs().toStringAsFixed(0)}% from yesterday'
            : 'same as yesterday';

    await showNotification(
      notificationId: 9002,
      title: '📊 Daily Spending Summary',
      body: 'Today: ₹${todaySpent.toStringAsFixed(0)} across $transactionCount transactions '
          '($trend).',
      payload: 'daily_summary',
    );
  }
}