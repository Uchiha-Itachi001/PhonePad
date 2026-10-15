import 'dart:ui';
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

  static List<Offset>? _cachedBorderOffsets;
  static List<Offset>? _cachedInteriorOffsets;
  static Size? _lastSize;
  static double? _lastSpacing;
  static double? _lastBorderRadius;

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

  void _ensureCachedOffsets(Size size) {
    if (_lastSize == size &&
        _lastSpacing == dotSpacing &&
        _lastBorderRadius == containerBorderRadius &&
        _cachedBorderOffsets != null &&
        _cachedInteriorOffsets != null) {
      return;
    }

    _lastSize = size;
    _lastSpacing = dotSpacing;
    _lastBorderRadius = containerBorderRadius;

    // 1. Build Border Offsets
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

    final borderOffsets = <Offset>[];
    final double borderDotSpacing = dotSpacing * 0.85;
    final path = Path()..addRRect(borderRRect);
    for (final metric in path.computeMetrics()) {
      final length = metric.length;
      final numDots = (length / borderDotSpacing).round();
      if (numDots <= 0) continue;
      final step = length / numDots;
      for (int i = 0; i < numDots; i++) {
        final tangent = metric.getTangentForOffset(i * step);
        if (tangent != null) {
          borderOffsets.add(tangent.position);
        }
      }
    }
    _cachedBorderOffsets = borderOffsets;

    // 2. Build Interior Offsets
    final interiorOffsets = <Offset>[];
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
          if (borderRRect.contains(dotCenter)) {
            interiorOffsets.add(dotCenter);
          }
        }
      }
    }
    _cachedInteriorOffsets = interiorOffsets;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    _ensureCachedOffsets(size);

    final borderOffsets = _cachedBorderOffsets ?? const [];
    final interiorOffsets = _cachedInteriorOffsets ?? const [];
    final hasTouches = activePointers.isNotEmpty;

    // 1. Draw all ambient interior dots in a single hardware-accelerated drawPoints call
    final ambientPaint = Paint()
      ..color = theme.accentPrimary.withValues(
        alpha: theme.isDark ? 0.16 : 0.20,
      )
      ..strokeWidth = baseDotRadius * 2.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    if (interiorOffsets.isNotEmpty) {
      canvas.drawPoints(PointMode.points, interiorOffsets, ambientPaint);
    }

    // 2. Draw all ambient border dots in a single hardware-accelerated drawPoints call
    final borderDotPaint = Paint()
      ..color = theme.accentPrimary.withValues(
        alpha: theme.isDark ? 0.22 : 0.28,
      )
      ..strokeWidth = (baseDotRadius * 1.1) * 2.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    if (borderOffsets.isNotEmpty) {
      canvas.drawPoints(PointMode.points, borderOffsets, borderDotPaint);
    }

    // 3. If finger(s) are touching, render dynamic magnifications only for dots near the fingers
    if (hasTouches) {
      final glowPaint = Paint()..style = PaintingStyle.fill;
      final touches = activePointers.values.toList();
      final double influenceSq = influenceRadius * influenceRadius;
      final int activeFingerCount = touches.length;

      final Color dotColor = activeFingerCount >= 3
          ? theme.accentTertiary
          : activeFingerCount == 2
              ? theme.accentSecondary
              : theme.accentPrimary;

      // Dynamic interior dots in proximity
      for (final dotCenter in interiorOffsets) {
        double minDistanceSq = double.infinity;
        for (final point in touches) {
          final dx = dotCenter.dx - point.current.dx;
          final dy = dotCenter.dy - point.current.dy;
          // Quick bounding box check before calculating square distance
          if (dx.abs() <= influenceRadius && dy.abs() <= influenceRadius) {
            final distSq = dx * dx + dy * dy;
            if (distSq < minDistanceSq) {
              minDistanceSq = distSq;
            }
          }
        }

        if (minDistanceSq < influenceSq) {
          final prox = 1.0 - (minDistanceSq / influenceSq).clamp(0.0, 1.0);
          final eased = prox * prox * (3.0 - 2.0 * prox);
          final currentRadius = baseDotRadius + (maxDotRadius - baseDotRadius) * eased;

          glowPaint.color = dotColor.withValues(
            alpha: (0.35 + (0.65 * eased)).clamp(0.0, 1.0),
          );
          canvas.drawCircle(dotCenter, currentRadius, glowPaint);
        }
      }

      // Dynamic border dots in proximity
      final double baseBorderDotRadius = baseDotRadius * 1.1;
      final double maxBorderDotRadius = maxDotRadius * 0.7;

      for (final dotCenter in borderOffsets) {
        double minDistanceSq = double.infinity;
        for (final point in touches) {
          final dx = dotCenter.dx - point.current.dx;
          final dy = dotCenter.dy - point.current.dy;
          if (dx.abs() <= influenceRadius && dy.abs() <= influenceRadius) {
            final distSq = dx * dx + dy * dy;
            if (distSq < minDistanceSq) {
              minDistanceSq = distSq;
            }
          }
        }

        if (minDistanceSq < influenceSq) {
          final prox = 1.0 - (minDistanceSq / influenceSq).clamp(0.0, 1.0);
          final eased = prox * prox * (3.0 - 2.0 * prox);
          final currentRadius = baseBorderDotRadius + (maxBorderDotRadius - baseBorderDotRadius) * eased;

          glowPaint.color = dotColor.withValues(
            alpha: (0.35 + (0.65 * eased)).clamp(0.0, 1.0),
          );
          canvas.drawCircle(dotCenter, currentRadius, glowPaint);
        }
      }
    }

    // 4. Render tactile finger contact indicators directly under touch coordinates
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
