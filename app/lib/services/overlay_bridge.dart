import 'package:flutter/services.dart';

/// 与原生悬浮窗服务通信。
class OverlayBridge {
  static const _channel = MethodChannel('nailong/overlay');

  /// 原生侧从系统设置页返回时会调 refresh。
  static void Function()? onRefresh;

  static void init() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'refresh') onRefresh?.call();
      return null;
    });
  }

  static Future<Map<String, bool>> status() async {
    try {
      final raw = await _channel.invokeMethod<Map<Object?, Object?>>('status');
      if (raw == null) return {};
      return raw.map((k, v) => MapEntry(k.toString(), v == true));
    } catch (_) {
      return {};
    }
  }

  static Future<void> requestOverlay() =>
      _channel.invokeMethod('requestOverlay');

  static Future<void> requestCalendar() =>
      _channel.invokeMethod('requestCalendar');

  static Future<void> requestNotification() =>
      _channel.invokeMethod('requestNotification');

  static Future<bool> start() async {
    final ok = await _channel.invokeMethod<bool>('start');
    return ok ?? false;
  }

  static Future<void> stop() => _channel.invokeMethod('stop');

  static Future<void> openBatterySettings() =>
      _channel.invokeMethod('openBattery');

  static Future<String> version() async {
    try {
      return await _channel.invokeMethod<String>('version') ?? '';
    } catch (_) {
      return '';
    }
  }

  static Future<Map<String, dynamic>> checkUpdate() async {
    try {
      final raw =
          await _channel.invokeMethod<Map<Object?, Object?>>('checkUpdate');
      if (raw == null) return {};
      return raw.map((k, v) => MapEntry(k.toString(), v));
    } catch (_) {
      return {'ok': false, 'message': '检查失败'};
    }
  }

  static Future<void> openUrl(String url) =>
      _channel.invokeMethod('openUrl', {'url': url});
}
