import 'dart:async';
import 'package:flutter/foundation.dart';

/// Power and screen governor optimizing AMOLED battery life.
class PowerGovernor extends ChangeNotifier {
  final Duration idleThreshold;
  DateTime _lastActiveTime = DateTime.now();
  bool _isDimmed = false;
  Timer? _checkTimer;

  PowerGovernor({
    this.idleThreshold = const Duration(seconds: 15),
  }) {
    _startTimer();
  }

  bool get isDimmed => _isDimmed;

  void _startTimer() {
    _checkTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      final elapsed = DateTime.now().difference(_lastActiveTime);
      if (elapsed >= idleThreshold && !_isDimmed) {
        _isDimmed = true;
        notifyListeners();
      }
    });
  }

  /// Registers user touch interaction, instantly restoring full screen luminance in 0ms.
  void recordActivity() {
    _lastActiveTime = DateTime.now();
    if (_isDimmed) {
      _isDimmed = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _checkTimer?.cancel();
    super.dispose();
  }
}
