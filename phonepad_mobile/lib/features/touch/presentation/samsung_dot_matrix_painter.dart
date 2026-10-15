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
  final double containerBorderRadius;

  List<Offset>? _cachedBorderOffsets;
  Size? _lastSize;

  SamsungDotMatrixPainter({
    required this.activePointers,
    super.repaint,
    PhonePadThemeData? theme,
    this.dotSpacing = 13.0,
    this.baseDotRadius = 1.2,
    this.maxDotRadius = 4.8,
    this.influenceRadius = 76.0,
    this.containerBorderRadius = 22.0,
  }) : theme = theme ?? PhonePadThemeData.obsidianEmerald;

  List<Offset> _getBorderOffsets(
    Size size,
    double borderInset,
    double cornerRadius,
    double spacing,
  ) {
    if (_cachedBorderOffsets != null && _lastSize == size) {
      return _cachedBorderOffsets!;
    }
    _lastSize = size;
    final offsets = <Offset>[];
    final borderRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        borderInset,
        borderInset,
        size.width - (borderInset * 2),
        size.height - (borderInset * 2),
      ),
      Radius.circular(cornerRadius),
    );
    final path = Path()..addRRect(borderRRect);
    for (final metric in path.computeMetrics()) {
      final length = metric.length;
      final numDots = (length / spacing).round();
      if (numDots <= 0) continue;
      final step = length / numDots;
      for (int i = 0; i < numDots; i++) {
        final tangent = metric.getTangentForOffset(i * step);
        if (tangent != null) {
          offsets.add(tangent.position);
        }
      }
    }
    _cachedBorderOffsets = offsets;
    return offsets;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final basePaint = Paint()
      ..color = theme.accentPrimary.withValues(
        alpha: theme.isDark ? 0.16 : 0.20,
      )
      ..style = PaintingStyle.fill;

    final glowPaint = Paint()..style = PaintingStyle.fill;
    final hasTouches = activePointers.isNotEmpty;

    // 1. Draw Dotted Container Boundary (replaces solid border lines with precision dots)
    const double borderInset = 2.0;
    final double innerCornerRadius =
        (containerBorderRadius - borderInset).clamp(0.0, containerBorderRadius);
    final borderRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        borderInset,
        borderInset,
        size.width - (borderInset * 2),
        size.height - (borderInset * 2),
      ),
      Radius.circular(innerCornerRadius),
    );

    final double borderDotSpacing = dotSpacing * 0.85;
    final double baseBorderDotRadius = baseDotRadius * 1.1;
    final borderOffsets = _getBorderOffsets(
      size,
      borderInset,
      innerCornerRadius,
      borderDotSpacing,
    );
    final borderDotPaint = Paint()..style = PaintingStyle.fill;

    for (final dotCenter in borderOffsets) {
      if (!hasTouches) {
        // Subtler, darker border dots at rest to blend cohesively with the grid
        borderDotPaint.color = theme.accentPrimary.withValues(
          alpha: theme.isDark ? 0.22 : 0.28,
        );
        canvas.drawCircle(dotCenter, baseBorderDotRadius, borderDotPaint);
      } else {
        // Proximity calculation for tactile border dots
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
          final eased = maxProximity * maxProximity * (3.0 - 2.0 * maxProximity);
          final currentRadius = baseBorderDotRadius +
              ((maxDotRadius * 0.7) - baseBorderDotRadius) * eased;

          final Color dotColor = activeFingerCount >= 3
              ? theme.accentTertiary
              : activeFingerCount == 2
                  ? theme.accentSecondary
                  : theme.accentPrimary;

          borderDotPaint.color = dotColor.withValues(
            alpha: (0.35 + (0.65 * eased)).clamp(0.0, 1.0),
          );
          canvas.drawCircle(dotCenter, currentRadius, borderDotPaint);
        } else {
          borderDotPaint.color = theme.accentPrimary.withValues(
            alpha: theme.isDark ? 0.22 : 0.28,
          );
          canvas.drawCircle(dotCenter, baseBorderDotRadius, borderDotPaint);
        }
      }
    }

    // 2. Draw dynamic dense interior dot matrix grid
    // Edge-to-edge symmetrical column and row distribution across full container
    const double margin = 12.0;
    final double availableWidth = size.width - (margin * 2);
    final double availableHeight = size.height - (margin * 2);

    if (availableWidth > 0 && availableHeight > 0) {
      final int colCount = (availableWidth / dotSpacing).round().clamp(1, 1000);
      final int rowCount = (availableHeight / dotSpacing).round().clamp(1, 1000);
      final double stepX = availableWidth / colCount;
      final double stepY = availableHeight / rowCount;

      for (int c = 0; c <= colCount; c++) {
        final double x = margin + (c * stepX);
        for (int r = 0; r <= rowCount; r++) {
          final double y = margin + (r * stepY);
          final dotCenter = Offset(x, y);

          // Only skip points that land outside the container's rounded corner boundary
          if (!borderRRect.contains(dotCenter)) continue;

          if (!hasTouches) {
            // Ambient state: visible, brighter micro-dots (eliminates dark void look)
            canvas.drawCircle(dotCenter, baseDotRadius, basePaint);
            continue;
          }

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
            final eased = maxProximity * maxProximity * (3.0 - 2.0 * maxProximity);
            final currentRadius =
                baseDotRadius + (maxDotRadius - baseDotRadius) * eased;

            final Color dotColor = activeFingerCount >= 3
                ? theme.accentTertiary
                : activeFingerCount == 2
                    ? theme.accentSecondary
                    : theme.accentPrimary;

            glowPaint.color = dotColor.withValues(
              alpha: (0.35 + (0.65 * eased)).clamp(0.0, 1.0),
            );

            canvas.drawCircle(dotCenter, currentRadius, glowPaint);
          } else {
            canvas.drawCircle(dotCenter, baseDotRadius, basePaint);
          }
        }
      }
    }

    // 3. Render tactile finger contact indicators directly under touch coordinates
    for (final point in activePointers.values) {
      final pos = point.current;

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
