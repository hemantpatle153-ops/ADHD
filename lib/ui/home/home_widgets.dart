import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/task.dart';
import '../../theme/app_theme.dart';
import '../../util/time_format.dart';
import 'timeline.dart';

/// A week of days to tap between.
class DayStrip extends StatelessWidget {
  const DayStrip({
    super.key,
    required this.selected,
    required this.today,
    required this.onSelect,
    required this.progressFor,
  });

  final DateTime selected;
  final DateTime today;
  final ValueChanged<DateTime> onSelect;
  final double Function(DateTime) progressFor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    // Monday-start week containing the selected day.
    final weekStart = selected.subtract(Duration(days: selected.weekday - 1));
    return Row(
      children: [
        IconButton(
          tooltip: 'Previous week',
          onPressed: () => onSelect(selected.subtract(const Duration(days: 7))),
          icon: const Icon(Icons.chevron_left),
        ),
        for (var i = 0; i < 7; i++)
          Expanded(
            child: Builder(
              builder: (context) {
                final day = weekStart.add(Duration(days: i));
                final isSelected = isSameDay(day, selected);
                final isToday = isSameDay(day, today);
                final progress = progressFor(day);
                return Semantics(
                  selected: isSelected,
                  button: true,
                  label: DateFormat('EEEE d MMMM').format(day),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => onSelect(day),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? scheme.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Text(
                            DateFormat('E').format(day).substring(0, 1),
                            style: text.labelSmall?.copyWith(
                              color: isSelected
                                  ? scheme.onPrimary
                                  : scheme.outline,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${day.day}',
                            style: text.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? scheme.onPrimary
                                  : isToday
                                  ? scheme.primary
                                  : scheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: progress >= 1
                                  ? (isSelected
                                        ? scheme.onPrimary
                                        : scheme.tertiary)
                                  : Colors.transparent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        IconButton(
          tooltip: 'Next week',
          onPressed: () => onSelect(selected.add(const Duration(days: 7))),
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

/// "Now" and "next up" so time stays visible.
class NowCard extends StatelessWidget {
  const NowCard({
    super.key,
    required this.now,
    required this.current,
    required this.next,
    required this.onFocus,
    required this.onOpen,
    required this.onAdd,
  });

  final DateTime now;
  final PlannerTask? current;
  final PlannerTask? next;
  final ValueChanged<PlannerTask> onFocus;
  final ValueChanged<PlannerTask> onOpen;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    if (current == null && next == null) {
      return Card(
        child: ListTile(
          contentPadding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
          title: const Text('Nothing else on the timeline'),
          subtitle: const Text('Add one small thing, or enjoy the space.'),
          trailing: IconButton.filledTonal(
            tooltip: 'Add a task',
            onPressed: onAdd,
            icon: const Icon(Icons.add),
          ),
        ),
      );
    }

    final task = current ?? next!;
    final isNow = current != null;
    final color = TaskPalette.of(context, task.colorIndex);
    final on = TaskPalette.onColor(context);
    final remaining = isNow
        ? task.endsAt!.difference(now)
        : task.startsAt!.difference(now);
    final elapsed = isNow
        ? now.difference(task.startsAt!).inSeconds / (task.durationMinutes * 60)
        : 0.0;

    return Material(
      color: color,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onOpen(task),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isNow ? 'NOW' : 'NEXT UP',
                style: text.labelMedium?.copyWith(
                  color: on.withValues(alpha: 0.7),
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(task.emoji, style: const TextStyle(fontSize: 30)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleLarge?.copyWith(
                            color: on,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          isNow
                              ? '${formatDuration((remaining.inSeconds / 60).ceil())} left'
                              : 'Starts ${formatUntil(remaining)}',
                          style: text.bodyMedium?.copyWith(
                            color: on.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(48, 44),
                      backgroundColor: on,
                      foregroundColor: color,
                    ),
                    onPressed: () => onFocus(task),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Focus'),
                  ),
                ],
              ),
              if (isNow) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: elapsed.clamp(0.0, 1.0),
                    minHeight: 8,
                    color: on.withValues(alpha: 0.75),
                    backgroundColor: on.withValues(alpha: 0.12),
                  ),
                ),
              ],
              if (task.nextStep != null) ...[
                const SizedBox(height: 10),
                Text(
                  task.completedSteps == 0
                      ? 'First tiny step: ${task.nextStep!.title}'
                      : 'Next step: ${task.nextStep!.title}',
                  style: text.bodyMedium?.copyWith(color: on),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Tasks without a time.
class AnytimeList extends StatelessWidget {
  const AnytimeList({
    super.key,
    required this.tasks,
    required this.onTap,
    required this.onToggleDone,
  });

  final List<PlannerTask> tasks;
  final ValueChanged<PlannerTask> onTap;
  final ValueChanged<PlannerTask> onToggleDone;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final t in tasks)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SizedBox(
              height: t.steps.isEmpty ? 56 : 72,
              child: TaskBlock(
                task: t,
                onTap: () => onTap(t),
                onToggleDone: () => onToggleDone(t),
              ),
            ),
          ),
      ],
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
