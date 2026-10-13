import 'package:flutter/material.dart';

/// Represents an active pointer touching the digitizer.
class TouchPoint {
  final int pointerId;
  Offset current;
  Offset previous;
  final Offset start;
  final DateTime startTime;

  TouchPoint({
    required this.pointerId,
    required this.current,
    required this.startTime,
  })  : previous = current,
        start = current;

  void update(Offset newPosition) {
    previous = current;
    current = newPosition;
  }

  Offset get delta => current - previous;

  double get totalDisplacement => (current - start).distance;

  Duration get contactDuration => DateTime.now().difference(startTime);
}
