import 'dart:ffi';

import 'package:ffi/ffi.dart';

/// 只用到 4 个 user32 函数，直接 FFI 调，省得跟着 win32 包的版本 API 折腾。
class Win32 {
  Win32._();

  static final DynamicLibrary _user32 = DynamicLibrary.open('user32.dll');

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

  static const _gwlExStyle = -20;
  static const _wsExTransparent = 0x00000020;
  static const _smCxScreen = 0;
  static const _smCyScreen = 1;

  static int findWindow(String title) {
    final ptr = title.toNativeUtf16();
    try {
      return _findWindowW(nullptr, ptr);
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

  static (int, int) screenSize() =>
      (_getSystemMetrics(_smCxScreen), _getSystemMetrics(_smCyScreen));

  static void setClickThrough(int hwnd, bool on) {
    if (hwnd == 0) return;
    final style = _getWindowLongPtrW(hwnd, _gwlExStyle);
    final next = on ? (style | _wsExTransparent) : (style & ~_wsExTransparent);
    _setWindowLongPtrW(hwnd, _gwlExStyle, next);
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
