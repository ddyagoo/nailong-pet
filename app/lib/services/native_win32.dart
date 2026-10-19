import 'dart:ffi';

import 'package:ffi/ffi.dart';

/// 只用到 4 个 user32 函数，直接 FFI 调，省得跟着 win32 包的版本 API 折腾。
class Win32 {
  Win32._();

  static final DynamicLibrary _user32 = DynamicLibrary.open('user32.dll');
  static final DynamicLibrary _gdi32 = DynamicLibrary.open('gdi32.dll');

  static final int Function(Pointer<_Point>) _getCursorPos =
      _user32.lookupFunction<Int32 Function(Pointer<_Point>),
          int Function(Pointer<_Point>)>('GetCursorPos');

  static final int Function(int, Pointer<_Rect>) _getWindowRect =
      _user32.lookupFunction<Int32 Function(IntPtr, Pointer<_Rect>),
          int Function(int, Pointer<_Rect>)>('GetWindowRect');

  static final int Function(int, int) _getWindowLongPtrW =
      _user32.lookupFunction<IntPtr Function(IntPtr, Int32),
          int Function(int, int)>('GetWindowLongPtrW');

  static final int Function(int, int, int) _setWindowLongPtrW =
      _user32.lookupFunction<IntPtr Function(IntPtr, Int32, IntPtr),
          int Function(int, int, int)>('SetWindowLongPtrW');

  static final int Function(Pointer<Utf16>, Pointer<Utf16>) _findWindowW =
      _user32.lookupFunction<IntPtr Function(Pointer<Utf16>, Pointer<Utf16>),
          int Function(Pointer<Utf16>, Pointer<Utf16>)>('FindWindowW');

  static final int Function(int) _getSystemMetrics =
      _user32.lookupFunction<Int32 Function(Int32), int Function(int)>(
          'GetSystemMetrics');

  static final int Function(int, Pointer<Utf16>, int) _getClassNameW =
      _user32.lookupFunction<Int32 Function(IntPtr, Pointer<Utf16>, Int32),
          int Function(int, Pointer<Utf16>, int)>('GetClassNameW');

  static final int Function(int) _deleteObject =
      _gdi32.lookupFunction<Int32 Function(IntPtr), int Function(int)>(
          'DeleteObject');

  static final int Function(int, int, int, int) _createRectRgn =
      _gdi32.lookupFunction<IntPtr Function(Int32, Int32, Int32, Int32),
          int Function(int, int, int, int)>('CreateRectRgn');

  static final int Function(int, int, int, int) _postMessage =
      _user32.lookupFunction<Int32 Function(IntPtr, Uint32, IntPtr, IntPtr),
          int Function(int, int, int, int)>('PostMessageW');

  static final int Function(int, int, int, int) _combineRgn =
      _gdi32.lookupFunction<Int32 Function(IntPtr, IntPtr, IntPtr, Int32),
          int Function(int, int, int, int)>('CombineRgn');

  static final int Function(int, int, int) _setWindowRgn =
      _user32.lookupFunction<Int32 Function(IntPtr, IntPtr, Int32),
          int Function(int, int, int)>('SetWindowRgn');

  static final int Function(int, int) _getWindow =
      _user32.lookupFunction<IntPtr Function(IntPtr, Uint32),
          int Function(int, int)>('GetWindow');

  static const _gwlExStyle = -20;
  static const _wsExTransparent = 0x00000020;
  static const _smCxScreen = 0;
  static const _smCyScreen = 1;
  static const _gwChild = 5;
  static const _gwHwndNext = 2;

  static int findWindow(String title) {
    final ptr = title.toNativeUtf16();
    try {
      return _findWindowW(nullptr, ptr);
    } finally {
      calloc.free(ptr);
    }
  }

  /// 按窗口类名找。Flutter 的顶层窗口类是 FLUTTER_RUNNER_WIN32_WINDOW，
  /// 按标题找可能命中别的同名窗口（托盘辅助窗口等）。
  static int findWindowByClass(String className) {
    final ptr = className.toNativeUtf16();
    try {
      return _findWindowW(ptr, nullptr);
    } finally {
      calloc.free(ptr);
    }
  }

  /// 光标屏幕坐标，失败返回 null。
  static (int, int)? cursorPos() {
    final p = calloc<_Point>();
    try {
      if (_getCursorPos(p) == 0) return null;
      return (p.ref.x, p.ref.y);
    } finally {
      calloc.free(p);
    }
  }

  /// 窗口在屏幕上的范围，失败返回 null。
  static (int, int, int, int)? windowRect(int hwnd) {
    if (hwnd == 0) return null;
    final r = calloc<_Rect>();
    try {
      if (_getWindowRect(hwnd, r) == 0) return null;
      return (r.ref.left, r.ref.top, r.ref.right, r.ref.bottom);
    } finally {
      calloc.free(r);
    }
  }

  /// 窗口尺寸（物理像素）。
  static (int, int) windowSize(int hwnd) {
    final rect = windowRect(hwnd);
    if (rect == null) return (0, 0);
    return (rect.$3 - rect.$1, rect.$4 - rect.$2);
  }

  /// 和自己点标题栏关闭一样：发 WM_CLOSE 让窗口正常退出。
  ///
  /// 比 window_manager.destroy() 快得多（后者要等引擎和插件收尾，实测 ~15 秒）。
  static void postClose(int hwnd) {
    if (hwnd == 0) return;
    const wmClose = 0x0010;
    _postMessage(hwnd, wmClose, 0, 0);
  }

  static (int, int) screenSize() =>
      (_getSystemMetrics(_smCxScreen), _getSystemMetrics(_smCyScreen));

  static String className(int hwnd) {
    final buf = calloc<Uint16>(256);
    try {
      final n = _getClassNameW(hwnd, buf.cast<Utf16>(), 256);
      if (n <= 0) return '?';
      return buf.cast<Utf16>().toDartString(length: n);
    } finally {
      calloc.free(buf);
    }
  }

  static bool hasClickThrough(int hwnd) {
    final style = _getWindowLongPtrW(hwnd, _gwlExStyle);
    return (style & _wsExTransparent) != 0;
  }

  /// 把窗口裁剪成若干矩形的并集（窗口坐标系，物理像素）。
  ///
  /// 传多个矩形就能做出「跟着身形走」的不规则可点区域。
  static void setRegionRects(int hwnd, List<List<int>> rects) {
    if (hwnd == 0 || rects.isEmpty) return;
    final first = rects.first;
    final dest = _createRectRgn(first[0], first[1], first[2], first[3]);
    if (dest == 0) return;
    const rgnOr = 2;
    for (var i = 1; i < rects.length; i++) {
      final r = rects[i];
      final tmp = _createRectRgn(r[0], r[1], r[2], r[3]);
      if (tmp == 0) continue;
      _combineRgn(dest, dest, tmp, rgnOr);
      // CombineRgn 不会释放 tmp，交给系统回收会泄漏，这里手动删
      _deleteObject(tmp);
    }
    _setWindowRgn(hwnd, dest, 1);
  }

  /// 把窗口裁剪成 rect（窗口坐标系，物理像素）。区域外鼠标事件直接落到桌面。
  ///
  /// 比 WS_EX_TRANSPARENT 可靠：后者对子窗口的命中测试不生效（实测
  /// WindowFromPoint 仍返回 FLUTTERVIEW）。
  static void setRegion(int hwnd, int left, int top, int right, int bottom) {
    if (hwnd == 0) return;
    final rgn = _createRectRgn(left, top, right, bottom);
    if (rgn == 0) return;
    _setWindowRgn(hwnd, rgn, 1);
  }

  // 旧方案（保留给别处用，目前不生效）
  static List<int> setClickThrough(int hwnd, bool on) {
    final touched = <int>[];
    if (hwnd == 0) return touched;
    _apply(hwnd, on);
    touched.add(hwnd);
    void walk(int parent) {
      var child = _getWindow(parent, _gwChild);
      while (child != 0) {
        _apply(child, on);
        touched.add(child);
        walk(child);
        child = _getWindow(child, _gwHwndNext);
      }
    }
    walk(hwnd);
    return touched;
  }

  static final int Function(int, int, int, int, int, int, int) _setWindowPos =
      _user32.lookupFunction<Int32 Function(IntPtr, IntPtr, Int32, Int32, Int32, Int32, Uint32),
          int Function(int, int, int, int, int, int, int)>('SetWindowPos');

  static const _swpNoMove = 0x0002;
  static const _swpNoSize = 0x0001;
  static const _swpNoZOrder = 0x0004;
  static const _swpFrameChanged = 0x0020;

  static void _apply(int hwnd, bool on) {
    final style = _getWindowLongPtrW(hwnd, _gwlExStyle);
    final next = on ? (style | _wsExTransparent) : (style & ~_wsExTransparent);
    _setWindowLongPtrW(hwnd, _gwlExStyle, next);
    // 改扩展样式后要重新走一遍 NC 计算，否则不生效
    _setWindowPos(hwnd, 0, 0, 0, 0, 0,
        _swpNoMove | _swpNoSize | _swpNoZOrder | _swpFrameChanged);
  }
}

final class _Point extends Struct {
  @Int32()
  external int x;

  @Int32()
  external int y;
}

final class _Rect extends Struct {
  @Int32()
  external int left;

  @Int32()
  external int top;

  @Int32()
  external int right;

  @Int32()
  external int bottom;
}
