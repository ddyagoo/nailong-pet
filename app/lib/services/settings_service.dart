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
  static const _kBlinkMin = 'blink_min';
  static const _kBlinkMax = 'blink_max';

  double _volume = 0.7;
  bool _muted = false;
  bool _laughOn = true;
  bool _hapticOn = true;
  double _petScale = 1.0;

  /// 静置多久会笑：在这个区间里随机取一秒。
  double _idleMin = 30;
  double _idleMax = 90;

  /// 待机动画播完之后停多久：在这个区间里随机取一个停顿（秒）。
  double _blinkMin = 0.5;
  double _blinkMax = 2.0;

  double get volume => _muted ? 0 : _volume;
  double get sliderValue => _volume;
  bool get muted => _muted;
  bool get laughOn => _laughOn;
  bool get hapticOn => _hapticOn;

  /// 奶龙整体大小，0.6–1.6。
  double get petScale => _petScale;

  double get idleMin => _idleMin;
  double get idleMax => _idleMax;

  /// 待机动画两段之间的停顿（秒）。
  double get blinkMin => _blinkMin;
  double get blinkMax => _blinkMax;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _volume = p.getDouble(_kVolume) ?? 0.7;
    _muted = p.getBool(_kMuted) ?? false;
    _laughOn = p.getBool(_kLaugh) ?? true;
    _hapticOn = p.getBool(_kHaptic) ?? true;
    _petScale = p.getDouble(_kScale) ?? 1.0;
    _idleMin = p.getDouble(_kIdleMin) ?? 30;
    _idleMax = p.getDouble(_kIdleMax) ?? 90;
    _blinkMin = (p.getDouble(_kBlinkMin) ?? 0.5).clamp(0.5, 10.0);
    _blinkMax = (p.getDouble(_kBlinkMax) ?? 2.0).clamp(0.5, 10.0);
    if (_blinkMax < _blinkMin) _blinkMax = _blinkMin;
    notifyListeners();
  }

  /// 待机停顿时长：允许 min == max（固定间隔），只保证 min <= max。
  Future<void> setBlinkRange(double min, double max) async {
    var lo = min.clamp(0.5, 10.0);
    var hi = max.clamp(0.5, 10.0);
    if (hi < lo) {
      final t = lo;
      lo = hi;
      hi = t;
    }
    _blinkMin = lo;
    _blinkMax = hi;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setDouble(_kBlinkMin, lo);
    await p.setDouble(_kBlinkMax, hi);
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
