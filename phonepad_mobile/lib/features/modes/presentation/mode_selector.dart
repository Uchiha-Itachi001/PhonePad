import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/liquid_glass_container.dart';
import '../../../core/theme/spring_bounce_tap.dart';
import '../../../core/theme/theme_controller.dart';
import '../models/surface_mode.dart';

/// Segmented mode selector inspired by developer-bucket/components/liquid-gooey-segmented-tabs.html,
/// upgraded with frosted liquid glass and tactile spring bounce physics.
class ModeSelector extends StatelessWidget {
  final SurfaceMode currentMode;
  final ValueChanged<SurfaceMode> onModeChanged;
  final bool isLandscape;

  const ModeSelector({
    super.key,
    required this.currentMode,
    required this.onModeChanged,
    this.isLandscape = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final theme = ThemeController.instance.theme;

        return LiquidGlassContainer(
          height: isLandscape ? 44 : 48,
          blur: 16.0,
          borderRadius: BorderRadius.circular(isLandscape ? 14 : 18),
          backgroundColor: theme.backgroundSecondary.withValues(alpha: 0.85),
          borderGradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: theme.isDark ? 0.22 : 0.6),
              theme.accentPrimary.withValues(alpha: 0.15),
              Colors.white.withValues(alpha: 0.05),
            ],
          ),
          padding: EdgeInsets.all(isLandscape ? 3 : 4),
          child: Row(
            mainAxisSize: isLandscape ? MainAxisSize.min : MainAxisSize.max,
            children: SurfaceMode.values.map((mode) {
              final isSelected = mode == currentMode;

              final item = SpringBounceTap(
                pressedScale: 0.92,
                bounceOvershoot: 1.06,
                onTap: () {
                  if (!isSelected) {
                    HapticFeedback.selectionClick();
                    onModeChanged(mode);
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  padding: EdgeInsets.symmetric(
                    horizontal: isLandscape ? 10 : 4,
                    vertical: isLandscape ? 6 : 7,
                  ),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              theme.accentPrimary.withValues(alpha: 0.28),
                              theme.accentSecondary.withValues(alpha: 0.16),
                            ],
                          )
                        : null,
                    borderRadius: BorderRadius.circular(isLandscape ? 11 : 14),
                    border: Border.all(
                      color: isSelected
                          ? theme.accentPrimary.withValues(alpha: 0.65)
                          : Colors.transparent,
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isSelected
                            ? theme.accentPrimary.withValues(alpha: 0.25)
                            : Colors.transparent,
                        blurRadius: isSelected ? 8 : 0,
                        offset: isSelected ? const Offset(0, 2) : Offset.zero,
                      ),
                    ],
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          mode.icon,
                          size: isLandscape ? 13 : 15,
                          color: isSelected
                              ? theme.accentPrimary
                              : theme.textSecondary.withValues(alpha: 0.8),
                        ),
                        SizedBox(width: isLandscape ? 4 : 6),
                        Text(
                          mode.title,
                          style: TextStyle(
                            fontSize: isLandscape ? 10.5 : 12,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            letterSpacing: 0.4,
                            color: isSelected
                                ? (theme.isDark ? Colors.white : theme.textPrimary)
                                : theme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );

              return isLandscape ? item : Expanded(child: item);
            }).toList(),
          ),
        );
      },
    );
  }
}
