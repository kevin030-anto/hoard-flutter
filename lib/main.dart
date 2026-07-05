import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';

import 'app.dart';
import 'data/repositories/hive_boxes.dart';
import 'data/repositories/seed_data.dart';
import 'providers/app_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final boxes = await HiveBoxes.open();
  await SeedData.seedIfEmpty(boxes);

  if (!kIsWeb && Platform.isAndroid) {
    try {
      await AndroidAlarmManager.initialize();
    } catch (_) {}
  }

  runApp(
    ProviderScope(
      overrides: [hiveBoxesProvider.overrideWithValue(boxes)],
      child: const FinFlowApp(),
    ),
  );
}
