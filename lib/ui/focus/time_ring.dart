import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A "time timer": a coloured wedge that shrinks as time passes, so the
/// remaining time is something you can see at a glance, not just read.
class TimeRing extends StatelessWidget {
  const TimeRing({
    super.key,
    required this.progress,
    required this.color,
    required this.child,
  });

  /// 0 = full wedge, 1 = empty.
  final double progress;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AspectRatio(
      aspectRatio: 1,
      child: CustomPaint(
        painter: _WedgePainter(
          remaining: 1 - progress,
          color: color,
          track: scheme.surfaceContainerHighest,
          tick: scheme.outlineVariant,
        ),
        child: Center(
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.all(64),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.surface,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 16,
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _WedgePainter extends CustomPainter {
  _WedgePainter({
    required this.remaining,
    required this.color,
    required this.track,
    required this.tick,
  });

  final double remaining;
  final Color color;
  final Color track;
  final Color tick;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    canvas.drawCircle(center, radius, Paint()..color = track);
    final sweep = 2 * math.pi * remaining.clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweep,
      true,
      Paint()..color = color,
    );
    final tickPaint = Paint()
      ..color = tick
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 12; i++) {
      final a = i / 12 * 2 * math.pi - math.pi / 2;
      final outer = center + Offset(math.cos(a), math.sin(a)) * (radius - 6);
      final inner = center + Offset(math.cos(a), math.sin(a)) * (radius - 16);
      canvas.drawLine(inner, outer, tickPaint);
    }
  }

  @override
  bool shouldRepaint(_WedgePainter old) =>
      old.remaining != remaining || old.color != color || old.track != track;
}
