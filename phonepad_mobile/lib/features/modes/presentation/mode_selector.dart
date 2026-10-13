import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/theme_controller.dart';
import '../models/surface_mode.dart';

/// Segmented mode selector inspired by developer-bucket/components/liquid-gooey-segmented-tabs.html.
class ModeSelector extends StatelessWidget {
  final SurfaceMode currentMode;
  final ValueChanged<SurfaceMode> onModeChanged;

  const ModeSelector({
    super.key,
    required this.currentMode,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ThemeController.instance.theme;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.backgroundSecondary.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
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
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? theme.accentPrimary.withValues(alpha: 0.2)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
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
                    size: 14,
                    color: isSelected
                        ? theme.accentPrimary
                        : theme.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    mode.title,
                    style: TextStyle(
                      fontSize: 11,
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
