import 'planner_controller.dart';

/// Pure timer maths for a focus session, driven by an injectable clock so it
/// stays correct when the app is backgrounded and is easy to test.
class FocusSession {
  FocusSession({required this._length, required this._clock})
    : _startedAt = _clock();

  final Clock _clock;
  final DateTime _startedAt;
  Duration _length;
  Duration _pausedTotal = Duration.zero;
  DateTime? _pausedAt;

  bool get isPaused => _pausedAt != null;
  Duration get length => _length;

  Duration get elapsed {
    final end = _pausedAt ?? _clock();
    final e = end.difference(_startedAt) - _pausedTotal;
    return e.isNegative ? Duration.zero : e;
  }

  Duration get remaining {
    final r = _length - elapsed;
    return r.isNegative ? Duration.zero : r;
  }

  /// 0 at start, 1 when finished.
  double get progress => _length.inMilliseconds == 0
      ? 1
      : (elapsed.inMilliseconds / _length.inMilliseconds).clamp(0.0, 1.0);

  bool get isFinished => remaining == Duration.zero;

  /// Wall-clock time the session will end if left running.
  DateTime get endsAt => _clock().add(remaining);

  void pause() {
    _pausedAt ??= _clock();
  }

  void resume() {
    final p = _pausedAt;
    if (p == null) return;
    _pausedTotal += _clock().difference(p);
    _pausedAt = null;
  }

  void extend(Duration by) {
    // If already finished, extend from now rather than from the old end.
    if (isFinished) {
      _length = elapsed + by;
    } else {
      _length += by;
    }
  }
}
