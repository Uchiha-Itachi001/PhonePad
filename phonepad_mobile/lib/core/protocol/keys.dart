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
