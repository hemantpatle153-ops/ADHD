import '../models/task.dart';

/// Where a block sits horizontally when tasks overlap.
class LaneSlot {
  const LaneSlot(this.task, this.lane, this.lanes);

  final PlannerTask task;

  /// 0-based column within its overlap group.
  final int lane;

  /// Columns in its overlap group.
  final int lanes;
}

/// Packs overlapping scheduled tasks into side-by-side lanes, like a
/// calendar day view. [tasks] must all be scheduled.
List<LaneSlot> layoutLanes(List<PlannerTask> tasks, {int minBlockMinutes = 0}) {
  final sorted = [...tasks]
    ..sort((a, b) {
      final c = a.startMinute!.compareTo(b.startMinute!);
      return c != 0 ? c : b.durationMinutes.compareTo(a.durationMinutes);
    });

  int end(PlannerTask t) =>
      t.startMinute! +
      (t.durationMinutes < minBlockMinutes
          ? minBlockMinutes
          : t.durationMinutes);

  final result = <LaneSlot>[];
  var group = <(PlannerTask, int)>[];
  var laneEnds = <int>[];
  var groupEnd = -1;

  void flush() {
    final lanes = laneEnds.length;
    for (final (t, lane) in group) {
      result.add(LaneSlot(t, lane, lanes));
    }
    group = [];
    laneEnds = [];
  }

  for (final t in sorted) {
    if (t.startMinute! >= groupEnd && group.isNotEmpty) flush();
    var lane = laneEnds.indexWhere((e) => e <= t.startMinute!);
    if (lane == -1) {
      lane = laneEnds.length;
      laneEnds.add(end(t));
    } else {
      laneEnds[lane] = end(t);
    }
    group.add((t, lane));
    groupEnd = group.length == 1
        ? end(t)
        : (end(t) > groupEnd ? end(t) : groupEnd);
  }
  if (group.isNotEmpty) flush();
  return result;
}
