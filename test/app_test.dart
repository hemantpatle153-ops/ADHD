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

Future<(PlannerController, SettingsController)> _pump(
  WidgetTester tester, {
  AppSettings settings = const AppSettings(),
  List<PlannerTask> tasks = const [],
}) async {
  final now = DateTime(2026, 10, 4, 10, 10);
  final planner = PlannerController(
    store: MemoryTaskStore(tasks),
    reminders: NoopReminders(),
    clock: () => now,
  );
  final s = SettingsController(MemorySettingsStore(settings));
  await s.load();
  await planner.load();
  await tester.binding.setSurfaceSize(const Size(420, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    BrightdayApp(
      planner: planner,
      settings: s,
      breakdown: SmartBreakdown(),
      reminders: NoopReminders(),
    ),
  );
  await tester.pumpAndSettle();
  return (planner, s);
}

void main() {
  testWidgets('onboarding leads to the day view', (tester) async {
    final (_, settings) = await _pump(tester);
    expect(find.text('See your whole day'), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Sam');
    await tester.tap(find.text('Plan my day'));
    await tester.pumpAndSettle();
    expect(settings.value.onboardingDone, isTrue);
    expect(find.textContaining('Sam'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
  });

  testWidgets('adds a task with offline step breakdown', (tester) async {
    final (planner, _) = await _pump(
      tester,
      settings: const AppSettings(onboardingDone: true),
    );
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Clean the kitchen');
    await tester.pump();
    await tester.ensureVisible(find.text('Break it down'));
    await tester.tap(find.text('Break it down'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Offline suggestions'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final task = planner.tasksFor(planner.today).single;
    expect(task.title, 'Clean the kitchen');
    expect(task.emoji, '🧹');
    expect(task.steps, isNotEmpty);
    expect(find.text('Clean the kitchen'), findsOneWidget);
  });

  testWidgets('shows the current task and opens focus mode', (tester) async {
    final (planner, _) = await _pump(
      tester,
      settings: const AppSettings(onboardingDone: true),
      tasks: [
        PlannerTask(
          id: 'a',
          title: 'Answer emails',
          emoji: '📧',
          day: DateTime(2026, 10, 4),
          startMinute: 10 * 60,
          durationMinutes: 30,
          steps: const [TaskStep(id: '1', title: 'Open the inbox')],
          createdAt: DateTime(2026, 10, 1),
        ),
      ],
    );
    // The day view auto-scrolls to the now line; scroll back up.
    await tester.scrollUntilVisible(find.text('NOW'), -300);
    expect(find.text('NOW'), findsOneWidget);
    expect(find.text('20 min left'), findsOneWidget);
    await tester.tap(find.text('Focus'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('STEP 1 OF 1'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(planner.byId('a')!.done, isTrue);
    // Leave focus mode so its timer is disposed.
    await tester.tap(find.byTooltip('End session'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('End'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Answer emails'), findsWidgets);
  });
}
