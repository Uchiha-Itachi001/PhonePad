import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/theme_controller.dart';
import '../models/surface_mode.dart';

/// Segmented mode selector inspired by developer-bucket/components/liquid-gooey-segmented-tabs.html.
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
    final theme = ThemeController.instance.theme;

    return Container(
      height: isLandscape ? 44 : null,
      padding: EdgeInsets.all(isLandscape ? 3 : 4),
      decoration: BoxDecoration(
        color: theme.backgroundSecondary.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(isLandscape ? 14 : 16),
        border: Border.all(color: theme.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: SurfaceMode.values.map((mode) {
          final isSelected = mode == currentMode;
          return GestureDetector(
            onTap: () {
              if (!isSelected) {
                HapticFeedback.selectionClick();
                onModeChanged(mode);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.symmetric(
                horizontal: isLandscape ? 8 : 10,
                vertical: isLandscape ? 4 : 6,
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? theme.accentPrimary.withValues(alpha: 0.2)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(isLandscape ? 10 : 12),
                border: Border.all(
                  color: isSelected
                      ? theme.accentPrimary.withValues(alpha: 0.6)
                      : Colors.transparent,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    mode.icon,
                    size: isLandscape ? 13 : 14,
                    color: isSelected
                        ? theme.accentPrimary
                        : theme.textSecondary,
                  ),
                  SizedBox(width: isLandscape ? 4 : 6),
                  Text(
                    mode.title,
                    style: TextStyle(
                      fontSize: isLandscape ? 10 : 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected
                          ? theme.textPrimary
                          : theme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
