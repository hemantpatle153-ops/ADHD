import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/task.dart';
import '../../state/planner_controller.dart';
import '../../theme/app_theme.dart';
import '../../util/time_format.dart';
import '../focus/focus_screen.dart';
import 'task_editor.dart';

Future<void> showTaskDetail(BuildContext context, String taskId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => TaskDetailSheet(taskId: taskId),
  );
}

class TaskDetailSheet extends StatelessWidget {
  const TaskDetailSheet({super.key, required this.taskId});

  final String taskId;

  @override
  Widget build(BuildContext context) {
    final planner = context.watch<PlannerController>();
    final task = planner.byId(taskId);
    if (task == null) return const SizedBox(height: 120);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final when = task.isScheduled
        ? '${formatDayTitle(task.day, planner.today)} · '
              '${formatMinuteOfDay(context, task.startMinute!)}–'
              '${formatMinuteOfDay(context, task.endMinute! % (24 * 60))}'
        : '${formatDayTitle(task.day, planner.today)} · anytime · '
              '${formatDuration(task.durationMinutes)}';

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: task.steps.length > 4 ? 0.75 : 0.55,
      maxChildSize: 0.95,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: TaskPalette.of(context, task.colorIndex),
                  shape: BoxShape.circle,
                ),
                child: Text(task.emoji, style: const TextStyle(fontSize: 28)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: text.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        decoration: task.done
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    Text(
                      when,
                      style: text.bodyMedium?.copyWith(color: scheme.outline),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: task.done
                      ? null
                      : () {
                          Navigator.of(context)
                            ..pop()
                            ..push(
                              MaterialPageRoute(
                                fullscreenDialog: true,
                                builder: (_) => FocusScreen(taskId: task.id),
                              ),
                            );
                        },
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Start focus'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: task.done ? 'Mark as not done' : 'Mark as done',
                onPressed: () => planner.toggleDone(task.id),
                icon: Icon(task.done ? Icons.undo : Icons.check),
              ),
              IconButton.filledTonal(
                tooltip: 'Edit',
                onPressed: () {
                  Navigator.of(context).pop();
                  showTaskEditor(context, task);
                },
                icon: const Icon(Icons.edit_outlined),
              ),
              PopupMenuButton<String>(
                tooltip: 'More',
                onSelected: (v) => _onMenu(context, planner, task, v),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'tomorrow',
                    child: Text('Move to tomorrow'),
                  ),
                  PopupMenuItem(value: 'copy', child: Text('Copy to tomorrow')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
          if (task.steps.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Steps · ${task.completedSteps}/${task.steps.length}',
              style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            for (final s in task.steps)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: s.done,
                onChanged: (_) => planner.toggleStep(task.id, s.id),
                title: Text(
                  s.title,
                  style: s.done
                      ? TextStyle(
                          decoration: TextDecoration.lineThrough,
                          color: scheme.outline,
                        )
                      : null,
                ),
              ),
          ],
          if (task.notes.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Notes',
              style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(task.notes, style: text.bodyMedium),
          ],
        ],
      ),
    );
  }

  Future<void> _onMenu(
    BuildContext context,
    PlannerController planner,
    PlannerTask task,
    String action,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final tomorrow = task.day.add(const Duration(days: 1));
    switch (action) {
      case 'tomorrow':
        await planner.upsert(task.copyWith(day: tomorrow));
        nav.pop();
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Moved to tomorrow. Future-you has it.'),
          ),
        );
      case 'copy':
        await planner.duplicateTo(task.id, tomorrow);
        nav.pop();
        messenger.showSnackBar(
          const SnackBar(content: Text('Copied to tomorrow.')),
        );
      case 'delete':
        await planner.delete(task.id);
        nav.pop();
        messenger.showSnackBar(
          SnackBar(
            content: Text('Deleted "${task.title}"'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () => planner.restore(task),
            ),
          ),
        );
    }
  }
}
