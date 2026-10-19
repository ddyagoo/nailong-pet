import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart' as acrylic;
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'native_win32.dart';
import 'update_service.dart';

/// Windows 原生外壳：无边框、置顶、透明、点击穿透、托盘。
///
/// 和 Electron 那版最大的区别：窗口尺寸**永远不变**，气泡画在窗口里，
/// 所以不会再有「气泡一出来奶龙跟着跳」的问题。
class DesktopShell with TrayListener, WindowListener {
  DesktopShell._();

  static final DesktopShell instance = DesktopShell._();

  static bool get isWindows => Platform.isWindows;

  /// 窗口逻辑尺寸：够放下奶龙和它头上的气泡。
  static const Size windowSize = Size(420, 820);

  /// 窗口标题同时用来找 HWND，别改。
  static const String windowTitle = 'nailong_pet';

  final navigatorKey = GlobalKey<NavigatorState>();

  int _hwnd = 0;
  Rect? _hitArea;
  bool _clickThrough = false;
  bool _held = false;
  Timer? _poll;

  /// PetLayer 布局后上报：奶龙 + 气泡在窗口坐标系里的范围。
  void setHitArea(Rect? rect) => _hitArea = rect;

  /// 打开设置/对话框时临时要求可点击（这些界面比奶龙大）。
  void setInteractive(bool value) {
    _held = value;
    if (value) _applyClickThrough(through: false);
  }

  Future<void> init() async {
    await windowManager.ensureInitialized();

    const options = WindowOptions(
      size: windowSize,
      backgroundColor: Colors.transparent,
      skipTaskbar: true,
      alwaysOnTop: true,
      title: windowTitle,
      titleBarStyle: TitleBarStyle.hidden,
    );

    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.setAsFrameless();
      await windowManager.setAlwaysOnTop(true);
      await windowManager.setSkipTaskbar(true);
      await windowManager.setResizable(false);
      await windowManager.setHasShadow(false);
      await windowManager.setMinimumSize(windowSize);
      await windowManager.setMaximumSize(windowSize);

      await acrylic.Window.initialize();
      await acrylic.Window.setEffect(
        effect: acrylic.WindowEffect.transparent,
        dark: false,
      );

      await _restorePosition();
      await windowManager.show();
      await windowManager.setIgnoreMouseEvents(false);
    });

    windowManager.addListener(this);
    _hwnd = _findWindowHandle();
    _poll = Timer.periodic(const Duration(milliseconds: 80), (_) => _tick());
    await _setupTray();
  }

  // ---------------- 位置 ----------------

  String get _posFile {
    final base = Platform.environment['LOCALAPPDATA'] ??
        Platform.environment['TEMP'] ??
        '.';
    return '$base\\NailongPet\\window.txt';
  }

  Future<void> _restorePosition() async {
    final (screenW, screenH) = Win32.screenSize();
    final right = screenW - windowSize.width - 24;
    final bottom = screenH - windowSize.height - 48;

    var target = Offset(right, bottom);
    try {
      final f = File(_posFile);
      if (f.existsSync()) {
        final parts = f.readAsStringSync().split(',');
        if (parts.length == 2) {
          final x = double.tryParse(parts[0].trim());
          final y = double.tryParse(parts[1].trim());
          if (x != null && y != null) target = Offset(x, y);
        }
      }
    } catch (_) {}
    await windowManager.setPosition(target);
  }

  void _savePosition() {
    try {
      final pos = _lastPos;
      if (pos == null) return;
      final f = File(_posFile);
      f.parent.createSync(recursive: true);
      f.writeAsStringSync('${pos.dx.round()},${pos.dy.round()}');
    } catch (_) {}
  }

  Offset? _lastPos;

  // ---------------- 拖动 ----------------

  Future<void> dragStart() async {
    _savePosition();
    await windowManager.startDragging();
    final pos = await windowManager.getPosition();
    _lastPos = pos;
    _savePosition();
  }

  Future<void> dragEnd() async {
    _lastPos = await windowManager.getPosition();
    _savePosition();
  }

  // ---------------- 点击穿透 ----------------

  int _findWindowHandle() => Win32.findWindow(windowTitle);

  void _tick() {
    if (_held) return;
    final hwnd = _hwnd;
    final area = _hitArea;
    if (hwnd == 0 || area == null) return;

    final cursor = Win32.cursorPos();
    final rect = Win32.windowRect(hwnd);
    if (cursor == null || rect == null) return;

    final local = Offset(
      (cursor.$1 - rect.$1).toDouble(),
      (cursor.$2 - rect.$2).toDouble(),
    );
    final inside = area.contains(local);
    if (inside == !_clickThrough) return;
    _applyClickThrough(through: !inside);
  }

  void _applyClickThrough({required bool through}) {
    Win32.setClickThrough(_hwnd, through);
    _clickThrough = through;
  }

  // ---------------- 托盘 ----------------

  Future<void> _setupTray() async {
    trayManager.addListener(this);
    final icon = _trayIconPath();
    if (icon != null) await trayManager.setIcon(icon);
    await trayManager.setToolTip('奶龙桌宠');
    await trayManager.setContextMenu(Menu(items: [
      MenuItem(key: 'toggle', label: '显示 / 隐藏奶龙'),
      MenuItem(key: 'check', label: '检查更新…'),
      MenuItem.separator(),
      MenuItem(key: 'quit', label: '退出'),
    ]));
  }

  String? _trayIconPath() {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final path = '$exeDir\\data\\flutter_assets\\assets\\icons\\app_icon.ico';
    return File(path).existsSync() ? path : null;
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'toggle':
        _toggleVisible();
        break;
      case 'check':
        _checkUpdateInteractive();
        break;
      case 'quit':
        quit();
        break;
    }
  }

  /// 右键奶龙时弹出同一份托盘菜单。
  Future<void> popUpMenu() async {
    setInteractive(true);
    await trayManager.popUpContextMenu();
    setInteractive(false);
  }

  Future<void> _toggleVisible() async {
    if (await windowManager.isVisible()) {
      await windowManager.hide();
    } else {
      await windowManager.show();
    }
  }

  // ---------------- 检查更新 ----------------

  Future<void> _checkUpdateInteractive() async {
    setInteractive(true);
    final info = await UpdateService.check();
    await windowManager.show();
    // show() 是 await，之后必须重新取 context 并确认还挂着
    final ctx = navigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) {
      setInteractive(false);
      return;
    }

    final title = switch (info) {
      null => '检查更新失败',
      _ when info.hasUpdate => '发现新版本 ${info.tag}',
      _ => '已经是最新版本',
    };
    final body = switch (info) {
      null => '网络不通，过会儿再试。',
      _ when info.hasUpdate =>
        info.notes.isEmpty ? '去 GitHub 下载新版本？' : info.notes,
      _ => '当前版本 ${info.current}。',
    };

    await showDialog<void>(
      context: ctx,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Text(body, style: const TextStyle(fontSize: 13)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(),
            child: const Text('知道了'),
          ),
          if (info != null && info.hasUpdate)
            FilledButton(
              onPressed: () {
                Navigator.of(c).pop();
                UpdateService.openReleasePage(info);
              },
              child: const Text('去 GitHub 下载'),
            ),
        ],
      ),
    );
    setInteractive(false);
  }

  Future<void> checkUpdateSilently() async {
    final info = await UpdateService.check();
    if (info == null || !info.hasUpdate) return;
    await _checkUpdateInteractive();
  }

  // ---------------- 生命周期 ----------------

  @override
  void onWindowMoved() {
    windowManager.getPosition().then((pos) {
      _lastPos = pos;
      _savePosition();
    });
  }

  Future<void> quit() async {
    _savePosition();
    trayManager.removeListener(this);
    windowManager.removeListener(this);
    _poll?.cancel();
    await windowManager.destroy();
  }
}
