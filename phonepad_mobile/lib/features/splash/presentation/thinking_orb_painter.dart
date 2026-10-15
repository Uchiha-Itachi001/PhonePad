import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Authentic 3D Halftone Thinking Orb Painter ported from Developer Bucket
/// component `thinking-orbs.html` (Libraries.dev Cognitive State Engine).
///
/// Features:
/// - 3D Orthographic projection with real-time yaw & tilt matrix transforms
/// - Z-sorted depth layering (back-to-front rendering)
/// - Multi-plane orbital tracks with ghost traces
/// - High-velocity energy particles with glowing blue halo
/// - Pure electric blue palette (#38BDF8 / #0284C7 / #2563EB)
class ThinkingOrbPainter extends CustomPainter {
  final double animationProgress; // 0.0 to 1.0 continuous loop
  final Color primaryColor;
  final Color accentColor;
  final int orbitCount;
  final int ghostDotsPerOrbit;
  final int particlesPerOrbit;

  ThinkingOrbPainter({
    required this.animationProgress,
    this.primaryColor = const Color(0xFF38BDF8), // Electric Cyan / Blue
    this.accentColor = const Color(0xFF60A5FA), // Azure Blue
    this.orbitCount = 10,
    this.ghostDotsPerOrbit = 32,
    this.particlesPerOrbit = 2,
  });

  // Deterministic pseudo-random hash function matching thinking-orbs.html
  double _hashD(double a, double b) {
    final h = math.sin(a * 12.9898 + b * 78.233) * 43758.5453;
    return h - h.floorToDouble();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = (math.min(size.width, size.height) / 2) * 0.84;

    // Ambient central blue energy glow
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          primaryColor.withValues(alpha: 0.22),
          accentColor.withValues(alpha: 0.08),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: radius));
    canvas.drawCircle(Offset(cx, cy), radius * 1.05, glowPaint);

    final t = animationProgress * 2 * math.pi;
    final yaw = t * 0.45;
    const tilt = 0.34;

    final st = math.sin(tilt);
    final ct = math.cos(tilt);
    final sy = math.sin(yaw);
    final cyw = math.cos(yaw);

    // 3D Orthographic Projection function
    _ProjectedPoint project(double x, double y, double z) {
      final x1 = x * cyw + z * sy;
      final z1 = -x * sy + z * cyw;
      final y1 = y * ct - z1 * st;
      final z2 = y * st + z1 * ct;
      return _ProjectedPoint(
        offset: Offset(cx + x1, cy - y1),
        z: z2,
      );
    }

    final List<_OrbDot> allDots = [];

    for (int orb = 0; orb < orbitCount; orb++) {
      final h1 = _hashD(orb.toDouble(), 1.7);
      final h2 = _hashD(orb.toDouble(), 5.2);
      final h3 = _hashD(orb.toDouble(), 8.9);

      final ro = radius * (0.42 + 0.54 * h1);
      final th = h1 * 2 * math.pi;
      final phi = math.acos(2 * h2 - 1);

      final nx = math.sin(phi) * math.cos(th);
      final ny = math.cos(phi);
      final nz = math.sin(phi) * math.sin(th);

      double ux = -ny;
      double uy = nx;
      const uz = 0.0;
      final ul = math.max(1e-6, math.sqrt(ux * ux + uy * uy));
      ux /= ul;
      uy /= ul;

      final vx = ny * uz - nz * uy;
      final vy = nz * ux - nx * uz;
      final vz = nx * uy - ny * ux;

      final speed = (0.35 + 0.65 * h3) * (h3 > 0.5 ? 1.0 : -1.0);

      // 1. Ghost dots forming the orbital track ellipse
      for (int k = 0; k < ghostDotsPerOrbit; k++) {
        final a = (k / ghostDotsPerOrbit) * 2 * math.pi;
        final px = (ux * math.cos(a) + vx * math.sin(a)) * ro;
        final py = (uy * math.cos(a) + vy * math.sin(a)) * ro;
        final pz = (uz * math.cos(a) + vz * math.sin(a)) * ro;

        final proj = project(px, py, pz);
        final depth = (proj.z / ro + 1.0) / 2.0; // 0.0 (far) to 1.0 (near)
        final clampedDepth = depth.clamp(0.0, 1.0);

        allDots.add(
          _OrbDot(
            offset: proj.offset,
            z: proj.z,
            radius: 0.8 + 0.9 * clampedDepth,
            color: primaryColor.withValues(
              alpha: 0.12 + 0.38 * clampedDepth,
            ),
            isParticle: false,
          ),
        );
      }

      // 2. High-energy traveling particles
      for (int m = 0; m < particlesPerOrbit; m++) {
        final a = t * speed + (m / particlesPerOrbit) * 2 * math.pi + h2 * 6.0;
        final px = (ux * math.cos(a) + vx * math.sin(a)) * ro;
        final py = (uy * math.cos(a) + vy * math.sin(a)) * ro;
        final pz = (uz * math.cos(a) + vz * math.sin(a)) * ro;

        final proj = project(px, py, pz);
        final depth = (proj.z / ro + 1.0) / 2.0;
        final clampedDepth = depth.clamp(0.0, 1.0);

        allDots.add(
          _OrbDot(
            offset: proj.offset,
            z: proj.z,
            radius: 2.2 + 2.0 * clampedDepth,
            color: Color.lerp(
              primaryColor,
              Colors.white,
              0.4 + 0.6 * clampedDepth,
            )!,
            isParticle: true,
            depth: clampedDepth,
          ),
        );
      }
    }

    // Halftone Z-sorting: Back-to-front rendering for authentic 3D depth
    allDots.sort((a, b) => a.z.compareTo(b.z));

    final dotPaint = Paint()..style = PaintingStyle.fill;

    for (final dot in allDots) {
      if (dot.isParticle) {
        // Particle outer glow aura
        final haloPaint = Paint()
          ..color = primaryColor.withValues(alpha: 0.40 * dot.depth)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
        canvas.drawCircle(dot.offset, dot.radius * 2.2, haloPaint);

        // Core bright particle
        dotPaint.color = dot.color;
        canvas.drawCircle(dot.offset, dot.radius, dotPaint);
      } else {
        // Ghost track dot
        dotPaint.color = dot.color;
        canvas.drawCircle(dot.offset, dot.radius, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant ThinkingOrbPainter oldDelegate) {
    return oldDelegate.animationProgress != animationProgress ||
        oldDelegate.primaryColor != primaryColor;
  }
}

class _ProjectedPoint {
  final Offset offset;
  final double z;

  const _ProjectedPoint({required this.offset, required this.z});
}

class _OrbDot {
  final Offset offset;
  final double z;
  final double radius;
  final Color color;
  final bool isParticle;
  final double depth;

  const _OrbDot({
    required this.offset,
    required this.z,
    required this.radius,
    required this.color,
    required this.isParticle,
    this.depth = 1.0,
  });
}
