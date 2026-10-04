import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../models/task.dart';
import '../../services/notification_service.dart';
import '../../state/focus_session.dart';
import '../../state/planner_controller.dart';
import '../../state/settings_controller.dart';
import '../../theme/app_theme.dart';
import '../../util/time_format.dart';
import 'companion.dart';
import 'time_ring.dart';

/// Body-doubling focus mode: a visual timer, the current step, and a calm
/// buddy who checks in now and then.
class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key, required this.taskId});

  final String taskId;

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> with WidgetsBindingObserver {
  late final PlannerController _planner;
  late final Reminders _reminders;
  late final FocusSession _session;
  Timer? _tick;
  String _lastLine = '';
  bool _finishedHandled = false;

  @override
  void initState() {
    super.initState();
    _planner = context.read<PlannerController>();
    _reminders = context.read<Reminders>();
    final task = _planner.byId(widget.taskId);
    final minutes = (task?.durationMinutes ?? 25).clamp(5, 120);
    _session = FocusSession(
      length: Duration(minutes: minutes),
      clock: _planner.now,
    );
    WidgetsBinding.instance.addObserver(this);
    _setAwake(true);
    _scheduleEnd();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tick?.cancel();
    _setAwake(false);
    super.dispose();
  }

  void _setAwake(bool on) {
    // Not supported in some test/desktop environments; never crash on it.
    unawaited(WakelockPlus.toggle(enable: on).catchError((_) {}));
  }

  void _scheduleEnd() {
    final task = _planner.byId(widget.taskId);
    unawaited(
      _reminders.scheduleFocusEnd(_session.endsAt, task?.title ?? 'your task'),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _onTick();
  }

  void _onTick() {
    if (!mounted) return;
    final settings = context.read<SettingsController>().value;
    final line = _line(settings.focusCheckInMinutes);
    if (line != _lastLine && _lastLine.isNotEmpty && settings.haptics) {
      HapticFeedback.selectionClick();
    }
    _lastLine = line;
    if (_session.isFinished && !_finishedHandled) {
      _finishedHandled = true;
      if (settings.haptics) HapticFeedback.heavyImpact();
    }
    setState(() {});
  }

  String _line(int checkIn) => companionLine(
    elapsed: _session.elapsed,
    length: _session.length,
    checkInMinutes: checkIn,
    paused: _session.isPaused,
  );

  void _togglePause() {
    setState(() {
      if (_session.isPaused) {
        _session.resume();
        _scheduleEnd();
      } else {
        _session.pause();
        unawaited(_reminders.cancelFocusEnd());
      }
    });
  }

  void _extend(int minutes) {
    setState(() {
      _session.extend(Duration(minutes: minutes));
      _finishedHandled = false;
    });
    if (!_session.isPaused) _scheduleEnd();
  }

  Future<void> _close({bool markDone = false}) async {
    unawaited(_reminders.cancelFocusEnd());
    if (markDone) {
      final task = _planner.byId(widget.taskId);
      if (task != null && !task.done) await _planner.toggleDone(task.id);
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<bool> _confirmLeave() async {
    if (_session.isFinished) return true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End this session?'),
        content: Text(
          'You focused for ${formatDuration(_session.elapsed.inMinutes)}. '
          'That still counts.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep going'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('End'),
          ),
        ],
      ),
    );
    return leave ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final planner = context.watch<PlannerController>();
    final settings = context.watch<SettingsController>().value;
    final task = planner.byId(widget.taskId);
    if (task == null) {
      return const Scaffold(body: Center(child: Text('Task not found')));
    }
    final color = TaskPalette.of(context, task.colorIndex);
    final text = Theme.of(context).textTheme;
    final finished = _session.isFinished;
    final animate = !MediaQuery.of(context).disableAnimations;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmLeave()) await _close();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'End session',
            icon: const Icon(Icons.close),
            onPressed: () async {
              if (await _confirmLeave()) await _close();
            },
          ),
          title: Text('Focus · ${task.emoji} ${task.title}', maxLines: 1),
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, c) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: c.maxHeight - 20),
                child: Column(
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 340),
                      child: TimeRing(
                        progress: _session.progress,
                        color: color,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              formatClock(_session.remaining),
                              style: text.displaySmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                              semanticsLabel:
                                  '${(_session.remaining.inSeconds / 60).ceil()} minutes left',
                            ),
                            Text(
                              _session.isPaused
                                  ? 'paused'
                                  : finished
                                  ? 'done'
                                  : 'left',
                              style: text.labelLarge,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Companion(
                      message: _line(settings.focusCheckInMinutes),
                      color: color,
                      animate: animate && !_session.isPaused && !finished,
                    ),
                    const SizedBox(height: 16),
                    _StepCard(task: task, planner: planner),
                    const SizedBox(height: 20),
                    if (!finished)
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 52),
                              ),
                              onPressed: () => _extend(5),
                              icon: const Icon(Icons.add),
                              label: const Text('5 min'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: FilledButton.icon(
                              onPressed: _togglePause,
                              icon: Icon(
                                _session.isPaused
                                    ? Icons.play_arrow_rounded
                                    : Icons.pause_rounded,
                              ),
                              label: Text(
                                _session.isPaused ? 'Resume' : 'Pause',
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      _FinishedActions(
                        taskDone: task.done,
                        onDone: () => _close(markDone: true),
                        onMore: () => _extend(10),
                        onClose: () => _close(),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({required this.task, required this.planner});

  final PlannerTask task;
  final PlannerController planner;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final step = task.nextStep;
    final total = task.steps.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    total == 0
                        ? 'FOCUS ON'
                        : step == null
                        ? 'ALL STEPS DONE'
                        : 'STEP ${task.completedSteps + 1} OF $total',
                    style: text.labelSmall?.copyWith(
                      letterSpacing: 1.2,
                      color: scheme.outline,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    step?.title ?? task.title,
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (step != null)
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(minimumSize: const Size(48, 44)),
                onPressed: () => planner.toggleStep(task.id, step.id),
                icon: const Icon(Icons.check),
                label: const Text('Done'),
              ),
          ],
        ),
      ),
    );
  }
}

class _FinishedActions extends StatelessWidget {
  const _FinishedActions({
    required this.taskDone,
    required this.onDone,
    required this.onMore,
    required this.onClose,
  });

  final bool taskDone;
  final VoidCallback onDone;
  final VoidCallback onMore;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '🎉',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 40),
        ),
        const SizedBox(height: 8),
        if (!taskDone)
          FilledButton(onPressed: onDone, child: const Text('Mark task done')),
        const SizedBox(height: 8),
        OutlinedButton(
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
          onPressed: onMore,
          child: const Text('10 more minutes'),
        ),
        TextButton(onPressed: onClose, child: const Text('Close')),
      ],
    );
  }
}
