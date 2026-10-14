import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/liquid_glass_container.dart';
import '../../../core/theme/spring_bounce_tap.dart';
import '../../../core/theme/theme_controller.dart';

/// Item definition for LiquidSpeedDial satellites.
class LiquidDialAction {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const LiquidDialAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });
}

/// Floating Liquid Gooey Speed Dial component featuring spring bounce physics
/// (cubic-bezier(0.34, 1.56, 0.64, 1)) and frosted liquid glass satellites.
class LiquidSpeedDial extends StatefulWidget {
  final List<LiquidDialAction> actions;
  final VoidCallback? onToggle;
  final Alignment alignment;

  const LiquidSpeedDial({
    super.key,
    required this.actions,
    this.onToggle,
    this.alignment = Alignment.bottomRight,
  });

  @override
  State<LiquidSpeedDial> createState() => _LiquidSpeedDialState();
}

class _LiquidSpeedDialState extends State<LiquidSpeedDial>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _expandAnimation;
  late Animation<double> _rotationAnimation;
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );

    // Spring curve with dynamic overshoot and settle matching developer-bucket
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Cubic(0.34, 1.56, 0.64, 1),
      reverseCurve: Curves.easeInBack,
    );

    _rotationAnimation = Tween<double>(begin: 0.0, end: 3 * math.pi / 4).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Cubic(0.34, 1.56, 0.64, 1),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    HapticFeedback.mediumImpact();
    setState(() {
      _isOpen = !_isOpen;
      if (_isOpen) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
    widget.onToggle?.call();
  }

  void _close() {
    if (_isOpen) {
      setState(() {
        _isOpen = false;
        _controller.reverse();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final theme = ThemeController.instance.theme;
        final boxSize = _isOpen ? 220.0 : 52.0;

        return SizedBox(
          width: boxSize,
          height: boxSize,
          child: Stack(
            alignment: widget.alignment,
            clipBehavior: Clip.none,
            children: [
              // Backdrop barrier when open
              if (_isOpen)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _close,
                    child: Container(
                      color: Colors.transparent,
                    ),
                  ),
                ),

              // Satellites Layer (arc radiating from trigger)
              ..._buildSatellites(theme),

              // Main Liquid Glass Trigger FAB
              _buildTrigger(theme),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildSatellites(PhonePadThemeData theme) {
    final count = widget.actions.length;
    if (count == 0) return [];

    final List<Widget> widgets = [];
    const double radius = 86.0;

    // Angle span from PI (straight left) to 3*PI/2 (straight up)
    for (int i = 0; i < count; i++) {
      final action = widget.actions[i];
      final angle = count == 1
          ? -math.pi / 2
          : -math.pi + (i * (math.pi / 2) / (count - 1));

      final targetX = radius * math.cos(angle);
      final targetY = radius * math.sin(angle);

      widgets.add(
        AnimatedBuilder(
          animation: _expandAnimation,
          builder: (context, child) {
            final progress = _expandAnimation.value;
            final currentX = targetX * progress;
            final currentY = targetY * progress;
            final scale = progress.clamp(0.0, 1.0);
            final opacity = progress.clamp(0.0, 1.0);

            return Transform.translate(
              offset: Offset(currentX, currentY),
              child: Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: opacity,
                  child: IgnorePointer(
                    ignoring: !_isOpen,
                    child: child,
                  ),
                ),
              ),
            );
          },
          child: SpringBounceTap(
            onTap: () {
              _close();
              action.onTap();
            },
            child: Tooltip(
              message: action.label,
              child: LiquidGlassContainer(
                width: 44,
                height: 44,
                blur: 16,
                borderRadius: BorderRadius.circular(16),
                backgroundColor: theme.surfaceCard.withValues(alpha: 0.85),
                borderColor: (action.color ?? theme.accentPrimary).withValues(alpha: 0.5),
                shadows: [
                  BoxShadow(
                    color: (action.color ?? theme.accentPrimary).withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
                child: Center(
                  child: Icon(
                    action.icon,
                    size: 20,
                    color: action.color ?? theme.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return widgets;
  }

  Widget _buildTrigger(PhonePadThemeData theme) {
    return SpringBounceTap(
      onTap: _toggle,
      pressedScale: 0.90,
      bounceOvershoot: 1.08,
      child: AnimatedBuilder(
        animation: _rotationAnimation,
        builder: (context, child) {
          return Transform.rotate(
            angle: _rotationAnimation.value,
            child: child,
          );
        },
        child: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.accentPrimary,
                theme.accentSecondary,
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: theme.accentPrimary.withValues(alpha: 0.45),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.35),
              width: 1.2,
            ),
          ),
          child: Center(
            child: Icon(
              Icons.add_rounded,
              size: 26,
              color: theme.isDark ? Colors.black : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
