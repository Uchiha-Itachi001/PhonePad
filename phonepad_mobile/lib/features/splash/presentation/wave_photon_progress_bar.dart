import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';

/// Wave-Light Radial Photon Progress Bar adapted from Developer Bucket Vault
/// (`wave-progress-bar.html`).
///
/// Features a dark frosted track with rounded pill geometry, emerald-to-cyan
/// gradient progress fill, a sweeping radial photon light spot, percentage tag,
/// and smooth status label transitions.
class WavePhotonProgressBar extends StatelessWidget {
  final double progress;       // 0.0 -> 1.0
  final double sweepProgress;  // 0.0 -> 1.0 continuous wave sweep
  final String statusText;
  final double maxWidth;

  const WavePhotonProgressBar({
    super.key,
    required this.progress,
    required this.sweepProgress,
    required this.statusText,
    this.maxWidth = 320.0,
  });

  @override
  Widget build(BuildContext context) {
    final clampedProgress = progress.clamp(0.0, 1.0);
    final percentInt = (clampedProgress * 100).toInt();

    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: PhonePadColors.backgroundSecondary.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Status Step & Percentage Tag
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.2),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: Text(
                    statusText,
                    key: ValueKey<String>(statusText),
                    style: const TextStyle(
                      color: PhonePadColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: PhonePadColors.accentCyan.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: PhonePadColors.accentCyan.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  '$percentInt%',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: PhonePadColors.accentCyan,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Track & Sweeping Photon Wave Fill
          SizedBox(
            height: 12,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final trackWidth = constraints.maxWidth;
                final fillWidth = trackWidth * clampedProgress;

                return Container(
                  width: trackWidth,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(9999),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                      width: 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(9999),
                    child: Stack(
                      children: [
                        // Gradient Fill
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          curve: Curves.easeOut,
                          width: fillWidth,
                          height: 12,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                PhonePadColors.accentEmerald,
                                PhonePadColors.accentCyan,
                                Color(0xFF38BDF8),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(9999),
                            boxShadow: [
                              BoxShadow(
                                color: PhonePadColors.accentCyan.withValues(alpha: 0.4),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                        ),

                        // Sweeping Radial Light Photon Spot
                        if (clampedProgress > 0.05)
                          Positioned(
                            left: (sweepProgress * fillWidth - 25).clamp(
                              -25.0,
                              math.max(0.0, fillWidth - 25.0),
                            ),
                            top: -14,
                            child: Container(
                              width: 50,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    Colors.white.withValues(alpha: 0.95),
                                    PhonePadColors.accentCyan.withValues(alpha: 0.5),
                                    Colors.transparent,
                                  ],
                                  stops: const [0.0, 0.4, 1.0],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
