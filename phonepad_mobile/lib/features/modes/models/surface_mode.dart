import 'package:flutter/material.dart';

/// Available input surface modes for PhonePad.
enum SurfaceMode {
  trackpad('Trackpad', Icons.mouse_rounded),
  keyboard('Keyboard', Icons.keyboard_rounded),
  remote('Remote', Icons.settings_remote_rounded);

  final String title;
  final IconData icon;

  const SurfaceMode(this.title, this.icon);
}
