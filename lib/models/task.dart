import 'package:flutter/foundation.dart';

/// One small, concrete step inside a task.
@immutable
class TaskStep {
  const TaskStep({required this.id, required this.title, this.done = false});

  final String id;
  final String title;
  final bool done;

  TaskStep copyWith({String? title, bool? done}) =>
      TaskStep(id: id, title: title ?? this.title, done: done ?? this.done);

  Map<String, Object?> toJson() => {'id': id, 'title': title, 'done': done};

  factory TaskStep.fromJson(Map<String, Object?> json) => TaskStep(
    id: json['id'] as String,
    title: json['title'] as String? ?? '',
    done: json['done'] as bool? ?? false,
  );

  @override
  bool operator ==(Object other) =>
      other is TaskStep &&
      other.id == id &&
      other.title == title &&
      other.done == done;

  @override
  int get hashCode => Object.hash(id, title, done);
}

/// A block on the day's timeline (or an "anytime" task when [startMinute]
/// is null).
@immutable
class PlannerTask {
  const PlannerTask({
    required this.id,
    required this.title,
    required this.day,
    required this.createdAt,
    this.emoji = '✨',
    this.colorIndex = 0,
    this.startMinute,
    this.durationMinutes = 25,
    this.reminderLeadMinutes,
    this.steps = const [],
    this.notes = '',
    this.done = false,
    this.completedAt,
  });

  final String id;
  final String title;
  final String emoji;
  final int colorIndex;

  /// Calendar day this task belongs to, normalised to local midnight.
  final DateTime day;

  /// Minutes after midnight. Null means "anytime today".
  final int? startMinute;
  final int durationMinutes;

  /// Minutes before [startMinute] to send a reminder. Null means no reminder.
  final int? reminderLeadMinutes;
  final List<TaskStep> steps;
  final String notes;
  final bool done;
  final DateTime? completedAt;
  final DateTime createdAt;

  bool get isScheduled => startMinute != null;

  int? get endMinute =>
      startMinute == null ? null : startMinute! + durationMinutes;

  DateTime? get startsAt => startMinute == null
      ? null
      : DateTime(
          day.year,
          day.month,
          day.day,
        ).add(Duration(minutes: startMinute!));

  DateTime? get endsAt => startsAt?.add(Duration(minutes: durationMinutes));

  int get completedSteps => steps.where((s) => s.done).length;

  /// Progress 0..1, counting steps when there are any.
  double get progress {
    if (done) return 1;
    if (steps.isEmpty) return 0;
    return completedSteps / steps.length;
  }

  TaskStep? get nextStep {
    for (final s in steps) {
      if (!s.done) return s;
    }
    return null;
  }

  PlannerTask copyWith({
    String? title,
    String? emoji,
    int? colorIndex,
    DateTime? day,
    int? Function()? startMinute,
    int? durationMinutes,
    int? Function()? reminderLeadMinutes,
    List<TaskStep>? steps,
    String? notes,
    bool? done,
    DateTime? Function()? completedAt,
  }) {
    return PlannerTask(
      id: id,
      title: title ?? this.title,
      emoji: emoji ?? this.emoji,
      colorIndex: colorIndex ?? this.colorIndex,
      day: day ?? this.day,
      startMinute: startMinute != null ? startMinute() : this.startMinute,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      reminderLeadMinutes: reminderLeadMinutes != null
          ? reminderLeadMinutes()
          : this.reminderLeadMinutes,
      steps: steps ?? this.steps,
      notes: notes ?? this.notes,
      done: done ?? this.done,
      completedAt: completedAt != null ? completedAt() : this.completedAt,
      createdAt: createdAt,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'emoji': emoji,
    'colorIndex': colorIndex,
    'day': dayKey(day),
    'startMinute': startMinute,
    'durationMinutes': durationMinutes,
    'reminderLeadMinutes': reminderLeadMinutes,
    'steps': steps.map((s) => s.toJson()).toList(),
    'notes': notes,
    'done': done,
    'completedAt': completedAt?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
  };

  factory PlannerTask.fromJson(Map<String, Object?> json) => PlannerTask(
    id: json['id'] as String,
    title: json['title'] as String? ?? '',
    emoji: json['emoji'] as String? ?? '✨',
    colorIndex: (json['colorIndex'] as num?)?.toInt() ?? 0,
    day: parseDayKey(json['day'] as String),
    startMinute: (json['startMinute'] as num?)?.toInt(),
    durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 25,
    reminderLeadMinutes: (json['reminderLeadMinutes'] as num?)?.toInt(),
    steps: ((json['steps'] as List?) ?? const [])
        .map((e) => TaskStep.fromJson((e as Map).cast<String, Object?>()))
        .toList(),
    notes: json['notes'] as String? ?? '',
    done: json['done'] as bool? ?? false,
    completedAt: json['completedAt'] == null
        ? null
        : DateTime.parse(json['completedAt'] as String),
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}

/// Local-midnight date for [d].
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

DateTime parseDayKey(String key) {
  final parts = key.split('-').map(int.parse).toList();
  return DateTime(parts[0], parts[1], parts[2]);
}

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
