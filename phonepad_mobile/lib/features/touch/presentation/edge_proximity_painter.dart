import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../models/touch_point.dart';

/// Renders peripheral border glow when fingers near display edges.
/// Inspired by developer-bucket/components/border-glow.html.
class EdgeProximityPainter extends CustomPainter {
  final Map<int, TouchPoint> activePointers;
  final double threshold;

  EdgeProximityPainter({
    required this.activePointers,
    this.threshold = 35.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (activePointers.isEmpty) return;

    double maxProximityLeft = 0.0;
    double maxProximityRight = 0.0;
    double maxProximityTop = 0.0;
    double maxProximityBottom = 0.0;

    for (final point in activePointers.values) {
      final pos = point.current;

      // Distance to edges
      final distLeft = pos.dx;
      final distRight = size.width - pos.dx;
      final distTop = pos.dy;
      final distBottom = size.height - pos.dy;

      if (distLeft < threshold) {
        maxProximityLeft = max(maxProximityLeft, 1.0 - (distLeft / threshold));
      }
      if (distRight < threshold) {
        maxProximityRight = max(maxProximityRight, 1.0 - (distRight / threshold));
      }
      if (distTop < threshold) {
        maxProximityTop = max(maxProximityTop, 1.0 - (distTop / threshold));
      }
      if (distBottom < threshold) {
        maxProximityBottom = max(maxProximityBottom, 1.0 - (distBottom / threshold));
      }
    }

    // Paint Left Glow
    if (maxProximityLeft > 0) {
      _paintEdgeGlow(canvas, Rect.fromLTWH(0, 0, 12, size.height), Alignment.centerLeft, maxProximityLeft);
    }
    // Paint Right Glow
    if (maxProximityRight > 0) {
      _paintEdgeGlow(canvas, Rect.fromLTWH(size.width - 12, 0, 12, size.height), Alignment.centerRight, maxProximityRight);
    }
    // Paint Top Glow
    if (maxProximityTop > 0) {
      _paintEdgeGlow(canvas, Rect.fromLTWH(0, 0, size.width, 12), Alignment.topCenter, maxProximityTop);
    }
    // Paint Bottom Glow
    if (maxProximityBottom > 0) {
      _paintEdgeGlow(canvas, Rect.fromLTWH(0, size.height - 12, size.width, 12), Alignment.bottomCenter, maxProximityBottom);
    }
  }

  void _paintEdgeGlow(Canvas canvas, Rect rect, Alignment align, double intensity) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: align,
        end: -align,
        colors: [
          PhonePadColors.accentEmerald.withValues(alpha: 0.6 * intensity),
          Colors.transparent,
        ],
      ).createShader(rect);

    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant EdgeProximityPainter oldDelegate) {
    return true;
  }
}
