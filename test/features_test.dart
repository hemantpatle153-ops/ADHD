// One test per feature a user can reach from the day view, driven through the
// real UI: task details, steps, editing, moving, copying, deleting with undo,
// focus mode and settings.
import 'package:brightday/models/settings.dart';
import 'package:brightday/models/task.dart';
import 'package:brightday/ui/focus/focus_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

final _tomorrow = DateTime(2026, 10, 5);

PlannerTask _withSteps(String id, String title, {int? start}) => PlannerTask(
  id: id,
  title: title,
  day: DateTime(2026, 10, 4),
  startMinute: start,
  durationMinutes: 30,
  steps: const [
    TaskStep(id: 's1', title: 'Open the laptop'),
    TaskStep(id: 's2', title: 'Write one line'),
  ],
  createdAt: DateTime(2026, 10, 1),
);

Future<void> _openTask(WidgetTester tester, String title) async {
  await scrollToTop(tester);
  await tester.tap(find.text(title).first);
  await tester.pumpAndSettle();
}

Future<void> _detailMenu(WidgetTester tester, String item) async {
  await tester.tap(find.byTooltip('More').last);
  await tester.pumpAndSettle();
  await tester.tap(find.text(item));
  await tester.pumpAndSettle();
}

void main() {
  group('task details', () {
    testWidgets('ticking every step finishes the task', (tester) async {
      final h = await pumpApp(
        tester,
        settings: onboarded,
        tasks: [_withSteps('a', 'Write report')],
      );
      await _openTask(tester, 'Write report');
      await tester.tap(find.text('Open the laptop'));
      await tester.pumpAndSettle();
      expect(h.planner.byId('a')!.steps.first.done, isTrue);
      expect(h.planner.byId('a')!.done, isFalse);
      await tester.tap(find.text('Write one line'));
      await tester.pumpAndSettle();
      expect(h.planner.byId('a')!.done, isTrue);
    });

    testWidgets('move to tomorrow', (tester) async {
      final h = await pumpApp(
        tester,
        settings: onboarded,
        tasks: [makeTask('a', 'Pay rent')],
      );
      await _openTask(tester, 'Pay rent');
      await _detailMenu(tester, 'Move to tomorrow');
      expect(h.planner.byId('a')!.day, _tomorrow);
      expect(
        find.text('Moved to tomorrow. Future-you has it.'),
        findsOneWidget,
      );
    });

    testWidgets('copy to tomorrow keeps the original', (tester) async {
      final h = await pumpApp(
        tester,
        settings: onboarded,
        tasks: [makeTask('a', 'Stretch')],
      );
      await _openTask(tester, 'Stretch');
      await _detailMenu(tester, 'Copy to tomorrow');
      expect(h.planner.byId('a')!.day, DateTime(2026, 10, 4));
      expect(h.planner.tasksFor(_tomorrow).single.title, 'Stretch');
    });

    testWidgets('delete, then undo brings it back', (tester) async {
      final h = await pumpApp(
        tester,
        settings: onboarded,
        tasks: [makeTask('a', 'Call mum')],
      );
      await _openTask(tester, 'Call mum');
      await _detailMenu(tester, 'Delete');
      expect(h.planner.byId('a'), isNull);
      expect(find.text('Deleted "Call mum"'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(h.planner.byId('a')?.title, 'Call mum');
    });

    testWidgets('edit renames the task', (tester) async {
      final h = await pumpApp(
        tester,
        settings: onboarded,
        tasks: [makeTask('a', 'Groceries')],
      );
      await _openTask(tester, 'Groceries');
      await tester.tap(find.byTooltip('Edit'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Big shop');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(h.planner.byId('a')!.title, 'Big shop');
    });
  });

  group('task editor', () {
    testWidgets('will not save or break down a task without a name', (
      tester,
    ) async {
      final h = await pumpApp(tester, settings: onboarded);
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      final save = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('Save'),
          matching: find.byType(FilledButton),
        ),
      );
      expect(save.onPressed, isNull);
      await tester.ensureVisible(find.text('Break it down'));
      await tester.tap(find.text('Break it down'));
      await tester.pump();
      expect(find.text('Give the task a name first.'), findsOneWidget);
      expect(h.planner.tasksFor(h.planner.today), isEmpty);
    });

    testWidgets('a step can be added by hand', (tester) async {
      final h = await pumpApp(tester, settings: onboarded);
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Tidy desk');
      await tester.ensureVisible(find.text('Add a step'));
      await tester.tap(find.text('Add a step'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(1), 'Clear the cups');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      final task = h.planner.tasksFor(h.planner.today).single;
      expect(task.steps.map((s) => s.title), contains('Clear the cups'));
    });

    testWidgets('deleting from the editor removes the task', (tester) async {
      final h = await pumpApp(
        tester,
        settings: onboarded,
        tasks: [makeTask('a', 'Old idea')],
      );
      await _openTask(tester, 'Old idea');
      await tester.tap(find.byTooltip('Edit'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Delete'));
      await tester.pumpAndSettle();
      expect(h.planner.byId('a'), isNull);
    });
  });

  group('day view menu', () {
    testWidgets('moves unfinished tasks to tomorrow', (tester) async {
      final h = await pumpApp(
        tester,
        settings: onboarded,
        tasks: [
          makeTask('a', 'Unfinished'),
          makeTask('b', 'Finished', done: true),
        ],
      );
      await tester.tap(find.byTooltip('More').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Move unfinished to tomorrow'));
      await tester.pumpAndSettle();
      expect(h.planner.byId('a')!.day, _tomorrow);
      expect(h.planner.byId('b')!.day, DateTime(2026, 10, 4));
    });
  });

  group('focus mode', () {
    testWidgets('pause, add time, tick steps and end the session', (
      tester,
    ) async {
      final h = await pumpApp(
        tester,
        settings: onboarded,
        tasks: [_withSteps('a', 'Write report', start: 10 * 60)],
      );
      await _openTask(tester, 'Write report');
      await tester.tap(find.text('Start focus'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(FocusScreen), findsOneWidget);
      expect(find.text('STEP 1 OF 2'), findsOneWidget);

      await tester.tap(find.text('Pause'));
      await tester.pump();
      expect(find.text('paused'), findsOneWidget);
      expect(find.text('Resume'), findsOneWidget);

      await tester.tap(find.text('5 min'));
      await tester.pump();
      expect(find.textContaining(RegExp(r'^3[45]:')), findsOneWidget);

      await tester.tap(find.text('Resume'));
      await tester.pump();
      expect(find.text('Pause'), findsOneWidget);

      await tester.tap(find.text('Done'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('STEP 2 OF 2'), findsOneWidget);
      await tester.tap(find.text('Done'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(h.planner.byId('a')!.done, isTrue);

      await tester.tap(find.byTooltip('End session'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('End'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(FocusScreen), findsNothing);
    });

    testWidgets('Keep going stays in the session', (tester) async {
      await pumpApp(
        tester,
        settings: onboarded,
        tasks: [makeTask('a', 'Read', start: 10 * 60)],
      );
      await _openTask(tester, 'Read');
      await tester.tap(find.text('Start focus'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.byTooltip('End session'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Keep going'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(FocusScreen), findsOneWidget);
      // Leave so the timer is disposed.
      await tester.tap(find.byTooltip('End session'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('End'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    });
  });

  group('settings', () {
    Future<void> openSettings(WidgetTester tester) async {
      await tester.tap(find.byTooltip('More').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
    }

    testWidgets('theme, motion and haptics switches are saved', (tester) async {
      final h = await pumpApp(tester, settings: onboarded);
      await openSettings(tester);
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      expect(h.settings.value.themeMode, ThemeMode.dark);
      await tester.tap(find.text('Reduce motion'));
      await tester.pumpAndSettle();
      expect(h.settings.value.reduceMotion, isTrue);
      await tester.tap(find.text('Haptics'));
      await tester.pumpAndSettle();
      expect(h.settings.value.haptics, isFalse);
      final stored = await h.settingsStore.load();
      expect(stored.themeMode, ThemeMode.dark);
      expect(stored.reduceMotion, isTrue);
    });

    testWidgets('changing your name updates the greeting', (tester) async {
      final h = await pumpApp(
        tester,
        settings: const AppSettings(onboardingDone: true, name: 'Sam'),
      );
      await openSettings(tester);
      await tester.tap(find.text('Your name'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Rahul');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(h.settings.value.name, 'Rahul');
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.textContaining('Rahul'), findsOneWidget);
    });

    testWidgets('delete all my data clears every task', (tester) async {
      final h = await pumpApp(
        tester,
        settings: onboarded,
        tasks: [makeTask('a', 'One'), makeTask('b', 'Two')],
      );
      await openSettings(tester);
      await tester.scrollUntilVisible(find.text('Delete all my data'), 200);
      await tester.tap(find.text('Delete all my data'));
      await tester.pumpAndSettle();
      expect(find.text('Delete everything?'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(h.planner.tasksFor(h.planner.today), isEmpty);
      expect(await h.taskStore.loadAll(), isEmpty);
    });
  });
}
