import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Interactive container that applies tactile spring bounce physics with dynamic
/// overshoot and settle (cubic-bezier(0.34, 1.56, 0.64, 1) curve) on press & release.
/// Optionally supports press-and-hold auto-repeat for continuous actions (arrows, volume, scroll).
class SpringBounceTap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onHoldRepeat;
  final Duration repeatInitialDelay;
  final Duration repeatInterval;
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
    this.onHoldRepeat,
    this.repeatInitialDelay = const Duration(milliseconds: 320),
    this.repeatInterval = const Duration(milliseconds: 65),
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
  Timer? _initialDelayTimer;
  Timer? _periodicRepeatTimer;

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
    _cancelRepeat();
    _controller.dispose();
    super.dispose();
  }

  void _cancelRepeat() {
    _initialDelayTimer?.cancel();
    _initialDelayTimer = null;
    _periodicRepeatTimer?.cancel();
    _periodicRepeatTimer = null;
  }

  void _handleTapDown(TapDownDetails _) {
    if (widget.onTap == null && widget.onLongPress == null && widget.onHoldRepeat == null) return;
    setState(() => _isPressed = true);
    if (widget.enableHaptics) {
      HapticFeedback.lightImpact();
    }
    _controller.animateTo(0.25, duration: widget.pressDuration, curve: Curves.easeOutCubic);

    if (widget.onHoldRepeat != null) {
      // Fire immediate initial event on touch
      widget.onHoldRepeat!();

      // Start initial delay before rapid repeat kicks in
      _cancelRepeat();
      _initialDelayTimer = Timer(widget.repeatInitialDelay, () {
        if (_isPressed && mounted) {
          _periodicRepeatTimer = Timer.periodic(widget.repeatInterval, (_) {
            if (_isPressed && mounted) {
              if (widget.enableHaptics) {
                HapticFeedback.selectionClick();
              }
              widget.onHoldRepeat!();
            }
          });
        }
      });
    }
  }

  void _handleTapUp(TapUpDetails _) {
    if (!_isPressed) return;
    _cancelRepeat();
    setState(() => _isPressed = false);
    _controller.forward(from: 0.25).then((_) {
      if (mounted) _controller.reset();
    });
    if (widget.onHoldRepeat == null) {
      widget.onTap?.call();
    }
  }

  void _handleTapCancel() {
    if (!_isPressed) return;
    _cancelRepeat();
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
