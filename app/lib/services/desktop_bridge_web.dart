import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// 这几个函数由 Electron 的 preload.js 注入到 window 上。
@JS('desktopDragStart')
external void _dragStart();

@JS('desktopDragEnd')
external void _dragEnd();

@JS('desktopReserveBubble')
external void _reserveBubble(bool visible);

@JS('desktopMenu')
external void _desktopMenu();

/// Windows 版把奶龙放在一个透明置顶窗口里：拖动移动整个窗口，
/// 气泡弹出时让窗口向上长高，右键弹原生菜单。
class DesktopBridge {
  static bool get active =>
      kIsWeb && Uri.base.queryParameters['desktop'] == '1';

  static void dragStart() {
    if (active) _dragStart();
  }

  static void dragEnd() {
    if (active) _dragEnd();
  }

  static void reserveBubble(bool visible) {
    if (active) _reserveBubble(visible);
  }

  static void menu() {
    if (active) _desktopMenu();
  }

  static void reportHitAreas(List<Rect> rects) {}

  static void setInteractive(bool value) {}
}
