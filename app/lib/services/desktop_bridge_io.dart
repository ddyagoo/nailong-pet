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

  /// 上报可点击区域（窗口坐标，逻辑像素）。传多个矩形就是不规则区域。
  static void reportHitAreas(List<Rect> rects) {
    if (active) DesktopShell.instance.setHitAreas(rects);
  }

  /// 打开设置/对话框时整窗可点。
  static void setInteractive(bool value) {
    if (active) DesktopShell.instance.setInteractive(value);
  }
}
