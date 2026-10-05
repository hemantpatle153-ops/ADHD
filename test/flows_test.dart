// End-to-end style widget tests for the flows a new user hits first. They use
// in-memory stores and fake reminders, so they run on any machine and in CI.
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
class _BrokenReminders implements Reminders {
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
class _HangingReminders extends NoopReminders {
  @override
  Future<bool> requestPermission() => Completer<bool>().future;
}

final _now = DateTime(2026, 10, 4, 10, 10);

PlannerTask _task(
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

class _Harness {
  _Harness(this.planner, this.settings, this.settingsStore, this.taskStore);
  final PlannerController planner;
  final SettingsController settings;
  final MemorySettingsStore settingsStore;
  final MemoryTaskStore taskStore;
}

Future<_Harness> _pump(
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
    clock: () => _now,
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
  return _Harness(planner, s, settingsStore, taskStore);
}

/// The day view opens scrolled to the now line; go back to the top.
Future<void> _scrollToTop(WidgetTester tester) async {
  await tester.fling(
    find.byType(Scrollable).first,
    const Offset(0, 3000),
    5000,
  );
  await tester.pumpAndSettle();
}

Future<void> _skipToNamePage(WidgetTester tester) async {
  await tester.tap(find.text('Skip'));
  await tester.pumpAndSettle();
}

const _done = AppSettings(onboardingDone: true);

void main() {
  group('onboarding', () {
    testWidgets('Next walks through every page to the name page', (
      tester,
    ) async {
      await _pump(tester);
      expect(find.text('See your whole day'), findsOneWidget);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Big tasks, tiny steps'), findsOneWidget);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Focus with a buddy'), findsOneWidget);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Plan my day'), findsOneWidget);
    });

    testWidgets('Skip jumps straight to the name page', (tester) async {
      await _pump(tester);
      await _skipToNamePage(tester);
      expect(find.text('Plan my day'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('Plan my day opens the day view and saves the name', (
      tester,
    ) async {
      final h = await _pump(tester);
      await _skipToNamePage(tester);
      await tester.enterText(find.byType(TextField), '  Rahul ');
      await tester.tap(find.text('Plan my day'));
      await tester.pumpAndSettle();
      expect(find.text('Plan my day'), findsNothing);
      expect(find.textContaining('Rahul'), findsOneWidget);
      expect(h.settings.value.onboardingDone, isTrue);
      expect(h.settings.value.name, 'Rahul');
      // Saved to storage, so it survives an app restart.
      final stored = await h.settingsStore.load();
      expect(stored.onboardingDone, isTrue);
      expect(stored.name, 'Rahul');
    });

    testWidgets('works with the name left empty', (tester) async {
      final h = await _pump(tester);
      await _skipToNamePage(tester);
      await tester.tap(find.text('Plan my day'));
      await tester.pumpAndSettle();
      expect(h.settings.value.onboardingDone, isTrue);
      expect(find.text('Add'), findsOneWidget);
    });

    testWidgets('gets into the app even when notifications are broken', (
      tester,
    ) async {
      final broken = _BrokenReminders();
      final h = await _pump(tester, reminders: broken);
      await _skipToNamePage(tester);
      await tester.enterText(find.byType(TextField), 'Rahul');
      await tester.tap(find.text('Plan my day'));
      await tester.pumpAndSettle();
      expect(broken.calls, greaterThan(0));
      expect(h.settings.value.onboardingDone, isTrue);
      expect(find.text('Add'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('does not wait for the notification permission dialog', (
      tester,
    ) async {
      final h = await _pump(tester, reminders: _HangingReminders());
      await _skipToNamePage(tester);
      await tester.tap(find.text('Plan my day'));
      await tester.pumpAndSettle();
      expect(h.settings.value.onboardingDone, isTrue);
      expect(find.text('Add'), findsOneWidget);
    });

    testWidgets('returning users skip onboarding', (tester) async {
      await _pump(tester, settings: _done);
      expect(find.text('See your whole day'), findsNothing);
      expect(find.text('Add'), findsOneWidget);
    });
  });

  group('day view', () {
    testWidgets('shows anytime tasks and lets you tick them off', (
      tester,
    ) async {
      final h = await _pump(
        tester,
        settings: _done,
        tasks: [_task('a', 'Water the plants')],
      );
      await _scrollToTop(tester);
      final check = find.byTooltip('Mark as done').first;
      expect(find.text('Water the plants'), findsOneWidget);
      await tester.tap(check);
      await tester.pumpAndSettle();
      expect(h.planner.byId('a')!.done, isTrue);
      expect(find.text('1 of 1 done'), findsOneWidget);
    });

    testWidgets('opening the editor and closing it saves nothing', (
      tester,
    ) async {
      final h = await _pump(tester, settings: _done);
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Draft only');
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      if (find.text('Discard').evaluate().isNotEmpty) {
        await tester.tap(find.text('Discard'));
        await tester.pumpAndSettle();
      }
      expect(h.planner.tasksFor(h.planner.today), isEmpty);
    });

    testWidgets('a new task is saved even when reminders fail', (tester) async {
      final h = await _pump(
        tester,
        settings: _done,
        reminders: _BrokenReminders(),
      );
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Call the bank');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(h.planner.tasksFor(h.planner.today).single.title, 'Call the bank');
      expect(h.taskStore.saves, greaterThan(0));
      expect(find.text('Call the bank'), findsOneWidget);
    });

    testWidgets('the day strip switches to another day', (tester) async {
      await _pump(
        tester,
        settings: _done,
        tasks: [
          _task('t', 'Today thing'),
          _task('m', 'Tomorrow thing', day: DateTime(2026, 10, 5)),
        ],
      );
      await _scrollToTop(tester);
      expect(find.text('Today thing'), findsOneWidget);
      expect(find.text('Tomorrow thing'), findsNothing);
      // 4 Oct 2026 is a Sunday, so Monday the 5th is in next week's strip.
      await tester.tap(find.byTooltip('Next week'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('5'));
      await tester.pumpAndSettle();
      expect(find.text('Tomorrow thing'), findsOneWidget);
      expect(find.text('Today thing'), findsNothing);
    });

    testWidgets('settings opens from the menu', (tester) async {
      await _pump(tester, settings: _done);
      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Reduce motion'), findsOneWidget);
      expect(find.text('Haptics'), findsOneWidget);
    });
  });

  group('planner keeps working when reminders fail', () {
    late PlannerController planner;
    late MemoryTaskStore store;

    setUp(() async {
      store = MemoryTaskStore([
        _task('a', 'Morning', start: 9 * 60),
        _task('b', 'Later', start: 15 * 60),
      ]);
      planner = PlannerController(
        store: store,
        reminders: _BrokenReminders(),
        clock: () => _now,
      );
      await planner.load();
    });

    test('loads tasks', () {
      expect(planner.loaded, isTrue);
      expect(planner.tasksFor(planner.today).length, 2);
    });

    test('saves new tasks', () async {
      await planner.upsert(_task('c', 'New one', start: 12 * 60));
      final saved = await store.loadAll();
      expect(saved.map((t) => t.id), contains('c'));
    });

    test('deletes tasks', () async {
      await planner.delete('a');
      expect(planner.byId('a'), isNull);
      expect((await store.loadAll()).map((t) => t.id), isNot(contains('a')));
    });

    test('moves unfinished tasks to tomorrow', () async {
      final moved = await planner.moveUnfinished(
        planner.today,
        DateTime(2026, 10, 5),
      );
      expect(moved, 2);
      expect(planner.tasksFor(DateTime(2026, 10, 5)).length, 2);
    });

    test('deletes everything', () async {
      await planner.deleteEverything();
      expect(await store.loadAll(), isEmpty);
    });
  });
}
