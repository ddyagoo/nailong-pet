import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../services/settings_service.dart';

enum PetMood { idle, laughing }

/// 奶龙的「什么时候该笑」状态机。
///
/// 规则（已和用户确认）：
///  * 静置 40 秒 → 笑一次
///  * 之后每次随机 90–150 秒
///  * 点一下 / 拖一下 → 计时清零，回到 40 秒
///  * 连续第 3 次笑播完整彩蛋，然后冷却 5 分钟
class PetBrain extends ChangeNotifier {
  PetBrain({required this.settings, this.fastIdle = false});

  final SettingsService settings;

  /// 预览用：把 40s / 90–150s 压成几秒，方便验收彩蛋。
  final bool fastIdle;
  final Random _rng = Random();

  static const cooldown = Duration(minutes: 5);

  PetMood _mood = PetMood.idle;
  PetMood get mood => _mood;

  bool _isEgg = false;
  bool get isEgg => _isEgg;

  int _laughs = 0;
  int get laughsSinceCooldown => _laughs;

  Timer? _timer;
  bool _cooling = false;
  bool _started = false;

  /// 界面接到这两个回调里去切动画 / 放声音。
  VoidCallback? onLaughStart;
  VoidCallback? onLaughEnd;

  void start() {
    if (_started) return;
    _started = true;
    _schedule(_idleDelay);
  }

  /// 任何一次互动都让计时归零。
  void poke() {
    if (_mood != PetMood.idle) return;
    _schedule(_idleDelay);
  }

  void _schedule(Duration delay) {
    _timer?.cancel();
    _timer = Timer(delay, _fire);
  }

  /// 每轮静置的目标时长：在设置区间里随机取一秒。
  Duration get _idleDelay {
    if (fastIdle) return const Duration(seconds: 3);
    final lo = settings.idleMin.clamp(5.0, 600.0);
    final hi = settings.idleMax.clamp(lo, 600.0);
    final span = (hi - lo).round();
    final seconds = lo.round() + (span > 0 ? _rng.nextInt(span + 1) : 0);
    return Duration(seconds: seconds);
  }

  Duration get _nextDelay => _idleDelay;

  void _fire() {
    if (!settings.laughOn || _cooling || _mood != PetMood.idle) {
      _schedule(_nextDelay);
      return;
    }
    _beginLaugh();
  }

  /// 长按手动让它笑。不受「冷却」限制，但同样累计次数：
  /// 第 3、6、9… 次是完整版（笑到躺下）。
  void triggerLaugh() {
    if (_mood != PetMood.idle) return;
    _timer?.cancel();
    _beginLaugh();
  }

  void _beginLaugh() {
    _laughs += 1;
    _isEgg = _laughs % 3 == 0;
    _mood = PetMood.laughing;
    notifyListeners();
    onLaughStart?.call();
  }

  /// 切回前台时把静置计时重新开始，避免在后台偷偷笑完。
  void restartIdle() {
    if (_mood != PetMood.idle) return;
    _schedule(_idleDelay);
  }

  /// 动画播完后由界面调用。
  void finishLaugh() {
    if (_mood != PetMood.laughing) return;
    final wasEgg = _isEgg;
    _mood = PetMood.idle;
    _isEgg = false;
    notifyListeners();
    onLaughEnd?.call();

    if (wasEgg) {
      _laughs = 0;
      _cooling = true;
      final cool = fastIdle ? const Duration(seconds: 8) : cooldown;
      _schedule(cool + Duration(milliseconds: 1)); // 冷却期间不主动笑
      // 冷却结束后回到正常节奏
      Timer(cool, () {
        _cooling = false;
        if (_mood == PetMood.idle) _schedule(_idleDelay);
      });
    } else {
      _schedule(_nextDelay);
    }
  }

  /// 用户点它 / 拖它时打断正在进行的大笑。
  void interrupt() {
    if (_mood != PetMood.laughing) return;
    _mood = PetMood.idle;
    _isEgg = false;
    notifyListeners();
    _schedule(_nextDelay);
  }

  /// 用户改了「大笑开关」，关掉时立刻取消排期。
  void onSettingsChanged() {
    if (!settings.laughOn) {
      _timer?.cancel();
    } else if (_mood == PetMood.idle && !_cooling) {
      _schedule(_nextDelay);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
