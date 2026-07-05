import 'dart:convert';
import 'dart:io';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/auto_pay.dart';
import '../models/enums.dart';
import '../repositories/autopay_engine.dart';
import '../repositories/hive_boxes.dart';

int _alarmId(String autoPayId) => autoPayId.hashCode & 0x7fffffff;

/// Schedules exact-time reminders / background auto-adds for auto-pays using
/// AndroidAlarmManager. Android-only; safely no-ops elsewhere.
class AutoPayScheduler {
  AutoPayScheduler._();

  static bool get _supported {
    try {
      return Platform.isAndroid;
    } catch (_) {
      return false;
    }
  }

  /// Cancels and re-schedules the next occurrence for every reminder-enabled
  /// auto-pay.
  static Future<void> rescheduleAll(List<AutoPay> autoPays) async {
    if (!_supported) return;
    final now = DateTime.now();
    for (final ap in autoPays) {
      final id = _alarmId(ap.id);
      try {
        await AndroidAlarmManager.cancel(id);
        final next = AutoPayEngine.nextOccurrence(ap, now);
        if (next == null) continue;
        await AndroidAlarmManager.oneShotAt(
          next,
          id,
          autoPayAlarmCallback,
          exact: true,
          wakeup: true,
          allowWhileIdle: true,
          rescheduleOnReboot: true,
        );
      } catch (_) {
        // Ignore scheduling failures (e.g. exact-alarm permission denied).
      }
    }
  }
}

/// Runs in a background isolate when an auto-pay alarm fires: posts due
/// transactions, shows a notification, and reschedules the next occurrence.
@pragma('vm:entry-point')
Future<void> autoPayAlarmCallback() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    await Hive.initFlutter();

    Future<Box<String>> open(String name) async =>
        Hive.isBoxOpen(name) ? Hive.box<String>(name) : Hive.openBox<String>(name);

    final autoPays = await open(BoxNames.autoPays);
    final transactions = await open(BoxNames.transactions);
    final accounts = await open(BoxNames.accounts);
    final paymentModes = await open(BoxNames.paymentModes);

    const uuid = Uuid();
    final fired = await AutoPayEngine.run(
      autoPays: autoPays,
      transactions: transactions,
      accounts: accounts,
      paymentModes: paymentModes,
      newId: uuid.v4,
    );

    if (fired.isNotEmpty) {
      final plugin = FlutterLocalNotificationsPlugin();
      await plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      for (final ap in fired) {
        if (!ap.notifyEnabled) continue;
        await plugin.show(
          id: ap.id.hashCode,
          title: ap.flow == FlowType.income ? 'Income added' : 'Payment made',
          body: '${ap.name}: ${ap.amount.toStringAsFixed(0)}',
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'autopay',
              'Auto-Pay',
              channelDescription: 'Auto-pay reminders and posted logs',
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
        );
      }
    }

    // Reschedule the next occurrence for all reminder-enabled items.
    final all = autoPays.values
        .map((s) => AutoPay.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
    await AutoPayScheduler.rescheduleAll(all);
  } catch (_) {
    // Background best-effort; the in-app on-open pass is the reliable backstop.
  }
}
