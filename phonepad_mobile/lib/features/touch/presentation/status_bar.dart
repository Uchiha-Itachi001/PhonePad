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
        statusColor = PhonePadColors.successGreen;
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
      margin: margin ??
          EdgeInsets.symmetric(
            horizontal: isLandscape ? 12 : 16,
            vertical: isLandscape ? 4 : 8,
          ),
      height: isLandscape ? 44 : null,
      padding: EdgeInsets.symmetric(
        horizontal: isLandscape ? 10 : 14,
        vertical: isLandscape ? 4 : 8,
      ),
      decoration: BoxDecoration(
        color: theme.backgroundSecondary.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(isLandscape ? 14 : 20),
        border: Border.all(
          color: status == ConnectionStatus.connected
              ? PhonePadColors.successGreen.withValues(alpha: 0.35)
              : theme.borderSubtle,
        ),
        boxShadow: [
          if (status == ConnectionStatus.connected)
            BoxShadow(
              color: PhonePadColors.successGreen.withValues(alpha: 0.15),
              blurRadius: 16,
              spreadRadius: 2,
            ),
        ],
      ),
      child: Row(
        children: [
          // Animated Status Dot
          Container(
            width: isLandscape ? 6 : 8,
            height: isLandscape ? 6 : 8,
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
          SizedBox(width: isLandscape ? 6 : 10),

          // Status & Destination
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'PhonePad • $statusText',
                  style: TextStyle(
                    fontSize: isLandscape ? 11 : 12,
                    fontWeight: FontWeight.w700,
                    color: theme.textPrimary,
                    letterSpacing: 0.2,
                  ),
                ),
                Text(
                  destination,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isLandscape ? 9 : 10,
                    color: theme.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Pointer Count Badge
          if (pointerCount > 0)
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isLandscape ? 6 : 8,
                vertical: isLandscape ? 1 : 2,
              ),
              margin: EdgeInsets.only(right: isLandscape ? 4 : 8),
              decoration: BoxDecoration(
                color: theme.accentPrimary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${pointerCount}P',
                style: TextStyle(
                  fontSize: isLandscape ? 9 : 10,
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
                padding: EdgeInsets.all(isLandscape ? 5 : 8),
                margin: EdgeInsets.only(right: isLandscape ? 6 : 8),
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
                  size: isLandscape ? 15 : 18,
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
              padding: EdgeInsets.all(isLandscape ? 5 : 8),
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
                size: isLandscape ? 15 : 18,
                color: theme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
