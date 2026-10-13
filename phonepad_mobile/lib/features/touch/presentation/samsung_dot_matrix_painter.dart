import 'package:flutter/material.dart';
import '../../../core/theme/theme_controller.dart';
import '../models/touch_point.dart';

/// Samsung One UI Inspired Dynamic Dot Matrix Digitizer Painter.
/// Features a dense ambient dot grid that dynamically magnifies and glows
/// under finger contact points with magnetic ripple physics.
class SamsungDotMatrixPainter extends CustomPainter {
  final Map<int, TouchPoint> activePointers;
  final PhonePadThemeData theme;
  final double dotSpacing;
  final double baseDotRadius;
  final double maxDotRadius;
  final double influenceRadius;

  SamsungDotMatrixPainter({
    required this.activePointers,
    super.repaint,
    PhonePadThemeData? theme,
    this.dotSpacing = 13.0,
    this.baseDotRadius = 1.2,
    this.maxDotRadius = 4.8,
    this.influenceRadius = 76.0,
  }) : theme = theme ?? PhonePadThemeData.obsidianEmerald;

  @override
  void paint(Canvas canvas, Size size) {
    final basePaint = Paint()
      ..color = theme.dotBaseColor.withValues(alpha: theme.isDark ? 0.045 : 0.065)
      ..style = PaintingStyle.fill;

    final glowPaint = Paint()..style = PaintingStyle.fill;

    final hasTouches = activePointers.isNotEmpty;

    // 1. Draw dynamic dense dot matrix grid
    final cols = (size.width / dotSpacing).ceil() + 1;
    final rows = (size.height / dotSpacing).ceil() + 1;

    for (int c = 0; c < cols; c++) {
      final x = c * dotSpacing;
      if (x > size.width) continue;

      for (int r = 0; r < rows; r++) {
        final y = r * dotSpacing;
        if (y > size.height) continue;

        final dotCenter = Offset(x, y);

        if (!hasTouches) {
          // Ambient state: ultra-subtle, non-distracting transparent micro-dots
          canvas.drawCircle(dotCenter, baseDotRadius * 0.85, basePaint);
          continue;
        }

        // Calculate proximity to closest active finger
        double maxProximity = 0.0;
        int activeFingerCount = 1;

        for (final point in activePointers.values) {
          final dist = (dotCenter - point.current).distance;
          if (dist < influenceRadius) {
            final prox = 1.0 - (dist / influenceRadius);
            if (prox > maxProximity) {
              maxProximity = prox;
              activeFingerCount = activePointers.length;
            }
          }
        }

        if (maxProximity > 0.0) {
          // Smoothstep easing for fluid Samsung One UI spring feel
          final eased = maxProximity * maxProximity * (3.0 - 2.0 * maxProximity);
          final currentRadius = baseDotRadius + (maxDotRadius - baseDotRadius) * eased;

          // Samsung One UI adaptive gradient glow matching theme palette
          final Color dotColor = activeFingerCount >= 3
              ? theme.accentTertiary // 3-finger system gesture
              : activeFingerCount == 2
                  ? theme.accentSecondary // 2-finger scroll
                  : theme.accentPrimary; // 1-finger trackpad

          glowPaint.color = dotColor.withValues(
            alpha: (0.35 + (0.65 * eased)).clamp(0.0, 1.0),
          );

          canvas.drawCircle(dotCenter, currentRadius, glowPaint);
        } else {
          canvas.drawCircle(dotCenter, baseDotRadius * 0.85, basePaint);
        }
      }
    }

    // 2. Render tactile finger contact indicators directly under touch coordinates
    for (final point in activePointers.values) {
      final pos = point.current;

      // Outer soft aura glow
      final auraPaint = Paint()
        ..color = theme.accentPrimary.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
      canvas.drawCircle(pos, 34.0, auraPaint);

      // Samsung One UI Sleek Concentric Ring
      final ringPaint = Paint()
        ..color = theme.accentPrimary.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawCircle(pos, 24.0, ringPaint);

      // Inner Core Dot
      final corePaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.95)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pos, 4.5, corePaint);
    }
  }

  @override
  bool shouldRepaint(covariant SamsungDotMatrixPainter oldDelegate) {
    return true;
  }
}
