import 'dart:async';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'data/settings_store.dart';
import 'data/task_store.dart';
import 'services/breakdown_service.dart';
import 'services/notification_service.dart';
import 'state/planner_controller.dart';
import 'state/settings_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final dir = await getApplicationSupportDirectory();
  final reminders = LocalReminders();
  final settings = SettingsController(
    PrefsSettingsStore(SharedPreferencesAsync()),
  );
  final planner = PlannerController(
    store: JsonFileTaskStore(dir),
    reminders: reminders,
  );
  final breakdown = SmartBreakdown.fromEnvironment();

  await settings.load();
  breakdown.aiAllowed = settings.value.aiEnabled;
  // Reminder setup can be slow on first launch; don't block the first frame.
  unawaited(reminders.init().then((_) => planner.load()));

  runApp(
    BrightdayApp(
      planner: planner,
      settings: settings,
      breakdown: breakdown,
      reminders: reminders,
    ),
  );
}
