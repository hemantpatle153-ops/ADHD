import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/task.dart';
import '../../services/breakdown_service.dart';
import '../../state/planner_controller.dart';
import '../../theme/app_theme.dart';
import '../../util/time_format.dart';
import 'emoji_picker.dart';

Future<void> showTaskEditor(
  BuildContext context,
  PlannerTask task, {
  bool isNew = false,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => TaskEditor(initial: task, isNew: isNew),
    ),
  );
}

class TaskEditor extends StatefulWidget {
  const TaskEditor({super.key, required this.initial, this.isNew = false});

  final PlannerTask initial;
  final bool isNew;

  @override
  State<TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends State<TaskEditor> {
  late PlannerTask _task = widget.initial;
  late final _title = TextEditingController(text: widget.initial.title);
  late final _notes = TextEditingController(text: widget.initial.notes);
  final _newStep = TextEditingController();
  final _newStepFocus = FocusNode();
  bool _emojiTouched = false;
  bool _breakingDown = false;
  BreakdownSource? _lastSource;

  static const _durations = [5, 10, 15, 25, 30, 45, 60, 90, 120];
  static const _reminders = <int?>[null, 0, 5, 10, 15, 30];

  @override
  void initState() {
    super.initState();
    _emojiTouched = !widget.isNew;
    _title.addListener(() {
      if (!_emojiTouched) {
        setState(
          () => _task = _task.copyWith(emoji: suggestEmoji(_title.text)),
        );
      }
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    _newStep.dispose();
    _newStepFocus.dispose();
    super.dispose();
  }

  bool get _canSave => _title.text.trim().isNotEmpty;

  Future<void> _save() async {
    if (!_canSave) return;
    final planner = context.read<PlannerController>();
    _addPendingStep();
    await planner.upsert(
      _task.copyWith(title: _title.text.trim(), notes: _notes.text.trim()),
    );
    if (mounted) Navigator.of(context).pop();
  }

  void _addPendingStep() {
    final text = _newStep.text.trim();
    if (text.isEmpty) return;
    final planner = context.read<PlannerController>();
    _task = _task.copyWith(
      steps: [
        ..._task.steps,
        TaskStep(id: planner.newStepId(), title: text),
      ],
    );
    _newStep.clear();
  }

  Future<void> _breakDown() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Give the task a name first.')),
      );
      return;
    }
    final breakdown = context.read<SmartBreakdown>();
    final planner = context.read<PlannerController>();
    setState(() => _breakingDown = true);
    try {
      final result = await breakdown.breakDown(title, notes: _notes.text);
      if (!mounted) return;
      final hadSteps = _task.steps.isNotEmpty;
      setState(() {
        _lastSource = result.source;
        _task = _task.copyWith(
          steps: [
            // Keep finished steps; replace the rest with the new plan.
            ..._task.steps.where((s) => s.done),
            for (final s in result.steps)
              TaskStep(id: planner.newStepId(), title: s.title),
          ],
          durationMinutes: hadSteps
              ? null
              : _closestDuration(result.totalMinutes),
        );
      });
    } finally {
      if (mounted) setState(() => _breakingDown = false);
    }
  }

  int _closestDuration(int minutes) {
    var best = _durations.first;
    for (final d in _durations) {
      if ((d - minutes).abs() < (best - minutes).abs()) best = d;
    }
    return best;
  }

  Future<void> _pickTime() async {
    final initial = _task.startMinute ?? _roundedNow();
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initial ~/ 60, minute: initial % 60),
    );
    if (picked == null) return;
    setState(() {
      _task = _task.copyWith(
        startMinute: () => picked.hour * 60 + picked.minute,
        reminderLeadMinutes: () => _task.reminderLeadMinutes ?? 5,
      );
    });
  }

  int _roundedNow() {
    final now = context.read<PlannerController>().now();
    final m = now.hour * 60 + now.minute;
    return ((m / 15).ceil() * 15).clamp(0, 24 * 60 - 15);
  }

  Future<void> _pickDay() async {
    final planner = context.read<PlannerController>();
    final picked = await showDatePicker(
      context: context,
      initialDate: _task.day,
      firstDate: planner.today.subtract(const Duration(days: 365)),
      lastDate: planner.today.add(const Duration(days: 365 * 2)),
    );
    if (picked != null) setState(() => _task = _task.copyWith(day: picked));
  }

  Future<void> _delete() async {
    final planner = context.read<PlannerController>();
    final messenger = ScaffoldMessenger.of(context);
    final removed = planner.byId(_task.id);
    await planner.delete(_task.id);
    if (!mounted) return;
    Navigator.of(context).pop();
    if (removed != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Deleted "${removed.title}"'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => planner.restore(removed),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final planner = context.read<PlannerController>();
    final aiAvailable = context.read<SmartBreakdown>().aiAvailable;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(widget.isNew ? 'New task' : 'Edit task'),
        actions: [
          if (!widget.isNew)
            IconButton(
              tooltip: 'Delete',
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ListenableBuilder(
              listenable: _title,
              builder: (_, _) => FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(72, 40)),
                onPressed: _canSave ? _save : null,
                child: const Text('Save'),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 48),
        children: [
          Row(
            children: [
              Material(
                color: TaskPalette.of(context, _task.colorIndex),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () async {
                    final e = await pickEmoji(context, _task.emoji);
                    if (e != null) {
                      setState(() {
                        _emojiTouched = true;
                        _task = _task.copyWith(emoji: e);
                      });
                    }
                  },
                  child: SizedBox(
                    width: 60,
                    height: 60,
                    child: Center(
                      child: Text(
                        _task.emoji,
                        style: const TextStyle(fontSize: 30),
                        semanticsLabel: 'Choose icon',
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _title,
                  autofocus: widget.isNew,
                  textCapitalization: TextCapitalization.sentences,
                  style: text.titleLarge,
                  maxLength: 120,
                  decoration: const InputDecoration(
                    hintText: 'What do you want to do?',
                    counterText: '',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: TaskPalette.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final selected = i == _task.colorIndex;
                return Semantics(
                  label: '${TaskPalette.names[i]} colour',
                  selected: selected,
                  button: true,
                  child: GestureDetector(
                    onTap: () =>
                        setState(() => _task = _task.copyWith(colorIndex: i)),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 40,
                      decoration: BoxDecoration(
                        color: TaskPalette.of(context, i),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected
                              ? scheme.onSurface
                              : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          _Label('When'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                avatar: const Icon(Icons.calendar_today, size: 18),
                label: Text(formatDayTitle(_task.day, planner.today)),
                onPressed: _pickDay,
              ),
              ChoiceChip(
                label: const Text('Anytime'),
                selected: !_task.isScheduled,
                onSelected: (_) => setState(
                  () => _task = _task.copyWith(
                    startMinute: () => null,
                    reminderLeadMinutes: () => null,
                  ),
                ),
              ),
              ChoiceChip(
                avatar: const Icon(Icons.schedule, size: 18),
                label: Text(
                  _task.isScheduled
                      ? formatMinuteOfDay(context, _task.startMinute!)
                      : 'Pick a time',
                ),
                selected: _task.isScheduled,
                onSelected: (_) => _pickTime(),
              ),
            ],
          ),
          _Label('How long'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final d in _durations)
                ChoiceChip(
                  label: Text(formatDuration(d)),
                  selected: _task.durationMinutes == d,
                  onSelected: (_) => setState(
                    () => _task = _task.copyWith(durationMinutes: d),
                  ),
                ),
            ],
          ),
          if (_task.isScheduled) ...[
            _Label('Gentle reminder'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final r in _reminders)
                  ChoiceChip(
                    label: Text(
                      r == null
                          ? 'None'
                          : r == 0
                          ? 'At start'
                          : '$r min before',
                    ),
                    selected: _task.reminderLeadMinutes == r,
                    onSelected: (_) => setState(
                      () =>
                          _task = _task.copyWith(reminderLeadMinutes: () => r),
                    ),
                  ),
              ],
            ),
          ],
          _Label('Steps'),
          Card(
            color: scheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Feeling stuck? Get it broken into tiny steps.',
                      style: text.bodyMedium?.copyWith(
                        color: scheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(48, 44),
                    ),
                    onPressed: _breakingDown ? null : _breakDown,
                    icon: _breakingDown
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome),
                    label: Text(_task.steps.isEmpty ? 'Break it down' : 'Redo'),
                  ),
                ],
              ),
            ),
          ),
          if (_lastSource != null)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Text(
                _lastSource == BreakdownSource.ai
                    ? 'Suggested by AI. Edit anything that doesn\'t fit.'
                    : aiAvailable
                    ? 'Couldn\'t reach the AI, so here are offline suggestions.'
                    : 'Offline suggestions. Edit anything that doesn\'t fit.',
                style: text.labelSmall?.copyWith(color: scheme.outline),
              ),
            ),
          const SizedBox(height: 8),
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            onReorderItem: (from, to) {
              setState(() {
                final steps = [..._task.steps];
                steps.insert(to, steps.removeAt(from));
                _task = _task.copyWith(steps: steps);
              });
            },
            children: [
              for (var i = 0; i < _task.steps.length; i++)
                _StepRow(
                  key: ValueKey(_task.steps[i].id),
                  index: i,
                  step: _task.steps[i],
                  onChanged: (s) => setState(() {
                    final steps = [..._task.steps];
                    steps[i] = s;
                    _task = _task.copyWith(steps: steps);
                  }),
                  onRemove: () => setState(() {
                    _task = _task.copyWith(
                      steps: [..._task.steps]..removeAt(i),
                    );
                  }),
                ),
            ],
          ),
          TextField(
            controller: _newStep,
            focusNode: _newStepFocus,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              hintText: 'Add a step',
              prefixIcon: Icon(Icons.add),
            ),
            onSubmitted: (_) {
              setState(_addPendingStep);
              _newStepFocus.requestFocus();
            },
          ),
          _Label('Notes'),
          TextField(
            controller: _notes,
            minLines: 2,
            maxLines: 6,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Anything future-you should know',
            ),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 10),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall
            ?.copyWith(fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _StepRow extends StatefulWidget {
  const _StepRow({
    super.key,
    required this.index,
    required this.step,
    required this.onChanged,
    required this.onRemove,
  });

  final int index;
  final TaskStep step;
  final ValueChanged<TaskStep> onChanged;
  final VoidCallback onRemove;

  @override
  State<_StepRow> createState() => _StepRowState();
}

class _StepRowState extends State<_StepRow> {
  late final _controller = TextEditingController(text: widget.step.title);

  @override
  void didUpdateWidget(covariant _StepRow old) {
    super.didUpdateWidget(old);
    if (widget.step.title != _controller.text) {
      _controller.text = widget.step.title;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Checkbox(
            value: widget.step.done,
            onChanged: (v) =>
                widget.onChanged(widget.step.copyWith(done: v ?? false)),
          ),
          Expanded(
            child: TextField(
              controller: _controller,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                isDense: true,
                filled: false,
                border: InputBorder.none,
              ),
              onChanged: (v) =>
                  widget.onChanged(widget.step.copyWith(title: v)),
            ),
          ),
          IconButton(
            tooltip: 'Remove step',
            visualDensity: VisualDensity.compact,
            onPressed: widget.onRemove,
            icon: const Icon(Icons.close, size: 20),
          ),
          ReorderableDragStartListener(
            index: widget.index,
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.drag_indicator, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
