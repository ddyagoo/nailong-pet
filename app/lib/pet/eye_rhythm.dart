import 'dart:math' as math;

/// 待机「播一次 → 停一会儿 → 再播」的停顿长度。
///
/// 抽成独立类是为了能单测：停顿必须随机、而且落在设置区间里。
class BlinkRhythm {
  factory BlinkRhythm({
    int minMs = defaultMinMs,
    int maxMs = defaultMaxMs,
    math.Random? rng,
  }) {
    final (lo, hi) = clampRange(minMs, maxMs);
    return BlinkRhythm._(lo, hi, rng ?? math.Random());
  }

  BlinkRhythm._(this.minMs, this.maxMs, this._rng);

  /// 允许的最短停顿（0.5 秒）。
  static const floorMs = 500;

  /// 允许的最长停顿（10 秒）。
  static const ceilMs = 10000;

  /// 默认区间：0.5–2 秒。
  static const defaultMinMs = 500;
  static const defaultMaxMs = 2000;

  final int minMs;
  final int maxMs;
  final math.Random _rng;

  /// 下一次停多久（毫秒）。区间相同就返回固定值。
  int nextGapMs() {
    if (maxMs <= minMs) return minMs;
    return minMs + _rng.nextInt(maxMs - minMs + 1);
  }

  /// 把任意输入收进 [floorMs, ceilMs]。
  static int clampGap(num ms) => ms.round().clamp(floorMs, ceilMs);

  /// 收进合法区间，顺手处理 min > max。
  static (int, int) clampRange(num minMs, num maxMs) {
    var lo = clampGap(minMs);
    var hi = clampGap(maxMs);
    if (hi < lo) (lo, hi) = (hi, lo);
    return (lo, hi);
  }
}
