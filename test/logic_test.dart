import 'dart:convert';
import 'dart:io';

import 'package:brightday/data/task_store.dart';
import 'package:brightday/models/task.dart';
import 'package:brightday/services/breakdown_service.dart';
import 'package:brightday/services/notification_service.dart';
import 'package:brightday/state/focus_session.dart';
import 'package:brightday/state/planner_controller.dart';
import 'package:brightday/ui/focus/companion.dart';
import 'package:brightday/util/timeline_layout.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _RecordingReminders extends NoopReminders {
  final synced = <String>[];
  final cancelled = <String>[];

  @override
  Future<void> syncTask(PlannerTask task) async => synced.add(task.id);

  @override
  Future<void> cancelTask(String taskId) async => cancelled.add(taskId);
}

PlannerTask _task(
  String id, {
  int? start,
  int duration = 30,
  DateTime? day,
  List<TaskStep> steps = const [],
  bool done = false,
}) => PlannerTask(
  id: id,
  title: 'Task $id',
  day: day ?? DateTime(2026, 10, 4),
  startMinute: start,
  durationMinutes: duration,
  steps: steps,
  done: done,
  createdAt: DateTime(2026, 10, 1),
);

void main() {
  group('PlannerTask', () {
    test('round-trips through JSON', () {
      final t = PlannerTask(
        id: 'a',
        title: 'Write essay',
        emoji: '📝',
        colorIndex: 3,
        day: DateTime(2026, 10, 4),
        startMinute: 9 * 60 + 30,
        durationMinutes: 45,
        reminderLeadMinutes: 10,
        steps: const [
          TaskStep(id: 's1', title: 'Outline', done: true),
          TaskStep(id: 's2', title: 'Draft'),
        ],
        notes: 'due Friday',
        createdAt: DateTime(2026, 10, 1, 8),
      );
      final back = PlannerTask.fromJson(
        jsonDecode(jsonEncode(t.toJson())) as Map<String, Object?>,
      );
      expect(back.toJson(), t.toJson());
      expect(back.startsAt, DateTime(2026, 10, 4, 9, 30));
      expect(back.endsAt, DateTime(2026, 10, 4, 10, 15));
      expect(back.progress, 0.5);
      expect(back.nextStep?.id, 's2');
    });

    test('copyWith can clear nullable fields', () {
      final t = _task('a', start: 600).copyWith(startMinute: () => null);
      expect(t.isScheduled, isFalse);
    });
  });

  group('PlannerController', () {
    late MemoryTaskStore store;
    late _RecordingReminders reminders;
    late PlannerController planner;
    var now = DateTime(2026, 10, 4, 10, 10);

    setUp(() async {
      now = DateTime(2026, 10, 4, 10, 10);
      store = MemoryTaskStore([
        _task('early', start: 9 * 60, duration: 30),
        _task('current', start: 10 * 60, duration: 30),
        _task('later', start: 14 * 60),
        _task('anytime'),
        _task('tomorrow', start: 9 * 60, day: DateTime(2026, 10, 5)),
      ]);
      reminders = _RecordingReminders();
      planner = PlannerController(
        store: store,
        reminders: reminders,
        clock: () => now,
      );
      await planner.load();
    });

    test('sorts scheduled tasks first, by time', () {
      expect(planner.tasksFor(planner.today).map((t) => t.id), [
        'early',
        'current',
        'later',
        'anytime',
      ]);
      expect(planner.anytimeFor(planner.today).single.id, 'anytime');
    });

    test('knows what is happening now and next', () {
      expect(planner.currentTask()?.id, 'current');
      expect(planner.nextTask()?.id, 'later');
      now = DateTime(2026, 10, 4, 10, 45);
      expect(planner.currentTask(), isNull);
    });

    test('finishing every step finishes the task', () async {
      await planner.upsert(
        _task(
          's',
          steps: const [
            TaskStep(id: '1', title: 'one'),
            TaskStep(id: '2', title: 'two'),
          ],
        ),
      );
      await planner.toggleStep('s', '1');
      expect(planner.byId('s')!.done, isFalse);
      await planner.toggleStep('s', '2');
      expect(planner.byId('s')!.done, isTrue);
      expect(planner.byId('s')!.completedAt, now);
      await planner.toggleStep('s', '2');
      expect(planner.byId('s')!.done, isFalse);
    });

    test('toggling done ticks every step and persists', () async {
      await planner.upsert(
        _task(
          's',
          steps: const [TaskStep(id: '1', title: 'one')],
        ),
      );
      final saves = store.saves;
      await planner.toggleDone('s');
      expect(planner.byId('s')!.steps.single.done, isTrue);
      expect(store.saves, greaterThan(saves));
      expect((await store.loadAll()).firstWhere((t) => t.id == 's').done, true);
    });

    test('moves unfinished work to another day', () async {
      await planner.toggleDone('early');
      final moved = await planner.moveUnfinished(
        planner.today,
        DateTime(2026, 10, 5),
      );
      expect(moved, 3);
      expect(planner.tasksFor(planner.today).single.id, 'early');
      expect(planner.tasksFor(DateTime(2026, 10, 5)).length, 4);
    });

    test('duplicates a task with fresh ids', () async {
      await planner.upsert(
        _task(
          's',
          steps: const [TaskStep(id: '1', title: 'one', done: true)],
        ),
      );
      final copy = await planner.duplicateTo('s', DateTime(2026, 10, 6));
      expect(copy.id, isNot('s'));
      expect(copy.steps.single.id, isNot('1'));
      expect(copy.steps.single.done, isFalse);
    });

    test('deleting cancels the reminder', () async {
      await planner.delete('later');
      expect(planner.byId('later'), isNull);
      expect(reminders.cancelled, contains('later'));
    });

    test('progress counts done tasks', () async {
      await planner.toggleDone('early');
      expect(planner.progressFor(planner.today), 0.25);
    });
  });

  group('JsonFileTaskStore', () {
    test('writes and reads back atomically', () async {
      final dir = await Directory.systemTemp.createTemp('brightday');
      addTearDown(() => dir.delete(recursive: true));
      final store = JsonFileTaskStore(dir);
      expect(await store.loadAll(), isEmpty);
      await store.saveAll([_task('a', start: 60), _task('b')]);
      final loaded = await JsonFileTaskStore(dir).loadAll();
      expect(loaded.map((t) => t.id), ['a', 'b']);
      expect(File('${dir.path}/tasks.json.tmp').existsSync(), isFalse);
    });

    test('keeps a corrupt file aside instead of losing it', () async {
      final dir = await Directory.systemTemp.createTemp('brightday');
      addTearDown(() => dir.delete(recursive: true));
      await File('${dir.path}/tasks.json').writeAsString('{not json');
      expect(await JsonFileTaskStore(dir).loadAll(), isEmpty);
      expect(
        dir.listSync().any((f) => f.path.contains('tasks.corrupt-')),
        isTrue,
      );
    });
  });

  group('layoutLanes', () {
    test('puts overlapping tasks side by side', () {
      final slots = layoutLanes([
        _task('a', start: 540, duration: 60),
        _task('b', start: 570, duration: 30),
        _task('c', start: 720, duration: 30),
      ]);
      final byId = {for (final s in slots) s.task.id: s};
      expect(byId['a']!.lanes, 2);
      expect(byId['b']!.lane, 1);
      expect(byId['c']!.lanes, 1);
    });

    test('reuses a lane once it is free', () {
      final slots = layoutLanes([
        _task('a', start: 540, duration: 120),
        _task('b', start: 540, duration: 30),
        _task('c', start: 600, duration: 30),
      ]);
      final byId = {for (final s in slots) s.task.id: s};
      expect(byId['c']!.lane, 1);
      expect(byId.values.every((s) => s.lanes == 2), isTrue);
    });
  });

  group('FocusSession', () {
    test('counts down, pauses and extends', () {
      var now = DateTime(2026, 1, 1, 9);
      final s = FocusSession(
        length: const Duration(minutes: 25),
        clock: () => now,
      );
      now = now.add(const Duration(minutes: 10));
      expect(s.remaining, const Duration(minutes: 15));
      s.pause();
      now = now.add(const Duration(minutes: 30));
      expect(s.remaining, const Duration(minutes: 15));
      s.resume();
      now = now.add(const Duration(minutes: 5));
      expect(s.remaining, const Duration(minutes: 10));
      s.extend(const Duration(minutes: 5));
      expect(s.remaining, const Duration(minutes: 15));
      now = now.add(const Duration(minutes: 20));
      expect(s.isFinished, isTrue);
      expect(s.progress, 1);
      s.extend(const Duration(minutes: 10));
      expect(s.remaining, const Duration(minutes: 10));
    });
  });

  group('companionLine', () {
    String at(int minutes, {int length = 30, bool paused = false}) =>
        companionLine(
          elapsed: Duration(minutes: minutes),
          length: Duration(minutes: length),
          checkInMinutes: 10,
          paused: paused,
        );

    test('marks milestones', () {
      expect(at(0), contains('first tiny step'));
      expect(at(15), contains('Halfway'));
      expect(at(29), contains('Almost there'));
      expect(at(30), contains('You showed up'));
      expect(at(5, paused: true), contains('pause'));
    });

    test('rotates check-ins', () {
      expect(at(5), isNot(at(12)));
    });
  });

  group('breakdown', () {
    test('offline picks a matching template', () async {
      final r = await const OfflineBreakdown().breakDown('Clean my room');
      expect(r.source, BreakdownSource.offline);
      expect(r.steps.first.title, contains('song'));
    });

    test('offline falls back to a generic plan using the task name', () async {
      final r = await const OfflineBreakdown().breakDown('Renew passport');
      expect(r.steps.any((s) => s.title.contains('Renew passport')), isTrue);
      expect(r.totalMinutes, greaterThan(0));
    });

    test('remote parses steps and sends the app token', () async {
      late http.Request seen;
      final client = MockClient((req) async {
        seen = req;
        return http.Response(
          jsonEncode({
            'steps': [
              {'title': 'Open the doc', 'minutes': 2},
              {'title': '  ', 'minutes': 3},
              {'title': 'Write intro', 'minutes': 500},
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final r = await RemoteBreakdown(
        endpoint: Uri.parse('https://example.test/breakdown'),
        appToken: 'tok',
        client: client,
      ).breakDown('Write essay');
      expect(seen.headers['x-app-token'], 'tok');
      expect(jsonDecode(seen.body), {'task': 'Write essay'});
      expect(r.source, BreakdownSource.ai);
      expect(r.steps.map((s) => s.title), ['Open the doc', 'Write intro']);
      expect(r.steps.last.minutes, 120);
    });

    test('smart breakdown falls back offline when the server fails', () async {
      final smart = SmartBreakdown(
        remote: RemoteBreakdown(
          endpoint: Uri.parse('https://example.test/breakdown'),
          client: MockClient((_) async => http.Response('nope', 500)),
        ),
      );
      final r = await smart.breakDown('Do laundry');
      expect(r.source, BreakdownSource.offline);
    });

    test('smart breakdown skips the network when AI is turned off', () async {
      var calls = 0;
      final smart = SmartBreakdown(
        remote: RemoteBreakdown(
          endpoint: Uri.parse('https://example.test/breakdown'),
          client: MockClient((_) async {
            calls++;
            return http.Response('{}', 200);
          }),
        ),
      )..aiAllowed = false;
      await smart.breakDown('Do laundry');
      expect(calls, 0);
    });
  });
}
