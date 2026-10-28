/// يفتح قسماً من الشريط الجانبي دون استيراد دائري مع لوحة اليوم.
class ShellNav {
  static void Function(int index)? goTo;

  static void open(int index) => goTo?.call(index);
}

