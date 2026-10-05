// End-to-end style widget tests for the flows a new user hits first. They use
// in-memory stores and fake reminders, so they run on any machine and in CI.
import 'package:brightday/data/task_store.dart';
import 'package:brightday/state/planner_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

void main() {
  group('onboarding', () {
    testWidgets('Next walks through every page to the name page', (
      tester,
    ) async {
      await pumpApp(tester);
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
      await pumpApp(tester);
      await skipToNamePage(tester);
      expect(find.text('Plan my day'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('Plan my day opens the day view and saves the name', (
      tester,
    ) async {
      final h = await pumpApp(tester);
      await skipToNamePage(tester);
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
      final h = await pumpApp(tester);
      await skipToNamePage(tester);
      await tester.tap(find.text('Plan my day'));
      await tester.pumpAndSettle();
      expect(h.settings.value.onboardingDone, isTrue);
      expect(find.text('Add'), findsOneWidget);
    });

    testWidgets('gets into the app even when notifications are broken', (
      tester,
    ) async {
      final broken = BrokenReminders();
      final h = await pumpApp(tester, reminders: broken);
      await skipToNamePage(tester);
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
      final h = await pumpApp(tester, reminders: HangingReminders());
      await skipToNamePage(tester);
      await tester.tap(find.text('Plan my day'));
      await tester.pumpAndSettle();
      expect(h.settings.value.onboardingDone, isTrue);
      expect(find.text('Add'), findsOneWidget);
    });

    testWidgets('returning users skip onboarding', (tester) async {
      await pumpApp(tester, settings: onboarded);
      expect(find.text('See your whole day'), findsNothing);
      expect(find.text('Add'), findsOneWidget);
    });
  });

  group('day view', () {
    testWidgets('shows anytime tasks and lets you tick them off', (
      tester,
    ) async {
      final h = await pumpApp(
        tester,
        settings: onboarded,
        tasks: [makeTask('a', 'Water the plants')],
      );
      await scrollToTop(tester);
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
      final h = await pumpApp(tester, settings: onboarded);
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
      final h = await pumpApp(
        tester,
        settings: onboarded,
        reminders: BrokenReminders(),
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
      await pumpApp(
        tester,
        settings: onboarded,
        tasks: [
          makeTask('t', 'Today thing'),
          makeTask('m', 'Tomorrow thing', day: DateTime(2026, 10, 5)),
        ],
      );
      await scrollToTop(tester);
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
      await pumpApp(tester, settings: onboarded);
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
        makeTask('a', 'Morning', start: 9 * 60),
        makeTask('b', 'Later', start: 15 * 60),
      ]);
      planner = PlannerController(
        store: store,
        reminders: BrokenReminders(),
        clock: () => testNow,
      );
      await planner.load();
    });

    test('loads tasks', () {
      expect(planner.loaded, isTrue);
      expect(planner.tasksFor(planner.today).length, 2);
    });

    test('saves new tasks', () async {
      await planner.upsert(makeTask('c', 'New one', start: 12 * 60));
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
