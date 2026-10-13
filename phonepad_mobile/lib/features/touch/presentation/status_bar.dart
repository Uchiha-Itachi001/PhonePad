import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/network/transport.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/theme_controller.dart';

/// Top telemetry bar inspired by developer-bucket/components/dynamic-notch-island.html.
class PhonePadStatusBar extends StatelessWidget {
  final ConnectionStatus status;
  final String destination;
  final int pointerCount;
  final VoidCallback onSettingsTap;
  final VoidCallback? onToggleOrientation;
  final bool isLandscape;
  final EdgeInsetsGeometry? margin;

  const PhonePadStatusBar({
    super.key,
    required this.status,
    required this.destination,
    required this.pointerCount,
    required this.onSettingsTap,
    this.onToggleOrientation,
    this.isLandscape = false,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ThemeController.instance.theme;
    Color statusColor;
    String statusText;

    switch (status) {
      case ConnectionStatus.connected:
        statusColor = theme.accentPrimary;
        statusText = 'Connected';
        break;
      case ConnectionStatus.connecting:
      case ConnectionStatus.reconnecting:
        statusColor = Colors.amber;
        statusText = 'Connecting...';
        break;
      case ConnectionStatus.disconnected:
        statusColor = PhonePadColors.errorRed;
        statusText = 'Disconnected';
        break;
    }

    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: theme.backgroundSecondary.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: status == ConnectionStatus.connected
              ? theme.accentPrimary.withValues(alpha: 0.35)
              : theme.borderSubtle,
        ),
        boxShadow: [
          if (status == ConnectionStatus.connected)
            BoxShadow(
              color: theme.accentPrimary.withValues(alpha: 0.15),
              blurRadius: 16,
              spreadRadius: 2,
            ),
        ],
      ),
      child: Row(
        children: [
          // Animated Status Dot
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: statusColor.withValues(alpha: 0.6),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Status & Destination
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'PhonePad • $statusText',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: theme.textPrimary,
                    letterSpacing: 0.2,
                  ),
                ),
                Text(
                  destination,
                  style: TextStyle(
                    fontSize: 10,
                    color: theme.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Pointer Count Badge
          if (pointerCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: theme.accentPrimary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${pointerCount}P',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: theme.accentPrimary,
                ),
              ),
            ),

          // 1-Tap Horizontal / Portrait Orientation Toggle Button
          if (onToggleOrientation != null)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                HapticFeedback.lightImpact();
                onToggleOrientation!();
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: isLandscape
                      ? theme.accentPrimary.withValues(alpha: 0.18)
                      : theme.surfaceCard,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isLandscape
                        ? theme.accentPrimary.withValues(alpha: 0.5)
                        : theme.borderSubtle,
                    width: 1,
                  ),
                ),
                child: Icon(
                  isLandscape
                      ? Icons.stay_current_portrait_rounded
                      : Icons.stay_current_landscape_rounded,
                  size: 18,
                  color: isLandscape ? theme.accentPrimary : theme.textPrimary,
                ),
              ),
            ),

          // Settings Button with robust hit target
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              HapticFeedback.lightImpact();
              onSettingsTap();
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.surfaceCard,
                shape: BoxShape.circle,
                border: Border.all(
                  color: theme.borderSubtle,
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.tune_rounded,
                size: 18,
                color: theme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
