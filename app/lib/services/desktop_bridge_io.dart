/// 非 web 平台上的空实现（Android 走原生悬浮窗，不需要这个）。
class DesktopBridge {
  static bool get active => false;

  static void dragStart() {}

  static void dragEnd() {}

  static void reserveBubble(bool visible) {}

  static void menu() {}
}
