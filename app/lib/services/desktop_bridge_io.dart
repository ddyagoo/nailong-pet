import 'dart:io';

import 'package:flutter/material.dart';

import 'desktop_shell.dart';

/// 非 web 平台上的桥接。
///
/// - Android：全部空实现（悬浮窗走 Kotlin）
/// - Windows：转发给 [DesktopShell]（原生窗口 / 托盘 / 检查更新）
class DesktopBridge {
  static bool get active => Platform.isWindows && DesktopShell.isWindows;

  static void dragStart() {
    if (active) DesktopShell.instance.dragStart();
  }

  static void dragEnd() {
    if (active) DesktopShell.instance.dragEnd();
  }

  /// 原生是单窗口：气泡画在窗口内，不需要改窗口尺寸。
  static void reserveBubble(bool visible) {}

  static void menu() {
    if (active) DesktopShell.instance.popUpMenu();
  }

  /// 上报「奶龙 + 气泡」在窗口里的范围，用来做点击穿透。
  static void reportHitArea(Rect? rect) {
    if (active) DesktopShell.instance.setHitArea(rect);
  }

  /// 打开设置/对话框时整窗可点。
  static void setInteractive(bool value) {
    if (active) DesktopShell.instance.setInteractive(value);
  }
}
