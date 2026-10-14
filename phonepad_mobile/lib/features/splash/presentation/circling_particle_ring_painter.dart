import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';

/// Circling Particle Ring Painter adapted from Developer Bucket Vault
/// (`circling-particle-ring.html` & `magic-rings.html`).
///
/// Renders two concentric counter-rotating orbital particle rings with glowing
/// photon nodes, trailing auras, and a pulsing central energy halo.
class CirclingParticleRingPainter extends CustomPainter {
  final double animationValue; // 0.0 -> 1.0 cyclic
  final double pulseValue;     // 0.0 -> 1.0 breathing

  CirclingParticleRingPainter({
    required this.animationValue,
    required this.pulseValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.min(size.width, size.height) / 2;

    // 1. Central Ambient Energy Glow
    final glowRadius = maxRadius * (0.55 + 0.1 * pulseValue);
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          PhonePadColors.accentEmerald.withValues(alpha: 0.18 + 0.08 * pulseValue),
          PhonePadColors.accentCyan.withValues(alpha: 0.08 + 0.04 * pulseValue),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: glowRadius));

    canvas.drawCircle(center, glowRadius, glowPaint);

    // 2. Subtle Faint Orbital Guide Tracks
    final outerOrbitRadius = maxRadius * 0.88;
    final innerOrbitRadius = maxRadius * 0.62;

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = Colors.white.withValues(alpha: 0.05);

    canvas.drawCircle(center, outerOrbitRadius, trackPaint);
    canvas.drawCircle(center, innerOrbitRadius, trackPaint);

    // 3. Outer Orbital Particles (Counter-clockwise, Cyan/Emerald)
    const int outerCount = 20;
    final double outerBaseAngle = animationValue * 2 * math.pi;

    for (int i = 0; i < outerCount; i++) {
      final double progress = i / outerCount;
      final double angle = outerBaseAngle + progress * 2 * math.pi;
      // Oscillating radial breathing
      final double radialOffset = 4.0 * math.sin(angle * 2 + animationValue * 4 * math.pi);
      final double r = outerOrbitRadius + radialOffset;

      final double px = center.dx + r * math.cos(angle);
      final double py = center.dy + r * math.sin(angle);

      // Modulate particle size and opacity around orbit
      final double sizeMod = 1.5 + 1.8 * math.sin(progress * math.pi + animationValue * 2 * math.pi).abs();
      final double alphaMod = (0.3 + 0.6 * math.sin(progress * 2 * math.pi + animationValue * 2 * math.pi).abs()).clamp(0.1, 1.0);

      final Color particleColor = Color.lerp(
        PhonePadColors.accentCyan,
        PhonePadColors.accentEmerald,
        (math.sin(angle) + 1) / 2,
      )!.withValues(alpha: alphaMod);

      // Halo blur
      final haloPaint = Paint()
        ..color = particleColor.withValues(alpha: alphaMod * 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
      canvas.drawCircle(Offset(px, py), sizeMod * 2.0, haloPaint);

      // Core photon
      final corePaint = Paint()
        ..color = particleColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(px, py), sizeMod, corePaint);
    }

    // 4. Inner Orbital Particles (Clockwise, Emerald/Teal)
    const int innerCount = 14;
    final double innerBaseAngle = -animationValue * 1.6 * math.pi;

    for (int i = 0; i < innerCount; i++) {
      final double progress = i / innerCount;
      final double angle = innerBaseAngle + progress * 2 * math.pi;
      final double radialOffset = 3.0 * math.cos(angle * 3 + animationValue * 3 * math.pi);
      final double r = innerOrbitRadius + radialOffset;

      final double px = center.dx + r * math.cos(angle);
      final double py = center.dy + r * math.sin(angle);

      final double sizeMod = 1.2 + 1.4 * math.cos(progress * math.pi).abs();
      final double alphaMod = (0.25 + 0.65 * math.cos(progress * 2 * math.pi).abs()).clamp(0.1, 1.0);

      final Color particleColor = Color.lerp(
        PhonePadColors.accentEmerald,
        PhonePadColors.accentTeal,
        (math.cos(angle) + 1) / 2,
      )!.withValues(alpha: alphaMod);

      // Halo blur
      final haloPaint = Paint()
        ..color = particleColor.withValues(alpha: alphaMod * 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
      canvas.drawCircle(Offset(px, py), sizeMod * 1.8, haloPaint);

      // Core photon
      final corePaint = Paint()
        ..color = particleColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(px, py), sizeMod, corePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CirclingParticleRingPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.pulseValue != pulseValue;
  }
}
