import 'package:flutter/material.dart';

/// What the body-doubling buddy says at a given point in a session.
///
/// Milestones (start, halfway, final stretch) take priority; otherwise the
/// buddy rotates through calm check-ins every [checkInMinutes].
String companionLine({
  required Duration elapsed,
  required Duration length,
  required int checkInMinutes,
  required bool paused,
}) {
  if (paused) return 'Taking a pause is fine. I\'ll be right here.';
  final remaining = length - elapsed;
  if (elapsed < const Duration(minutes: 1)) {
    return 'I\'m here with you. Let\'s start with the first tiny step.';
  }
  if (remaining <= Duration.zero) return 'Time! You showed up and did it.';
  if (remaining <= const Duration(minutes: 2)) {
    return 'Almost there. Finish the bit you\'re on.';
  }
  final half = length ~/ 2;
  if (length >= const Duration(minutes: 10) &&
      elapsed >= half &&
      elapsed < half + const Duration(minutes: 1)) {
    return 'Halfway! Nice steady work.';
  }
  if (checkInMinutes <= 0) return 'Working alongside you.';
  final slot = elapsed.inMinutes ~/ checkInMinutes;
  return _checkIns[slot % _checkIns.length];
}

const _checkIns = [
  'Working alongside you.',
  'Still here. How\'s it going?',
  'Shoulders down, jaw unclenched. Keep going.',
  'Drifted off? No problem. Back to the current step.',
  'Small progress is real progress.',
  'Sip of water? Then back to it.',
  'You\'re doing the thing. That\'s the hard part.',
];

/// A softly "breathing" buddy so the screen feels shared, not empty.
class Companion extends StatefulWidget {
  const Companion({
    super.key,
    required this.message,
    required this.color,
    this.animate = true,
  });

  final String message;
  final Color color;
  final bool animate;

  @override
  State<Companion> createState() => _CompanionState();
}

class _CompanionState extends State<Companion>
    with SingleTickerProviderStateMixin {
  late final _breath = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) _breath.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant Companion old) {
    super.didUpdateWidget(old);
    if (widget.animate && !_breath.isAnimating) {
      _breath.repeat(reverse: true);
    } else if (!widget.animate && _breath.isAnimating) {
      _breath.stop();
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        ScaleTransition(
          scale: Tween(
            begin: 0.92,
            end: 1.06,
          ).animate(CurvedAnimation(parent: _breath, curve: Curves.easeInOut)),
          child: Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
            ),
            child: const Text('🦉', style: TextStyle(fontSize: 30)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: Container(
              key: ValueKey(widget.message),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                  bottomLeft: Radius.circular(4),
                ),
              ),
              child: Semantics(
                liveRegion: true,
                child: Text(widget.message, style: text.bodyMedium),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
