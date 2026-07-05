import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/auto_pay.dart';
import '../models/enums.dart';

/// Thin, defensive wrapper around flutter_local_notifications. All calls are
/// guarded so unsupported platforms (web/desktop) never crash the app.
class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> init() async {
    if (_ready || kIsWeb) return;
    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const ios = DarwinInitializationSettings();
      await _plugin.initialize(
        settings: const InitializationSettings(android: android, iOS: ios),
      );
      if (!kIsWeb && Platform.isAndroid) {
        await _plugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
      }
      _ready = true;
    } catch (_) {
      // Notifications are best-effort; ignore failures.
    }
  }

  Future<void> showAutoPayPosted(AutoPay ap, String currency) async {
    if (!_ready || !ap.notifyEnabled) return;
    try {
      final isIncome = ap.flow == FlowType.income;
      await _plugin.show(
        id: ap.id.hashCode,
        title: isIncome ? 'Income added' : 'Auto-payment made',
        body: '${ap.name}: $currency${ap.amount.toStringAsFixed(0)}',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'autopay',
            'Auto-Pay',
            channelDescription: 'Notifications when an auto-pay posts',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    } catch (_) {}
  }
}
