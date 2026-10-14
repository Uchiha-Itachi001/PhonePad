import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';

/// Specular Border Glow Badge adapted from Developer Bucket Vault (`border-glow.html`).
///
/// Features a continuous-curvature squircle container with a rotating conic
/// gradient border aura (`SweepGradient`), frosted glass dark interior, and
/// an energetic PhonePad trackpad emblem.
class BorderGlowBadge extends StatelessWidget {
  final double rotationAngle; // in radians
  final double pulse;         // 0.0 -> 1.0
  final double size;

  const BorderGlowBadge({
    super.key,
    required this.rotationAngle,
    required this.pulse,
    this.size = 110.0,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. Diffuse Glow Halo behind the badge
          Container(
            width: size * 0.9,
            height: size * 0.9,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: PhonePadColors.accentEmerald.withValues(alpha: 0.25 + 0.15 * pulse),
                  blurRadius: 32 + 12 * pulse,
                  spreadRadius: 2 + 4 * pulse,
                ),
                BoxShadow(
                  color: PhonePadColors.accentCyan.withValues(alpha: 0.15 + 0.1 * pulse),
                  blurRadius: 48,
                  spreadRadius: 0,
                ),
              ],
            ),
          ),

          // 2. Rotating Conic Gradient Outer Ring (BorderGlow)
          Transform.rotate(
            angle: rotationAngle,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(size * 0.32),
                gradient: const SweepGradient(
                  colors: [
                    PhonePadColors.accentEmerald,
                    PhonePadColors.accentCyan,
                    Color(0xFF3B82F6),
                    Colors.transparent,
                    PhonePadColors.accentEmerald,
                  ],
                  stops: [0.0, 0.3, 0.6, 0.8, 1.0],
                ),
              ),
            ),
          ),

          // 3. Inner Dark Glass Container with Squircle Curvature
          Container(
            width: size - 3.5,
            height: size - 3.5,
            decoration: BoxDecoration(
              color: PhonePadColors.backgroundPrimary,
              borderRadius: BorderRadius.circular((size - 3.5) * 0.32),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Subtle trackpad grid icon/emblem
                  Icon(
                    Icons.touch_app_rounded,
                    size: size * 0.44,
                    color: PhonePadColors.accentEmerald,
                  ),
                  // Secondary photon dot top-right of trackpad icon
                  Positioned(
                    top: size * 0.26,
                    right: size * 0.28,
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: PhonePadColors.accentCyan,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: PhonePadColors.accentCyan,
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
