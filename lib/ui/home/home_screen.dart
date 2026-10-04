import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/task.dart';
import '../../state/planner_controller.dart';
import '../../state/settings_controller.dart';
import '../../util/time_format.dart';
import '../focus/focus_screen.dart';
import '../settings/settings_screen.dart';
import '../task/task_detail_sheet.dart';
import '../task/task_editor.dart';
import 'home_widgets.dart';
import 'timeline.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _nowKey = GlobalKey();
  Timer? _ticker;
  bool _scrolledToNow = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Keep the now line and countdowns fresh.
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) setState(() {});
  }

  void _scrollToNowOnce() {
    if (_scrolledToNow) return;
    _scrolledToNow = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _nowKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.35,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<void> _addTask({int? startMinute}) async {
    final planner = context.read<PlannerController>();
    final settings = context.read<SettingsController>().value;
    final draft = planner.newDraft(
      startMinute: startMinute,
      reminderLead: settings.defaultReminderLead,
    );
    await showTaskEditor(context, draft, isNew: true);
  }

  void _openTask(PlannerTask task) => showTaskDetail(context, task.id);

  Future<void> _toggleDone(PlannerTask task) async {
    final planner = context.read<PlannerController>();
    final haptics = context.read<SettingsController>().value.haptics;
    if (haptics) unawaited(HapticFeedback.lightImpact());
    await planner.toggleDone(task.id);
    if (!mounted) return;
    final updated = planner.byId(task.id);
    if (updated?.done == true) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(_cheer(planner, updated!)),
            duration: const Duration(seconds: 2),
          ),
        );
    }
  }

  String _cheer(PlannerController planner, PlannerTask t) {
    final left = planner.unfinishedCount(t.day);
    if (left == 0) return '🎉 All done for the day. That\'s huge.';
    const lines = [
      'Nice! One less thing on your mind.',
      'Done. Look at you go.',
      'Checked off. Momentum unlocked.',
      'That counts. Well done.',
    ];
    return '${t.emoji}  ${lines[t.id.hashCode.abs() % lines.length]}';
  }

  void _startFocus(PlannerTask task) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => FocusScreen(taskId: task.id),
      ),
    );
  }

  Future<void> _moveUnfinished(DateTime from, DateTime to) async {
    final planner = context.read<PlannerController>();
    final n = await planner.moveUnfinished(from, to);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          n == 0
              ? 'Nothing to move.'
              : 'Moved $n ${n == 1 ? 'task' : 'tasks'} to '
                    '${formatDayTitle(to, planner.today).toLowerCase()}.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final planner = context.watch<PlannerController>();
    final settings = context.watch<SettingsController>().value;
    final now = planner.now();
    final today = planner.today;
    final day = planner.selectedDay;
    final isToday = isSameDay(day, today);
    final isPast = day.isBefore(today);
    final scheduled = planner.scheduledFor(day);
    final anytime = planner.anytimeFor(day);
    final all = planner.tasksFor(day);
    final doneCount = all.where((t) => t.done).length;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    if (isToday && planner.loaded) _scrollToNowOnce();

    final hello = settings.name.isEmpty
        ? greeting(now)
        : '${greeting(now)}, ${settings.name}';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              hello,
              style: text.labelLarge?.copyWith(color: scheme.outline),
            ),
            Text(formatDayTitle(day, today)),
          ],
        ),
        actions: [
          if (!isToday)
            TextButton(
              onPressed: () {
                _scrolledToNow = false;
                planner.selectDay(today);
              },
              child: const Text('Today'),
            ),
          PopupMenuButton<String>(
            tooltip: 'More',
            onSelected: (v) {
              switch (v) {
                case 'tomorrow':
                  _moveUnfinished(day, day.add(const Duration(days: 1)));
                case 'settings':
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
              }
            },
            itemBuilder: (_) => [
              if (!isPast)
                const PopupMenuItem(
                  value: 'tomorrow',
                  child: Text('Move unfinished to tomorrow'),
                ),
              const PopupMenuItem(value: 'settings', child: Text('Settings')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addTask(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add'),
      ),
      body: !planner.loaded
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async => setState(() {}),
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: DayStrip(
                        selected: day,
                        today: today,
                        progressFor: planner.progressFor,
                        onSelect: (d) {
                          _scrolledToNow = false;
                          planner.selectDay(d);
                        },
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                    sliver: SliverList.list(
                      children: [
                        if (isToday)
                          NowCard(
                            now: now,
                            current: planner.currentTask(),
                            next: planner.nextTask(),
                            onFocus: _startFocus,
                            onOpen: _openTask,
                            onAdd: () => _addTask(),
                          ),
                        if (isPast && planner.unfinishedCount(day) > 0)
                          Card(
                            child: ListTile(
                              leading: const Text(
                                '🌱',
                                style: TextStyle(fontSize: 24),
                              ),
                              title: Text(
                                '${planner.unfinishedCount(day)} left over. '
                                'That\'s okay.',
                              ),
                              subtitle: const Text('Bring them into today?'),
                              trailing: FilledButton.tonal(
                                onPressed: () => _moveUnfinished(day, today),
                                child: const Text('Move'),
                              ),
                            ),
                          ),
                        if (all.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _ProgressRow(done: doneCount, total: all.length),
                        ],
                        if (anytime.isNotEmpty) ...[
                          const SectionHeader('Anytime'),
                          AnytimeList(
                            tasks: anytime,
                            onTap: _openTask,
                            onToggleDone: _toggleDone,
                          ),
                        ],
                        SectionHeader(
                          'Timeline',
                          trailing: Text(
                            'Tap a time to add',
                            style: text.labelSmall?.copyWith(
                              color: scheme.outline,
                            ),
                          ),
                        ),
                        if (all.isEmpty) const _EmptyDay(),
                        DayTimeline(
                          tasks: scheduled,
                          startHour: settings.dayStartHour,
                          endHour: settings.dayEndHour,
                          now: isToday ? now : null,
                          nowKey: _nowKey,
                          onTapTask: _openTask,
                          onToggleDone: _toggleDone,
                          onTapEmpty: (m) => _addTask(startMinute: m),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({required this.done, required this.total});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: '$done of $total tasks done',
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: total == 0 ? 0 : done / total),
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOutCubic,
                builder: (_, v, _) => LinearProgressIndicator(
                  value: v,
                  minHeight: 10,
                  backgroundColor: scheme.surfaceContainerHighest,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$done of $total done',
            style: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _EmptyDay extends StatelessWidget {
  const _EmptyDay();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        'A blank day. Start with one thing that would make it feel good, '
        'even something tiny like "drink water".',
        style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      ),
    );
  }
}
