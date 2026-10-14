/// Virtual Numpad key representations and their protocol codes.
enum NumpadKey {
  num0(0, '0'),
  num1(1, '1'),
  num2(2, '2'),
  num3(3, '3'),
  num4(4, '4'),
  num5(5, '5'),
  num6(6, '6'),
  num7(7, '7'),
  num8(8, '8'),
  num9(9, '9'),
  add(10, '+'),
  subtract(11, '-'),
  multiply(12, '×'),
  divide(13, '÷'),
  enter(14, 'ENT'),
  backspace(15, '⌫'),
  decimal(16, '.');

  final int code;
  final String label;

  const NumpadKey(this.code, this.label);
}

/// Media and Presentation Remote keys.
enum MediaKey {
  playPause(1, 'Play/Pause'),
  volumeUp(2, 'Vol +'),
  volumeDown(3, 'Vol -'),
  mute(4, 'Mute'),
  nextSlide(5, 'Next Slide'),
  prevSlide(6, 'Prev Slide'),
  navBack(7, 'Back'),
  navForward(8, 'Forward');

  final int code;
  final String label;

  const MediaKey(this.code, this.label);
}

/// Virtual Keyboard packet event types matching Rust protocol.
abstract class KeyboardKeyType {
  static const int unicodeChar = 0;
  static const int specialKey = 1;
  static const int shortcut = 2;
}

/// Special Virtual Keys with specific Win32 handling.
enum SpecialKey {
  backspace(1, '⌫'),
  enter(2, 'Enter'),
  tab(3, 'Tab'),
  escape(4, 'Esc'),
  delete(5, 'Del'),
  arrowUp(6, '▲'),
  arrowDown(7, '▼'),
  arrowLeft(8, '◄'),
  arrowRight(9, '►'),
  home(10, 'Home'),
  end(11, 'End'),
  pageUp(12, 'PgUp'),
  pageDown(13, 'PgDn'),
  space(14, 'Space');

  final int code;
  final String label;

  const SpecialKey(this.code, this.label);
}

/// Keyboard shortcuts sent as Ctrl + key.
enum ShortcutKey {
  selectAll(1, 'Select All', 'Ctrl+A'),
  copy(2, 'Copy', 'Ctrl+C'),
  paste(3, 'Paste', 'Ctrl+V'),
  cut(4, 'Cut', 'Ctrl+X'),
  undo(5, 'Undo', 'Ctrl+Z'),
  redo(6, 'Redo', 'Ctrl+Y'),
  save(7, 'Save', 'Ctrl+S');

  final int code;
  final String label;
  final String combo;

  const ShortcutKey(this.code, this.label, this.combo);
}
