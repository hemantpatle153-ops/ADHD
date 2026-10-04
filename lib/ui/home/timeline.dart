import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/task.dart';
import '../../theme/app_theme.dart';
import '../../util/time_format.dart';
import '../../util/timeline_layout.dart';

/// The visual day: hour rows with task blocks whose height is their length.
class DayTimeline extends StatelessWidget {
  const DayTimeline({
    super.key,
    required this.tasks,
    required this.startHour,
    required this.endHour,
    required this.onTapTask,
    required this.onToggleDone,
    required this.onTapEmpty,
    this.now,
    this.nowKey,
    this.hourHeight = 76,
  });

  final List<PlannerTask> tasks;
  final int startHour;
  final int endHour;

  /// Set only when the timeline shows today.
  final DateTime? now;

  /// Attached to the "now" line so the screen can scroll to it.
  final Key? nowKey;
  final double hourHeight;
  final ValueChanged<PlannerTask> onTapTask;
  final ValueChanged<PlannerTask> onToggleDone;

  /// Called with a minute-of-day rounded to 15 minutes.
  final ValueChanged<int> onTapEmpty;

  static const _gutter = 60.0;
  static const _minBlockHeight = 48.0;

  /// Expands the visible range so no task is ever hidden.
  (int, int) _range() {
    var start = startHour, end = endHour;
    for (final t in tasks) {
      start = math.min(start, t.startMinute! ~/ 60);
      end = math.max(end, (t.endMinute! / 60).ceil());
    }
    if (now != null) {
      start = math.min(start, now!.hour);
      end = math.max(end, now!.hour + 1);
    }
    return (start.clamp(0, 23), end.clamp(start + 1, 24));
  }

  @override
  Widget build(BuildContext context) {
    final (start, end) = _range();
    final hours = end - start;
    final height = hours * hourHeight;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final minBlockMinutes = (_minBlockHeight / hourHeight * 60).ceil();
    final slots = layoutLanes(tasks, minBlockMinutes: minBlockMinutes);

    double yFor(int minute) => (minute - start * 60) / 60 * hourHeight;

    return LayoutBuilder(
      builder: (context, constraints) {
        final laneArea = constraints.maxWidth - _gutter - 16;
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapUp: (d) {
            if (d.localPosition.dx < _gutter) return;
            final minute = start * 60 + (d.localPosition.dy / hourHeight * 60);
            onTapEmpty(((minute / 15).floor() * 15).clamp(0, 24 * 60 - 15));
          },
          child: SizedBox(
            height: height + 16,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (var h = 0; h <= hours; h++)
                  Positioned(
                    top: h * hourHeight,
                    left: 0,
                    right: 0,
                    child: Row(
                      children: [
                        SizedBox(
                          width: _gutter,
                          child: Transform.translate(
                            offset: const Offset(0, -8),
                            child: Text(
                              h == hours && start + h == 24
                                  ? ''
                                  : formatMinuteOfDay(
                                      context,
                                      (start + h) * 60,
                                    ),
                              style: text.labelSmall?.copyWith(
                                color: scheme.outline,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Divider(
                            height: 1,
                            color: scheme.outlineVariant.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                for (final slot in slots)
                  Positioned(
                    top: yFor(slot.task.startMinute!) + 1,
                    left: _gutter + 8 + laneArea / slot.lanes * slot.lane,
                    width: laneArea / slot.lanes - 4,
                    height: math.max(
                      _minBlockHeight,
                      slot.task.durationMinutes / 60 * hourHeight - 2,
                    ),
                    child: TaskBlock(
                      task: slot.task,
                      compact: slot.lanes > 1,
                      active: now != null && _isActive(slot.task, now!),
                      onTap: () => onTapTask(slot.task),
                      onToggleDone: () => onToggleDone(slot.task),
                    ),
                  ),
                if (now != null)
                  Positioned(
                    key: nowKey,
                    top: yFor(now!.hour * 60 + now!.minute) - 5,
                    left: _gutter - 2,
                    right: 0,
                    child: IgnorePointer(child: _NowLine(color: scheme.error)),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  static bool _isActive(PlannerTask t, DateTime now) =>
      !t.done && !t.startsAt!.isAfter(now) && t.endsAt!.isAfter(now);
}

class _NowLine extends StatelessWidget {
  const _NowLine({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Current time',
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          Expanded(child: Container(height: 2, color: color)),
        ],
      ),
    );
  }
}

class TaskBlock extends StatelessWidget {
  const TaskBlock({
    super.key,
    required this.task,
    required this.onTap,
    required this.onToggleDone,
    this.compact = false,
    this.active = false,
  });

  final PlannerTask task;
  final VoidCallback onTap;
  final VoidCallback onToggleDone;
  final bool compact;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = TaskPalette.of(context, task.colorIndex);
    final on = TaskPalette.onColor(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final time = task.isScheduled
        ? '${formatMinuteOfDay(context, task.startMinute!)} · '
              '${formatDuration(task.durationMinutes)}'
        : formatDuration(task.durationMinutes);

    return Semantics(
      button: true,
      label:
          '${task.title}, $time${task.done ? ', done' : ''}'
          '${task.steps.isNotEmpty ? ', ${task.completedSteps} of ${task.steps.length} steps' : ''}',
      child: Opacity(
        opacity: task.done ? 0.55 : 1,
        child: Material(
          color: color,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Container(
              decoration: active
                  ? BoxDecoration(
                      border: Border.all(color: scheme.primary, width: 2.5),
                      borderRadius: BorderRadius.circular(16),
                    )
                  : null,
              padding: const EdgeInsets.fromLTRB(10, 4, 2, 4),
              child: LayoutBuilder(
                builder: (context, c) {
                  final tall = c.maxHeight > 64;
                  final roomy = c.maxHeight >= 38;
                  return Row(
                    crossAxisAlignment: tall
                        ? CrossAxisAlignment.start
                        : CrossAxisAlignment.center,
                    children: [
                      Text(task.emoji, style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              task.title,
                              maxLines: tall ? 2 : 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.titleSmall?.copyWith(
                                color: on,
                                fontWeight: FontWeight.w700,
                                decoration: task.done
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            if ((!compact || tall) && roomy)
                              Text(
                                task.steps.isEmpty
                                    ? time
                                    : '$time · ${task.completedSteps}/${task.steps.length} steps',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: text.labelSmall?.copyWith(
                                  color: on.withValues(alpha: 0.75),
                                ),
                              ),
                            if (tall && task.steps.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: task.progress,
                                  minHeight: 5,
                                  color: on.withValues(alpha: 0.7),
                                  backgroundColor: on.withValues(alpha: 0.12),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      DoneCheck(
                        done: task.done,
                        color: on,
                        onPressed: onToggleDone,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DoneCheck extends StatelessWidget {
  const DoneCheck({
    super.key,
    required this.done,
    required this.onPressed,
    this.color,
  });

  final bool done;
  final VoidCallback onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return IconButton(
      tooltip: done ? 'Mark as not done' : 'Mark as done',
      visualDensity: VisualDensity.compact,
      onPressed: onPressed,
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (child, a) =>
            ScaleTransition(scale: a, child: child),
        child: Icon(
          done ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
          key: ValueKey(done),
          color: c,
          size: 26,
        ),
      ),
    );
  }
}
