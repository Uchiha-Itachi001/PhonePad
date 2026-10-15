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

  // 2-Finger Pinch to Zoom state
  double _lastPinchSpan = 0.0;
  double _pinchSpanAccum = 0.0;
  bool _isPinching = false;
  bool pinchZoomEnabled = true;

  // 90-degree coordinate rotation for simulated horizontal mode
  bool rotateCoordinates = false;

  Map<int, TouchPoint> get activePointers => _activePointers;
  int get pointerCount => _activePointers.length;
  bool get isDragLocked => _isDragLocked;

  /// Handles finger down event.
  PhonePadPacket? onPointerDown(PointerDownEvent event) {
    if (_activePointers.isEmpty) {
      _subPixelDx = 0.0;
      _subPixelDy = 0.0;
      _scrollSubPixelDx = 0.0;
      _scrollSubPixelDy = 0.0;
      _maxPointersInSession = 0;
      _twoFingerTapHandled = false;
      _pinchSpanAccum = 0.0;
      _isPinching = false;
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
      if (twoFingerNavEnabled && !_twoFingerSwiped && !_isPinching) {
        final absX = _twoFingerAccumX.abs();
        final absY = _twoFingerAccumY.abs();

        if (absX >= 36.0 && absX >= absY * 1.5) {
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

      // 2. Pinch to Zoom (squeeze / shrink vs spread)
      final currentSpan = (p1.current - p2.current).distance;
      if (_lastPinchSpan > 0) {
        final deltaSpan = currentSpan - _lastPinchSpan;
        if (pinchZoomEnabled) {
          _pinchSpanAccum += deltaSpan;

          const pinchThreshold = 14.0;
          if (_pinchSpanAccum >= pinchThreshold) {
            _pinchSpanAccum -= pinchThreshold;
            _isPinching = true;
            HapticFeedback.selectionClick();
            _lastPinchSpan = currentSpan;
            return PhonePadPacket(
              opcode: Opcode.zoom,
              dx: 0,
              dy: 1, // Zoom In (spread/expand)
              flags: flags,
            );
          } else if (_pinchSpanAccum <= -pinchThreshold) {
            _pinchSpanAccum += pinchThreshold;
            _isPinching = true;
            HapticFeedback.selectionClick();
            _lastPinchSpan = currentSpan;
            return PhonePadPacket(
              opcode: Opcode.zoom,
              dx: 0,
              dy: -1, // Zoom Out (squeeze/shrink)
              flags: flags,
            );
          }

          // If actively pinching, suppress scrolling
          if (_isPinching) {
            _lastPinchSpan = currentSpan;
            return null;
          }
        }
      }
      _lastPinchSpan = currentSpan;

      // 2-Finger smooth scroll
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

    if (_activePointers.length < 2) {
      _twoFingerAccumX = 0.0;
      _twoFingerAccumY = 0.0;
      _twoFingerSwiped = false;
      _lastPinchSpan = 0.0;
      _pinchSpanAccum = 0.0;
      _isPinching = false;
      _scrollSubPixelDx = 0.0;
      _scrollSubPixelDy = 0.0;
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
    _isPinching = false;
    _maxPointersInSession = 0;
    _twoFingerTapHandled = false;
    _activePointers.remove(event.pointer);
    if (_activePointers.isEmpty) {
      return const PhonePadPacket(
        opcode: Opcode.move,
        dx: 0,
        dy: 0,
        flags: 0x00,
      );
    }
    return null;
  }
}
