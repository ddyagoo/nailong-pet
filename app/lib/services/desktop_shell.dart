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

  /// 窗口逻辑尺寸：够放下奶龙 + 头顶气泡，又能在 125% 缩放的 768 高屏幕上放得下。
  static const Size windowSize = Size(420, 660);

  /// 窗口标题同时用来找 HWND，别改。
  static const String windowTitle = 'nailong_pet';

  final navigatorKey = GlobalKey<NavigatorState>();

  int _hwnd = 0;
  List<Rect>? _hitAreas;
  bool _held = false;

  /// PetLayer 布局后上报：可点击区域（窗口坐标，逻辑像素）。
  ///
  /// 奶龙待机时传的是「剪影列矩形」，所以两侧透明区也能点穿；气泡另算一块。
  /// Windows 侧用 SetWindowRgn 把窗口裁成这些矩形的并集。
  void setHitAreas(List<Rect> rects) {
    if (_sameAreas(rects)) return;
    _hitAreas = List<Rect>.from(rects);
    _applyRegion();
  }

  bool _sameAreas(List<Rect> rects) {
    final old = _hitAreas;
    if (old == null || old.length != rects.length) return false;
    for (var i = 0; i < rects.length; i++) {
      if (old[i] != rects[i]) return false;
    }
    return true;
  }

  /// 打开设置/对话框时临时要求整窗可点（这些界面比奶龙大）。
  void setInteractive(bool value) {
    _held = value;
    _applyRegion();
  }

  /// 按「整窗」或「奶龙剪影 ∪ 气泡」裁剪窗口区域。
  void _applyRegion() {
    if (_hwnd == 0) return;
    final (w, h) = Win32.windowSize(_hwnd);
    if (w <= 0 || h <= 0) return;

    final rects = _hitAreas;
    if (_held || rects == null || rects.isEmpty) {
      Win32.setRegionRects(_hwnd, [
        [0, 0, w, h]
      ]);
      return;
    }

    final dpr = _devicePixelRatio;
    final converted = <List<int>>[];
    for (final r in rects) {
      final left = (r.left * dpr).round().clamp(0, w);
      final top = (r.top * dpr).round().clamp(0, h);
      final right = (r.right * dpr).round().clamp(0, w);
      final bottom = (r.bottom * dpr).round().clamp(0, h);
      if (right - left >= 1 && bottom - top >= 1) {
        converted.add([left, top, right, bottom]);
      }
    }
    if (converted.isEmpty) {
      Win32.setRegionRects(_hwnd, [
        [0, 0, w, h]
      ]);
      return;
    }
    Win32.setRegionRects(_hwnd, converted);
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
    _ensureOnScreen();
    _applyRegion();
    await _setupTray();
  }

  // ---------------- 位置 ----------------

  String get _posFile {
    final base = Platform.environment['LOCALAPPDATA'] ??
        Platform.environment['TEMP'] ??
        '.';
    return '$base\\NailongPet\\window.txt';
  }

  double get _devicePixelRatio {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty) return 1.0;
    return views.first.devicePixelRatio;
  }

  /// 逻辑像素的**屏幕**尺寸。
  ///
  /// 注意：`FlutterView.physicalSize` 是窗口尺寸，不是屏幕尺寸，拿它当屏幕会把
  /// 位置夹成 0,0；这里用 GetSystemMetrics 的物理像素除以缩放比。
  Size get _logicalScreen {
    final dpr = _devicePixelRatio;
    final (w, h) = Win32.screenSize();
    if (w <= 0 || h <= 0) return const Size(1280, 720);
    return Size(w / dpr, h / dpr);
  }

  Future<void> _restorePosition() async {
    // window_manager 的位置/尺寸都是逻辑像素；有记录就按记录，但必须夹回屏幕内
    //（换分辨率/缩放比例后，旧坐标会把窗口丢到屏幕外）。
    final screen = _logicalScreen;
    try {
      final f = File(_posFile);
      if (f.existsSync()) {
        final parts = f.readAsStringSync().split(',');
        if (parts.length == 2) {
          final x = double.tryParse(parts[0].trim());
          final y = double.tryParse(parts[1].trim());
          if (x != null && y != null) {
            final maxX = screen.width - windowSize.width;
            final maxY = screen.height - windowSize.height;
            final clamped = Offset(
              x.clamp(0.0, maxX < 0 ? 0.0 : maxX),
              y.clamp(0.0, maxY < 0 ? 0.0 : maxY),
            );
            await windowManager.setPosition(clamped);
            return;
          }
        }
      }
    } catch (_) {}
    await windowManager.setAlignment(Alignment.bottomRight);
  }

  /// 兜底：万一窗口已经跑到屏幕外，拉回右下角。
  void _ensureOnScreen() {
    final rect = Win32.windowRect(_hwnd);
    if (rect == null) return;
    final dpr = _logicalScreen.width == 0 ? 1.0 : _devicePixelRatio;
    final (left, top, right, bottom) = rect;
    final screenW = (_logicalScreen.width * dpr).round();
    final screenH = (_logicalScreen.height * dpr).round();
    final ok = left < screenW - 60 && top < screenH - 60 && right > 60 && bottom > 60;
    if (!ok) windowManager.setAlignment(Alignment.bottomRight);
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

  int _findWindowHandle() =>
      Win32.findWindowByClass('FLUTTER_RUNNER_WIN32_WINDOW');

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
    await windowManager.destroy();
  }
}
