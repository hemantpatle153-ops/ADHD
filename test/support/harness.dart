// Shared setup for widget tests: the real app wired to in-memory stores and
// fake reminders, with a fixed clock (Sunday 4 Oct 2026, 10:10).
import 'dart:async';

import 'package:brightday/app.dart';
import 'package:brightday/data/settings_store.dart';
import 'package:brightday/data/task_store.dart';
import 'package:brightday/models/settings.dart';
import 'package:brightday/models/task.dart';
import 'package:brightday/services/breakdown_service.dart';
import 'package:brightday/services/notification_service.dart';
import 'package:brightday/state/planner_controller.dart';
import 'package:brightday/state/settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Behaves like a phone where the notification plugin is broken: every call
/// throws. The app must still work, just without reminders.
class BrokenReminders implements Reminders {
  int calls = 0;

  Never _fail() {
    calls++;
    throw StateError('notification plugin unavailable');
  }

  @override
  Future<void> init() async => _fail();
  @override
  Future<bool> requestPermission() async => _fail();
  @override
  Future<void> syncTask(PlannerTask task) async => _fail();
  @override
  Future<void> cancelTask(String taskId) async => _fail();
  @override
  Future<void> scheduleFocusEnd(DateTime at, String taskTitle) async => _fail();
  @override
  Future<void> cancelFocusEnd() async => _fail();
}

/// A permission prompt the user never answers.
class HangingReminders extends NoopReminders {
  @override
  Future<bool> requestPermission() => Completer<bool>().future;
}

final testNow = DateTime(2026, 10, 4, 10, 10);

PlannerTask makeTask(
  String id,
  String title, {
  int? start,
  int duration = 30,
  DateTime? day,
  bool done = false,
}) => PlannerTask(
  id: id,
  title: title,
  day: day ?? DateTime(2026, 10, 4),
  startMinute: start,
  durationMinutes: duration,
  done: done,
  createdAt: DateTime(2026, 10, 1),
);

class Harness {
  Harness(this.planner, this.settings, this.settingsStore, this.taskStore);
  final PlannerController planner;
  final SettingsController settings;
  final MemorySettingsStore settingsStore;
  final MemoryTaskStore taskStore;
}

Future<Harness> pumpApp(
  WidgetTester tester, {
  AppSettings settings = const AppSettings(),
  List<PlannerTask> tasks = const [],
  Reminders? reminders,
}) async {
  final r = reminders ?? NoopReminders();
  final taskStore = MemoryTaskStore(tasks);
  final planner = PlannerController(
    store: taskStore,
    reminders: r,
    clock: () => testNow,
  );
  final settingsStore = MemorySettingsStore(settings);
  final s = SettingsController(settingsStore);
  await s.load();
  await planner.load();
  await tester.binding.setSurfaceSize(const Size(420, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    BrightdayApp(
      planner: planner,
      settings: s,
      breakdown: SmartBreakdown(),
      reminders: r,
    ),
  );
  await tester.pumpAndSettle();
  return Harness(planner, s, settingsStore, taskStore);
}

/// The day view opens scrolled to the now line; go back to the top.
Future<void> scrollToTop(WidgetTester tester) async {
  await tester.fling(
    find.byType(Scrollable).first,
    const Offset(0, 3000),
    5000,
  );
  await tester.pumpAndSettle();
}

Future<void> skipToNamePage(WidgetTester tester) async {
  await tester.tap(find.text('Skip'));
  await tester.pumpAndSettle();
}

const onboarded = AppSettings(onboardingDone: true);
