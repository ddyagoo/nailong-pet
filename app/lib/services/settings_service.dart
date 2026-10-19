import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 用户偏好：一条总音量滑杆 + 几个开关，本地持久化。
class SettingsService extends ChangeNotifier {
  static const _kVolume = 'volume';
  static const _kMuted = 'muted';
  static const _kLaugh = 'laugh_on';
  static const _kHaptic = 'haptic';
  static const _kScale = 'pet_scale';
  static const _kIdleMin = 'idle_min';
  static const _kIdleMax = 'idle_max';

  double _volume = 0.7;
  bool _muted = false;
  bool _laughOn = true;
  bool _hapticOn = true;
  double _petScale = 1.0;

  /// 静置多久会笑：在这个区间里随机取一秒。
  double _idleMin = 30;
  double _idleMax = 90;

  double get volume => _muted ? 0 : _volume;
  double get sliderValue => _volume;
  bool get muted => _muted;
  bool get laughOn => _laughOn;
  bool get hapticOn => _hapticOn;

  /// 奶龙整体大小，0.6–1.6。
  double get petScale => _petScale;

  double get idleMin => _idleMin;
  double get idleMax => _idleMax;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _volume = p.getDouble(_kVolume) ?? 0.7;
    _muted = p.getBool(_kMuted) ?? false;
    _laughOn = p.getBool(_kLaugh) ?? true;
    _hapticOn = p.getBool(_kHaptic) ?? true;
    _petScale = p.getDouble(_kScale) ?? 1.0;
    _idleMin = p.getDouble(_kIdleMin) ?? 30;
    _idleMax = p.getDouble(_kIdleMax) ?? 90;
    notifyListeners();
  }

  Future<void> setIdleRange(double min, double max) async {
    var lo = min.clamp(10.0, 300.0);
    var hi = max.clamp(10.0, 300.0);
    if (hi < lo + 5) hi = (lo + 5).clamp(10.0, 300.0);
    if (lo > hi - 5) lo = (hi - 5).clamp(10.0, 300.0);
    _idleMin = lo;
    _idleMax = hi;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setDouble(_kIdleMin, lo);
    await p.setDouble(_kIdleMax, hi);
  }

  Future<void> setPetScale(double v) async {
    _petScale = v.clamp(0.6, 1.6);
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setDouble(_kScale, _petScale);
  }

  Future<void> setVolume(double v) async {
    _volume = v.clamp(0.0, 1.0);
    if (_volume > 0 && _muted) _muted = false;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setDouble(_kVolume, _volume);
    await p.setBool(_kMuted, _muted);
  }

  Future<void> toggleMute() async {
    _muted = !_muted;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kMuted, _muted);
  }

  Future<void> setLaughOn(bool v) async {
    _laughOn = v;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kLaugh, v);
  }

  Future<void> setHapticOn(bool v) async {
    _hapticOn = v;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kHaptic, v);
  }
}
