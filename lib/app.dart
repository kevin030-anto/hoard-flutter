import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'data/notifications/autopay_scheduler.dart';
import 'data/notifications/notification_service.dart';
import 'providers/app_providers.dart';
import 'router.dart';

class FinFlowApp extends ConsumerStatefulWidget {
  const FinFlowApp({super.key});

  @override
  ConsumerState<FinFlowApp> createState() => _FinFlowAppState();
}

class _FinFlowAppState extends ConsumerState<FinFlowApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runStartupTasks());
  }

  Future<void> _runStartupTasks() async {
    await NotificationService.instance.init();
    final notifier = ref.read(appProvider.notifier);
    final currency = ref.read(appProvider).settings.currencySymbol;
    final fired = await notifier.processDueAutoPays();
    for (final ap in fired) {
      await NotificationService.instance.showAutoPayPosted(ap, currency);
    }
    // Schedule exact-time reminders / background auto-adds.
    await AutoPayScheduler.rescheduleAll(ref.read(appProvider).autoPays);
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(appProvider.select((d) => d.settings.themeMode));
    return MaterialApp.router(
      title: 'FinFlow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: appRouter,
    );
  }
}
