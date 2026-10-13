import 'package:flutter/material.dart';

/// Available input surface modes for PhonePad.
enum SurfaceMode {
  trackpad('Trackpad', Icons.mouse_rounded),
  numpad('Numpad', Icons.dialpad_rounded),
  remote('Remote', Icons.slideshow_rounded);

  final String title;
  final IconData icon;

  const SurfaceMode(this.title, this.icon);
}
