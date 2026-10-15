import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import '../../../core/protocol/opcode.dart';
import '../../../core/protocol/packet.dart';
import '../models/touch_point.dart';

class TouchDetector {
  final Map<int, TouchPoint> _activePointers = {};
  int _maxPointersInSession = 0;
  bool _twoFingerTapHandled = false;

  DateTime? _lastTapUpTime;
  Offset? _lastTapUpPosition;
  bool _isDragLocked = false;
  bool _dragStartDispatched = false;

  // Sub-pixel delta accumulator for micro-movements
  double _subPixelDx = 0.0;
  double _subPixelDy = 0.0;
  double _scrollSubPixelDx = 0.0;
  double _scrollSubPixelDy = 0.0;
  bool highResMode = false;

  // 2-Finger navigation swipe state (Browser Back / Forward)
  double _twoFingerAccumX = 0.0;
  double _twoFingerAccumY = 0.0;
  bool _twoFingerSwiped = false;
  bool twoFingerNavEnabled = true;

  // Smart 2-Finger Parallel Scroll vs Pinch to Zoom state
  double _lastPinchSpan = 0.0;
  double _pinchSpanAccum = 0.0;
  double _scrollConfidence = 0.0;
  bool _isScrollingLocked = false;
  bool _isPinching = false;
  bool pinchZoomEnabled = true;

  // Trackpad edge auto-scroll during drag-and-drop
  Size surfaceSize = Size.zero;
  void Function(PhonePadPacket packet)? onEdgeScroll;
  Timer? _edgeScrollTimer;

  // Two-finger kinetic inertial scrolling
  void Function(PhonePadPacket packet)? onInertialScroll;
  Timer? _scrollInertiaTimer;
  double _recentScrollVx = 0.0;
  double _recentScrollVy = 0.0;
  DateTime? _lastScrollTime;

  // 90-degree coordinate rotation for simulated horizontal mode
  bool rotateCoordinates = false;

  Map<int, TouchPoint> get activePointers => _activePointers;
  int get pointerCount => _activePointers.length;
  bool get isDragLocked => _isDragLocked;

  /// Handles finger down event.
  PhonePadPacket? onPointerDown(PointerDownEvent event) {
    _stopScrollInertia();
    if (_activePointers.isEmpty) {
      _subPixelDx = 0.0;
      _subPixelDy = 0.0;
      _scrollSubPixelDx = 0.0;
      _scrollSubPixelDy = 0.0;
      _maxPointersInSession = 0;
      _twoFingerTapHandled = false;
      _pinchSpanAccum = 0.0;
      _scrollConfidence = 0.0;
      _isScrollingLocked = false;
      _isPinching = false;
      _stopEdgeScroll();
    }

    // Check if this finger-down is part of a double-tap-and-hold (Drag Lock)
    PhonePadPacket? dragStartPacket;
    if (_activePointers.isEmpty && _lastTapUpTime != null) {
      final timeSinceTap = DateTime.now().difference(_lastTapUpTime!).inMilliseconds;
      final dist = _lastTapUpPosition != null
          ? (event.localPosition - _lastTapUpPosition!).distance
          : 999.0;

      if (timeSinceTap <= 320 && dist <= 42.0) {
        _isDragLocked = true;
        _dragStartDispatched = false;
        _lastTapUpTime = null;
        _lastTapUpPosition = null;
        HapticFeedback.mediumImpact();
        // We defer dragStart packet dispatch until actual movement begins,
        // ensuring Windows initiates SC_MOVE window header drag rather than double-click maximize.
      }
    }

    _activePointers[event.pointer] = TouchPoint(
      pointerId: event.pointer,
      current: event.localPosition,
      startTime: DateTime.now(),
    );

    if (_activePointers.length > _maxPointersInSession) {
      _maxPointersInSession = _activePointers.length;
    }

    if (_activePointers.length == 3) {
      HapticFeedback.selectionClick();
    } else if (_activePointers.length == 2) {
      _twoFingerAccumX = 0.0;
      _twoFingerAccumY = 0.0;
      _twoFingerSwiped = false;
      _pinchSpanAccum = 0.0;
      _scrollConfidence = 0.0;
      _isScrollingLocked = false;
      _isPinching = false;
      final pts = _activePointers.values.toList();
      _lastPinchSpan = (pts[0].current - pts[1].current).distance;
    }

    return dragStartPacket;
  }

  /// Handles continuous finger motion.
  PhonePadPacket? onPointerMove(PointerMoveEvent event) {
    final point = _activePointers[event.pointer];
    if (point == null) return null;

    point.update(event.localPosition);
    final rawDelta = point.delta;
    final delta = rotateCoordinates ? Offset(rawDelta.dy, -rawDelta.dx) : rawDelta;

    final count = _activePointers.length;
    if (count > _maxPointersInSession) {
      _maxPointersInSession = count;
    }
    final flags = 0x01 | ((count & 0x03) << 1);

    if (count == 1) {
      int sendDx = 0;
      int sendDy = 0;
      int packetFlags = flags;

      if (highResMode) {
        // High-resolution sub-pixel streaming (Q3 fixed-point: 8 units = 1 pixel)
        final rawDx = delta.dx * 8.0 + _subPixelDx;
        final rawDy = delta.dy * 8.0 + _subPixelDy;
        sendDx = rawDx.round();
        sendDy = rawDy.round();
        _subPixelDx = rawDx - sendDx;
        _subPixelDy = rawDy - sendDy;
        packetFlags |= PhonePadPacket.flagHighRes;
      } else {
        // Standard integer pixel mode with sub-pixel rounding accumulator
        _subPixelDx += delta.dx;
        _subPixelDy += delta.dy;

        if (_subPixelDx.abs() >= 0.5) {
          sendDx = _subPixelDx.round();
          _subPixelDx -= sendDx;
        }
        if (_subPixelDy.abs() >= 0.5) {
          sendDy = _subPixelDy.round();
          _subPixelDy -= sendDy;
        }
      }

      if (sendDx == 0 && sendDy == 0) return null;

      if (_isDragLocked) {
        _checkEdgeScroll(event.localPosition);
      }

      if (_isDragLocked && !_dragStartDispatched) {
        _dragStartDispatched = true;
        // On first movement, return DragStart with move deltas!
        // Mouse down and motion occur together so Windows initiates window moving (SC_MOVE) smoothly.
        return PhonePadPacket(
          opcode: Opcode.dragStart,
          dx: sendDx,
          dy: sendDy,
          flags: packetFlags,
        );
      }

      return PhonePadPacket(
        opcode: Opcode.move,
        dx: sendDx,
        dy: sendDy,
        flags: packetFlags,
      );
    } else if (count == 2) {
      // 2-Finger gesture (Pinch Zoom, Nav Swipe, or 2D Scroll)
      final pointers = _activePointers.values.toList();
      if (pointers.length < 2) return null;

      final p1 = pointers[0];
      final p2 = pointers[1];
      final primaryPointerId = _activePointers.keys.reduce((a, b) => a < b ? a : b);

      if (event.pointer == primaryPointerId) {
        _twoFingerAccumX += delta.dx;
        _twoFingerAccumY += delta.dy;
      }

      // 1. Detect deliberate 2-finger horizontal swipe for Browser Back / Forward
      // Requires horizontal dominance (2.2x Y) and blocked if scrolling already active
      if (twoFingerNavEnabled && !_twoFingerSwiped && !_isPinching && !_isScrollingLocked) {
        final absX = _twoFingerAccumX.abs();
        final absY = _twoFingerAccumY.abs();

        if (absX >= 36.0 && absX >= absY * 2.2) {
          _twoFingerSwiped = true;
          HapticFeedback.mediumImpact();
          if (_twoFingerAccumX > 0) {
            // Swiped right -> Browser/Page Back (Alt + Left)
            return const PhonePadPacket(
              opcode: Opcode.media,
              dx: 7, // MediaKey.navBack
            );
          } else {
            // Swiped left -> Browser/Page Forward (Alt + Right)
            return const PhonePadPacket(
              opcode: Opcode.media,
              dx: 8, // MediaKey.navForward
            );
          }
        }
      }

      // If swipe gesture fired, suppress pinch and scroll until fingers lift
      if (_twoFingerSwiped) {
        return null;
      }

      // 2. Smart Parallel Scroll vs Pinch-to-Zoom disambiguation
      final currentSpan = (p1.current - p2.current).distance;
      final deltaSpan = (_lastPinchSpan > 0) ? (currentSpan - _lastPinchSpan) : 0.0;
      final moveDist = delta.distance;
      final spanDist = deltaSpan.abs();

      if (moveDist > 0) {
        if (spanDist < moveDist * 0.65) {
          // Parallel motion dominates -> build scroll confidence and decay pinch accumulator
          _scrollConfidence += moveDist;
          _pinchSpanAccum *= 0.5; // Rapid decay of finger separation tremor during scroll
          if (_scrollConfidence >= 6.0) {
            _isScrollingLocked = true;
          }
        } else if (spanDist >= moveDist * 0.7 && !_isScrollingLocked) {
          // Pinch motion dominates -> accumulate span change
          _pinchSpanAccum += deltaSpan;
          _scrollConfidence = 0.0;
        }
      }

      // 3. Pinch to Zoom (only if not locked into parallel scroll)
      if (pinchZoomEnabled && !_isScrollingLocked) {
        const pinchThreshold = 16.0;
        if (_pinchSpanAccum >= pinchThreshold) {
          final steps = (_pinchSpanAccum / pinchThreshold).floor();
          _pinchSpanAccum -= steps * pinchThreshold;
          _isPinching = true;
          _lastPinchSpan = currentSpan;
          HapticFeedback.selectionClick();
          return PhonePadPacket(
            opcode: Opcode.zoom,
            dx: 0,
            dy: steps, // Zoom In (spread/expand)
            flags: flags,
          );
        } else if (_pinchSpanAccum <= -pinchThreshold) {
          final steps = (_pinchSpanAccum.abs() / pinchThreshold).floor();
          _pinchSpanAccum += steps * pinchThreshold;
          _isPinching = true;
          _lastPinchSpan = currentSpan;
          HapticFeedback.selectionClick();
          return PhonePadPacket(
            opcode: Opcode.zoom,
            dx: 0,
            dy: -steps, // Zoom Out (squeeze/shrink)
            flags: flags,
          );
        }

        // If actively pinching, suppress scrolling
        if (_isPinching) {
          _lastPinchSpan = currentSpan;
          return null;
        }
      }
      _lastPinchSpan = currentSpan;

      // 2-Finger smooth scroll with velocity tracking for kinetic inertia
      final now = DateTime.now();
      if (_lastScrollTime != null) {
        final dtMs = now.difference(_lastScrollTime!).inMilliseconds;
        if (dtMs > 0 && dtMs <= 80) {
          final instantVx = (delta.dx / dtMs) * 1000.0;
          final instantVy = (delta.dy / dtMs) * 1000.0;
          _recentScrollVx = _recentScrollVx * 0.35 + instantVx * 0.65;
          _recentScrollVy = _recentScrollVy * 0.35 + instantVy * 0.65;
        } else {
          _recentScrollVx = 0.0;
          _recentScrollVy = 0.0;
        }
      }
      _lastScrollTime = now;

      int scrollDx = 0;
      int scrollDy = 0;
      int scrollFlags = flags;

      if (highResMode) {
        // High-resolution sub-pixel scroll streaming
        final rawDx = delta.dx * 8.0 + _scrollSubPixelDx;
        final rawDy = delta.dy * 8.0 + _scrollSubPixelDy;
        scrollDx = rawDx.round();
        scrollDy = rawDy.round();
        _scrollSubPixelDx = rawDx - scrollDx;
        _scrollSubPixelDy = rawDy - scrollDy;
        scrollFlags |= PhonePadPacket.flagHighRes;
      } else {
        // Standard sub-pixel scroll accumulator
        _scrollSubPixelDx += delta.dx;
        _scrollSubPixelDy += delta.dy;

        if (_scrollSubPixelDx.abs() >= 0.5) {
          scrollDx = _scrollSubPixelDx.round();
          _scrollSubPixelDx -= scrollDx;
        }
        if (_scrollSubPixelDy.abs() >= 0.5) {
          scrollDy = _scrollSubPixelDy.round();
          _scrollSubPixelDy -= scrollDy;
        }
      }

      if (scrollDx == 0 && scrollDy == 0) return null;

      return PhonePadPacket(
        opcode: Opcode.scroll,
        dx: scrollDx,
        dy: scrollDy,
        flags: scrollFlags,
      );
    } else if (count >= 3) {
      // 3-Finger drag -> System gesture (Laptop App switcher / Task View / Show Desktop)
      final primaryPointerId = _activePointers.keys.reduce((a, b) => a < b ? a : b);
      if (event.pointer != primaryPointerId) {
        return null;
      }
      final dx = delta.dx.round();
      final dy = delta.dy.round();
      if (dx == 0 && dy == 0) return null;

      return PhonePadPacket(
        opcode: Opcode.move,
        dx: dx,
        dy: dy,
        flags: 0x01 | (3 << 1),
      );
    }

    return null;
  }

  /// Handles finger lift event and classifies quick taps & drag releases.
  PhonePadPacket? onPointerUp(PointerUpEvent event) {
    _stopEdgeScroll();
    final point = _activePointers.remove(event.pointer);
    PhonePadPacket? result;

    if (_isDragLocked) {
      final wasDragging = _dragStartDispatched;
      _isDragLocked = false;
      _dragStartDispatched = false;
      _lastTapUpTime = null;
      _lastTapUpPosition = null;
      if (wasDragging) {
        // Real drag release: immediately send DragEnd
        return const PhonePadPacket(
          opcode: Opcode.dragEnd,
          flags: 0x00,
        );
      } else {
        // User tapped twice without moving: clean double click
        HapticFeedback.lightImpact();
        return const PhonePadPacket(
          opcode: Opcode.tapLeft,
          flags: 0x01 | (1 << 1) | 0x08,
        );
      }
    }

    if (point != null) {
      // Human tap tolerance: up to 280ms duration and 24.0px displacement
      final isQuickTap = point.contactDuration.inMilliseconds <= 280;
      final isSmallDisplacement = point.totalDisplacement <= 24.0;

      if (_maxPointersInSession == 2) {
        // 2-Finger touch session: check for Right Click tap
        if (!_twoFingerTapHandled && isQuickTap && isSmallDisplacement) {
          _twoFingerTapHandled = true;
          _lastTapUpTime = null;
          _lastTapUpPosition = null;
          HapticFeedback.mediumImpact();
          result = const PhonePadPacket(
            opcode: Opcode.tapRight,
            flags: 0x01 | (2 << 1) | 0x08,
          );
        } else {
          // Second finger of 2-finger tap or multi-finger move release:
          // NEVER emit tapLeft!
          _lastTapUpTime = null;
          _lastTapUpPosition = null;
        }
      } else if (_maxPointersInSession == 1 && isQuickTap && isSmallDisplacement) {
        // 1-Finger quick tap -> Left click + record timestamp for potential double-tap drag
        _lastTapUpTime = DateTime.now();
        _lastTapUpPosition = point.current;
        HapticFeedback.lightImpact();
        result = const PhonePadPacket(
          opcode: Opcode.tapLeft,
          flags: 0x01 | (1 << 1) | 0x08,
        );
      } else {
        // Regular long move lift is NOT a tap!
        _lastTapUpTime = null;
        _lastTapUpPosition = null;
      }
    }

    final wasPinching = _isPinching;
    final wasScrolling = _isScrollingLocked;
    final releaseVx = _recentScrollVx;
    final releaseVy = _recentScrollVy;

    if (_activePointers.length < 2) {
      _twoFingerAccumX = 0.0;
      _twoFingerAccumY = 0.0;
      _twoFingerSwiped = false;
      _lastPinchSpan = 0.0;
      _pinchSpanAccum = 0.0;
      _scrollConfidence = 0.0;
      _isScrollingLocked = false;
      _isPinching = false;
      _scrollSubPixelDx = 0.0;
      _scrollSubPixelDy = 0.0;
      _lastScrollTime = null;

      // Launch kinetic inertial scroll coasting if released with flick velocity
      if (wasScrolling && !wasPinching && (releaseVx.abs() >= 140.0 || releaseVy.abs() >= 140.0)) {
        _startScrollInertia(releaseVx, releaseVy);
      }

      if (wasPinching && result == null) {
        result = const PhonePadPacket(
          opcode: Opcode.zoom,
          dx: 0,
          dy: 0,
          flags: 0x00,
        );
      }
    }

    // If all fingers lifted, transmit lift packet to reset host accumulators
    if (_activePointers.isEmpty) {
      _subPixelDx = 0.0;
      _subPixelDy = 0.0;
      _scrollSubPixelDx = 0.0;
      _scrollSubPixelDy = 0.0;
      _maxPointersInSession = 0;
      _twoFingerTapHandled = false;
      _lastPinchSpan = 0.0;
      _pinchSpanAccum = 0.0;
      _scrollConfidence = 0.0;
      _isScrollingLocked = false;
      _isPinching = false;
      result ??= const PhonePadPacket(
        opcode: Opcode.move,
        dx: 0,
        dy: 0,
        flags: 0x00, // Touch inactive
      );
    }

    return result;
  }

  /// Handles cancel (system interrupt, palm rejection).
  PhonePadPacket? onPointerCancel(PointerCancelEvent event) {
    _stopEdgeScroll();
    _stopScrollInertia();
    final wasPinching = _isPinching;
    _isDragLocked = false;
    _dragStartDispatched = false;
    _lastTapUpTime = null;
    _lastTapUpPosition = null;
    _subPixelDx = 0.0;
    _subPixelDy = 0.0;
    _scrollSubPixelDx = 0.0;
    _scrollSubPixelDy = 0.0;
    _twoFingerAccumX = 0.0;
    _twoFingerAccumY = 0.0;
    _twoFingerSwiped = false;
    _lastPinchSpan = 0.0;
    _pinchSpanAccum = 0.0;
    _scrollConfidence = 0.0;
    _isScrollingLocked = false;
    _isPinching = false;
    _maxPointersInSession = 0;
    _twoFingerTapHandled = false;
    _activePointers.remove(event.pointer);
    if (_activePointers.isEmpty) {
      if (wasPinching) {
        return const PhonePadPacket(
          opcode: Opcode.zoom,
          dx: 0,
          dy: 0,
          flags: 0x00,
        );
      }
      return const PhonePadPacket(
        opcode: Opcode.move,
        dx: 0,
        dy: 0,
        flags: 0x00,
      );
    } else if (wasPinching) {
      return const PhonePadPacket(
        opcode: Opcode.zoom,
        dx: 0,
        dy: 0,
        flags: 0x00,
      );
    }
    return null;
  }

  /// Evaluates trackpad boundary auto-scrolling while in DragLock.
  void _checkEdgeScroll(Offset localPos) {
    if (!_isDragLocked || surfaceSize.width <= 100 || surfaceSize.height <= 100) {
      _stopEdgeScroll();
      return;
    }

    const margin = 42.0;
    final inBottom = localPos.dy >= surfaceSize.height - margin;
    final inTop = localPos.dy <= margin;
    final inRight = localPos.dx >= surfaceSize.width - margin;
    final inLeft = localPos.dx <= margin;

    if (!inBottom && !inTop && !inRight && !inLeft) {
      _stopEdgeScroll();
      return;
    }

    // Active in edge zone -> start or maintain edge scroll ticker
    _edgeScrollTimer ??= Timer.periodic(const Duration(milliseconds: 35), (timer) {
      if (!_isDragLocked || _activePointers.isEmpty) {
        _stopEdgeScroll();
        return;
      }

      final pt = _activePointers.values.first;
      final pos = pt.current;
      int scrollDx = 0;
      int scrollDy = 0;

      if (pos.dy >= surfaceSize.height - margin) {
        final depth = ((pos.dy - (surfaceSize.height - margin)) / margin).clamp(0.2, 1.0);
        scrollDy = (depth * -22.0).round(); // Scroll down
      } else if (pos.dy <= margin) {
        final depth = ((margin - pos.dy) / margin).clamp(0.2, 1.0);
        scrollDy = (depth * 22.0).round(); // Scroll up
      }

      if (pos.dx >= surfaceSize.width - margin) {
        final depth = ((pos.dx - (surfaceSize.width - margin)) / margin).clamp(0.2, 1.0);
        scrollDx = (depth * -18.0).round(); // Scroll right
      } else if (pos.dx <= margin) {
        final depth = ((margin - pos.dx) / margin).clamp(0.2, 1.0);
        scrollDx = (depth * 18.0).round(); // Scroll left
      }

      if (rotateCoordinates) {
        final temp = scrollDx;
        scrollDx = scrollDy;
        scrollDy = -temp;
      }

      if (scrollDx != 0 || scrollDy != 0) {
        final packet = PhonePadPacket(
          opcode: Opcode.scroll,
          dx: scrollDx,
          dy: scrollDy,
          flags: 0x01 | (1 << 1) | PhonePadPacket.flagHighRes,
        );
        onEdgeScroll?.call(packet);
      }
    });
  }

  void _startScrollInertia(double initialVx, double initialVy) {
    _scrollInertiaTimer?.cancel();
    double vx = initialVx.clamp(-2500.0, 2500.0);
    double vy = initialVy.clamp(-2500.0, 2500.0);

    _scrollInertiaTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      // Natural kinetic friction decay (~0.92 per frame -> smooth coasting for ~350-450ms)
      vx *= 0.92;
      vy *= 0.92;

      if (vx.abs() < 10.0 && vy.abs() < 10.0) {
        _stopScrollInertia();
        return;
      }

      final tickDx = vx * 0.016;
      final tickDy = vy * 0.016;

      int sendDx = 0;
      int sendDy = 0;
      int packetFlags = 0x01 | (2 << 1);

      if (highResMode) {
        final rawDx = tickDx * 8.0 + _scrollSubPixelDx;
        final rawDy = tickDy * 8.0 + _scrollSubPixelDy;
        sendDx = rawDx.round();
        sendDy = rawDy.round();
        _scrollSubPixelDx = rawDx - sendDx;
        _scrollSubPixelDy = rawDy - sendDy;
        packetFlags |= PhonePadPacket.flagHighRes;
      } else {
        _scrollSubPixelDx += tickDx;
        _scrollSubPixelDy += tickDy;
        if (_scrollSubPixelDx.abs() >= 0.5) {
          sendDx = _scrollSubPixelDx.round();
          _scrollSubPixelDx -= sendDx;
        }
        if (_scrollSubPixelDy.abs() >= 0.5) {
          sendDy = _scrollSubPixelDy.round();
          _scrollSubPixelDy -= sendDy;
        }
      }

      if (sendDx != 0 || sendDy != 0) {
        final packet = PhonePadPacket(
          opcode: Opcode.scroll,
          dx: sendDx,
          dy: sendDy,
          flags: packetFlags,
        );
        onInertialScroll?.call(packet);
        onEdgeScroll?.call(packet);
      }
    });
  }

  void _stopScrollInertia() {
    _scrollInertiaTimer?.cancel();
    _scrollInertiaTimer = null;
    _recentScrollVx = 0.0;
    _recentScrollVy = 0.0;
    _lastScrollTime = null;
  }

  void _stopEdgeScroll() {
    _edgeScrollTimer?.cancel();
    _edgeScrollTimer = null;
  }

  void dispose() {
    _stopEdgeScroll();
    _stopScrollInertia();
  }
}
