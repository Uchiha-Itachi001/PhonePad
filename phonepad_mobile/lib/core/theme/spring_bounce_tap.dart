import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Interactive container that applies tactile spring bounce physics with dynamic
/// overshoot and settle (cubic-bezier(0.34, 1.56, 0.64, 1) curve) on press & release.
class SpringBounceTap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double pressedScale;
  final double bounceOvershoot;
  final Duration pressDuration;
  final Duration releaseDuration;
  final bool enableHaptics;
  final HitTestBehavior behavior;

  const SpringBounceTap({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressedScale = 0.93,
    this.bounceOvershoot = 1.05,
    this.pressDuration = const Duration(milliseconds: 110),
    this.releaseDuration = const Duration(milliseconds: 380),
    this.enableHaptics = true,
    this.behavior = HitTestBehavior.opaque,
  });

  @override
  State<SpringBounceTap> createState() => _SpringBounceTapState();
}

class _SpringBounceTapState extends State<SpringBounceTap>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.releaseDuration,
    );

    // Spring curve with dynamic overshoot and settle
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: widget.pressedScale)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 25.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: widget.pressedScale, end: widget.bounceOvershoot)
            .chain(CurveTween(curve: const Cubic(0.34, 1.56, 0.64, 1))),
        weight: 45.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: widget.bounceOvershoot, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutQuad)),
        weight: 30.0,
      ),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) {
    if (widget.onTap == null && widget.onLongPress == null) return;
    setState(() => _isPressed = true);
    if (widget.enableHaptics) {
      HapticFeedback.lightImpact();
    }
    _controller.animateTo(0.25, duration: widget.pressDuration, curve: Curves.easeOutCubic);
  }

  void _handleTapUp(TapUpDetails _) {
    if (!_isPressed) return;
    setState(() => _isPressed = false);
    _controller.forward(from: 0.25).then((_) {
      if (mounted) _controller.reset();
    });
    widget.onTap?.call();
  }

  void _handleTapCancel() {
    if (!_isPressed) return;
    setState(() => _isPressed = false);
    _controller.animateTo(0.0, duration: const Duration(milliseconds: 180), curve: Curves.easeOutQuad);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onLongPress: widget.onLongPress,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          // If controller is at 0, display resting scale 1.0
          final scale = _controller.isAnimating || _isPressed
              ? _scaleAnimation.value
              : 1.0;
          return Transform.scale(
            scale: scale,
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}
