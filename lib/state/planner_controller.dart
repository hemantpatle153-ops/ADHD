import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../data/task_store.dart';
import '../models/task.dart';
import '../services/notification_service.dart';

typedef Clock = DateTime Function();

/// Owns every task and keeps storage and reminders in step with it.
class PlannerController extends ChangeNotifier {
  PlannerController({
    required this._store,
    required this._reminders,
    Clock? clock,
  }) : _clock = clock ?? DateTime.now {
    _selectedDay = dateOnly(_clock());
  }

  final TaskStore _store;
  final Reminders _reminders;
  final Clock _clock;
  static const _uuid = Uuid();

  final Map<String, PlannerTask> _tasks = {};
  late DateTime _selectedDay;
  bool _loaded = false;

  bool get loaded => _loaded;
  DateTime get selectedDay => _selectedDay;
  DateTime now() => _clock();
  DateTime get today => dateOnly(_clock());

  Future<void> load() async {
    final all = await _store.loadAll();
    _tasks
      ..clear()
      ..addEntries(all.map((t) => MapEntry(t.id, t)));
    _loaded = true;
    notifyListeners();
    // Re-arm reminders in case the OS dropped them (app update, restore).
    for (final t in upcomingWithReminders()) {
      unawaited(_remind(() => _reminders.syncTask(t)));
    }
  }

  void selectDay(DateTime day) {
    _selectedDay = dateOnly(day);
    notifyListeners();
  }

  PlannerTask? byId(String id) => _tasks[id];

  List<PlannerTask> tasksFor(DateTime day) =>
      _tasks.values.where((t) => isSameDay(t.day, day)).toList()
        ..sort(_compare);

  List<PlannerTask> scheduledFor(DateTime day) =>
      tasksFor(day).where((t) => t.isScheduled).toList();

  List<PlannerTask> anytimeFor(DateTime day) =>
      tasksFor(day).where((t) => !t.isScheduled).toList();

  List<PlannerTask> upcomingWithReminders() {
    final now = _clock();
    return _tasks.values
        .where(
          (t) =>
              !t.done &&
              t.reminderLeadMinutes != null &&
              (t.startsAt?.isAfter(now) ?? false),
        )
        .toList();
  }

  /// Share of today's tasks that are done, 0..1.
  double progressFor(DateTime day) {
    final list = tasksFor(day);
    if (list.isEmpty) return 0;
    return list.where((t) => t.done).length / list.length;
  }

  /// The task happening right now on [day], if any.
  PlannerTask? currentTask() {
    final now = _clock();
    for (final t in scheduledFor(today)) {
      if (t.done) continue;
      if (!t.startsAt!.isAfter(now) && t.endsAt!.isAfter(now)) return t;
    }
    return null;
  }

  /// The next unfinished scheduled task that hasn't started yet today.
  PlannerTask? nextTask() {
    final now = _clock();
    for (final t in scheduledFor(today)) {
      if (!t.done && t.startsAt!.isAfter(now)) return t;
    }
    return null;
  }

  int _compare(PlannerTask a, PlannerTask b) {
    final sa = a.startMinute, sb = b.startMinute;
    if (sa != null && sb != null && sa != sb) return sa.compareTo(sb);
    if (sa == null && sb != null) return 1;
    if (sa != null && sb == null) return -1;
    return a.createdAt.compareTo(b.createdAt);
  }

  PlannerTask newDraft({DateTime? day, int? startMinute, int? reminderLead}) {
    return PlannerTask(
      id: _uuid.v4(),
      title: '',
      day: dateOnly(day ?? _selectedDay),
      startMinute: startMinute,
      reminderLeadMinutes: startMinute == null ? null : reminderLead,
      createdAt: _clock(),
    );
  }

  String newStepId() => _uuid.v4();

  Future<void> upsert(PlannerTask task) async {
    _tasks[task.id] = task;
    notifyListeners();
    await _persist();
    await _remind(() => _reminders.syncTask(task));
  }

  Future<void> delete(String id) async {
    if (_tasks.remove(id) == null) return;
    notifyListeners();
    await _persist();
    await _remind(() => _reminders.cancelTask(id));
  }

  /// Puts a deleted task back (for "Undo").
  Future<void> restore(PlannerTask task) => upsert(task);

  Future<void> toggleDone(String id) async {
    final t = _tasks[id];
    if (t == null) return;
    final done = !t.done;
    await upsert(
      t.copyWith(
        done: done,
        completedAt: () => done ? _clock() : null,
        // Finishing a task ticks off its steps too; reopening leaves them.
        steps: done ? [for (final s in t.steps) s.copyWith(done: true)] : null,
      ),
    );
  }

  Future<void> toggleStep(String taskId, String stepId) async {
    final t = _tasks[taskId];
    if (t == null) return;
    final steps = [
      for (final s in t.steps) s.id == stepId ? s.copyWith(done: !s.done) : s,
    ];
    final allDone = steps.isNotEmpty && steps.every((s) => s.done);
    await upsert(
      t.copyWith(
        steps: steps,
        done: allDone,
        completedAt: () => allDone ? (t.completedAt ?? _clock()) : null,
      ),
    );
  }

  /// Copies a task to another day as a fresh, unfinished task.
  Future<PlannerTask> duplicateTo(String id, DateTime day) async {
    final t = _tasks[id]!;
    final copy = PlannerTask(
      id: _uuid.v4(),
      title: t.title,
      emoji: t.emoji,
      colorIndex: t.colorIndex,
      day: dateOnly(day),
      startMinute: t.startMinute,
      durationMinutes: t.durationMinutes,
      reminderLeadMinutes: t.reminderLeadMinutes,
      steps: [
        for (final s in t.steps) TaskStep(id: _uuid.v4(), title: s.title),
      ],
      notes: t.notes,
      createdAt: _clock(),
    );
    await upsert(copy);
    return copy;
  }

  /// Moves every unfinished task from [from] to [to], keeping their times.
  /// No guilt, no red overdue list: unfinished work just rolls forward.
  Future<int> moveUnfinished(DateTime from, DateTime to) async {
    final target = dateOnly(to);
    final moving = tasksFor(from).where((t) => !t.done).toList();
    for (final t in moving) {
      final moved = t.copyWith(day: target);
      _tasks[t.id] = moved;
    }
    if (moving.isNotEmpty) {
      notifyListeners();
      await _persist();
    }
    for (final t in moving) {
      await _remind(() => _reminders.syncTask(_tasks[t.id]!));
    }
    return moving.length;
  }

  int unfinishedCount(DateTime day) =>
      tasksFor(day).where((t) => !t.done).length;

  Future<void> deleteEverything() async {
    final ids = _tasks.keys.toList();
    _tasks.clear();
    notifyListeners();
    await _persist();
    for (final id in ids) {
      await _remind(() => _reminders.cancelTask(id));
    }
  }

  Future<void> _persist() => _store.saveAll(_tasks.values.toList());

  /// Tasks are saved before reminders are touched, and a reminder failure is
  /// logged rather than surfaced: losing a heads-up beats losing a task.
  Future<void> _remind(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      debugPrint('Reminder update failed: $e');
    }
  }

  /// JSON export of every task, for the user's own records.
  List<Map<String, Object?>> exportJson() =>
      _tasks.values.map((t) => t.toJson()).toList();
}
