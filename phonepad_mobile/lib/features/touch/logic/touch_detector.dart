import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import '../../../core/protocol/opcode.dart';
import '../../../core/protocol/packet.dart';
import '../models/touch_point.dart';

class TouchDetector {
  final Map<int, TouchPoint> _activePointers = {};
  int _lastPointerCount = 0;

  DateTime? _lastTapUpTime;
  Offset? _lastTapUpPosition;
  bool _isDragLocked = false;

  // Sub-pixel delta accumulator for microscopic finger movements
  double _subPixelDx = 0.0;
  double _subPixelDy = 0.0;

  // 2-Finger navigation swipe state (Browser Back / Forward)
  double _twoFingerAccumX = 0.0;
  double _twoFingerAccumY = 0.0;
  bool _twoFingerSwiped = false;
  bool twoFingerNavEnabled = true;

  Map<int, TouchPoint> get activePointers => _activePointers;
  int get pointerCount => _activePointers.length;
  bool get isDragLocked => _isDragLocked;

  /// Handles finger down event.
  PhonePadPacket? onPointerDown(PointerDownEvent event) {
    // Check if this finger-down is part of a double-tap-and-hold (Drag Lock)
    PhonePadPacket? dragStartPacket;
    if (_activePointers.isEmpty && _lastTapUpTime != null) {
      final timeSinceTap = DateTime.now().difference(_lastTapUpTime!).inMilliseconds;
      final dist = _lastTapUpPosition != null
          ? (event.localPosition - _lastTapUpPosition!).distance
          : 999.0;

      if (timeSinceTap <= 300 && dist <= 36.0) {
        _isDragLocked = true;
        _lastTapUpTime = null;
        HapticFeedback.mediumImpact();
        dragStartPacket = const PhonePadPacket(
          opcode: Opcode.dragStart,
          flags: 0x01 | (1 << 1),
        );
      }
    }

    _activePointers[event.pointer] = TouchPoint(
      pointerId: event.pointer,
      current: event.localPosition,
      startTime: DateTime.now(),
    );

    if (_activePointers.length == 3) {
      HapticFeedback.selectionClick();
    } else if (_activePointers.length == 2) {
      _twoFingerAccumX = 0.0;
      _twoFingerAccumY = 0.0;
      _twoFingerSwiped = false;
    }

    _lastPointerCount = _activePointers.length;
    return dragStartPacket;
  }

  /// Handles continuous finger motion.
  PhonePadPacket? onPointerMove(PointerMoveEvent event) {
    final point = _activePointers[event.pointer];
    if (point == null) return null;

    point.update(event.localPosition);
    final delta = point.delta;

    final count = _activePointers.length;
    final flags = 0x01 | ((count & 0x03) << 1);

    if (count == 1) {
      // 1-Finger drag -> cursor move with sub-pixel accumulator
      // Catches micro-movements (0.1px - 0.4px) without dropping fractional deltas
      _subPixelDx += delta.dx;
      _subPixelDy += delta.dy;

      int sendDx = 0;
      int sendDy = 0;

      if (_subPixelDx.abs() >= 0.5) {
        sendDx = _subPixelDx.round();
        _subPixelDx -= sendDx;
      }
      if (_subPixelDy.abs() >= 0.5) {
        sendDy = _subPixelDy.round();
        _subPixelDy -= sendDy;
      }

      if (sendDx == 0 && sendDy == 0) return null;

      return PhonePadPacket(
        opcode: Opcode.move,
        dx: sendDx,
        dy: sendDy,
        flags: flags,
      );
    } else if (count == 2) {
      // 2-Finger gesture
      final primaryPointerId = _activePointers.keys.reduce((a, b) => a < b ? a : b);
      if (event.pointer != primaryPointerId) {
        return null;
      }

      _twoFingerAccumX += delta.dx;
      _twoFingerAccumY += delta.dy;

      // Detect deliberate 2-finger horizontal swipe for Browser Back / Forward
      if (twoFingerNavEnabled && !_twoFingerSwiped) {
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

      // If swipe gesture fired, suppress scroll until fingers lift
      if (_twoFingerSwiped) {
        return null;
      }

      // Regular 2-Finger scroll
      final dx = delta.dx.round();
      final dy = delta.dy.round();

      if (dx == 0 && dy == 0) return null;

      return PhonePadPacket(
        opcode: Opcode.scroll,
        dx: dx,
        dy: dy,
        flags: flags,
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
      // Drag Lock release: immediately send DragEnd
      _isDragLocked = false;
      _lastTapUpTime = null;
      _lastTapUpPosition = null;
      _lastPointerCount = _activePointers.length;
      return const PhonePadPacket(
        opcode: Opcode.dragEnd,
        flags: 0x00,
      );
    }

    if (point != null) {
      // Human tap tolerance: up to 260ms duration and 24.0px displacement
      final isQuickTap = point.contactDuration.inMilliseconds <= 260;
      final isSmallDisplacement = point.totalDisplacement <= 24.0;

      if (_lastPointerCount == 1 && isQuickTap && isSmallDisplacement) {
        // 1-Finger quick tap -> Left click + record timestamp for potential double-tap drag
        _lastTapUpTime = DateTime.now();
        _lastTapUpPosition = point.current;
        HapticFeedback.lightImpact();
        result = const PhonePadPacket(
          opcode: Opcode.tapLeft,
          flags: 0x01 | (1 << 1) | 0x08,
        );
      } else if (_lastPointerCount == 2 && isQuickTap && isSmallDisplacement) {
        // 2-Finger quick tap -> Right click
        _lastTapUpTime = null;
        _lastTapUpPosition = null;
        HapticFeedback.mediumImpact();
        result = const PhonePadPacket(
          opcode: Opcode.tapRight,
          flags: 0x01 | (2 << 1) | 0x08,
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
    }

    // If all fingers lifted, transmit lift packet to reset host accumulators
    if (_activePointers.isEmpty) {
      _subPixelDx = 0.0;
      _subPixelDy = 0.0;
      _lastPointerCount = 0;
      result ??= const PhonePadPacket(
        opcode: Opcode.move,
        dx: 0,
        dy: 0,
        flags: 0x00, // Touch inactive
      );
    } else {
      _lastPointerCount = _activePointers.length;
    }

    return result;
  }

  /// Handles cancel (system interrupt, palm rejection).
  PhonePadPacket? onPointerCancel(PointerCancelEvent event) {
    _isDragLocked = false;
    _lastTapUpTime = null;
    _lastTapUpPosition = null;
    _subPixelDx = 0.0;
    _subPixelDy = 0.0;
    _twoFingerAccumX = 0.0;
    _twoFingerAccumY = 0.0;
    _twoFingerSwiped = false;
    _activePointers.remove(event.pointer);
    if (_activePointers.isEmpty) {
      _lastPointerCount = 0;
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
