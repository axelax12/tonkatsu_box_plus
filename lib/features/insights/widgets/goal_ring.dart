import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';

/// A progress ring with a small tick where a steady pace would be today.
class GoalRing extends StatelessWidget {
  const GoalRing({
    required this.fraction,
    required this.color,
    this.expectedFraction,
    this.size = 72,
    this.strokeWidth = 8,
    this.child,
    super.key,
  });

  final double fraction;
  final double? expectedFraction;
  final Color color;
  final double size;
  final double strokeWidth;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: fraction.clamp(0, 1).toDouble()),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (BuildContext context, double value, Widget? child) =>
            CustomPaint(
              painter: _RingPainter(
                fraction: value,
                expectedFraction: expectedFraction,
                color: color,
                trackColor: AppColors.surfaceBorder,
                strokeWidth: strokeWidth,
              ),
              child: Center(child: child),
            ),
        child: child,
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.fraction,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
    this.expectedFraction,
  });

  final double fraction;
  final double? expectedFraction;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  static const double _startAngle = -math.pi / 2;
  static const double _fullTurn = 2 * math.pi;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double radius = (size.shortestSide - strokeWidth) / 2;
    final Rect rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );
    if (fraction > 0) {
      canvas.drawArc(
        rect,
        _startAngle,
        _fullTurn * fraction,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = strokeWidth,
      );
    }

    final double? expected = expectedFraction;
    if (expected != null && expected > 0 && expected < 1) {
      final double angle = _startAngle + _fullTurn * expected;
      final Offset inner =
          center +
          Offset(math.cos(angle), math.sin(angle)) *
              (radius - strokeWidth * 0.75);
      final Offset outer =
          center +
          Offset(math.cos(angle), math.sin(angle)) *
              (radius + strokeWidth * 0.75);
      canvas.drawLine(
        inner,
        outer,
        Paint()
          ..color = AppColors.textSecondary
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction ||
      old.expectedFraction != expectedFraction ||
      old.color != color ||
      old.trackColor != trackColor ||
      old.strokeWidth != strokeWidth;
}
