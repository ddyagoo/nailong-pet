import 'dart:math' as math;

/// 待机时「动眼睛」的节奏。
///
/// 抽成独立类是为了能单测：间隔必须是随机的，而且得落在设定的区间里。
class EyeRhythm {
  EyeRhythm({math.Random? rng}) : _rng = rng ?? math.Random();

  /// 普通的两次小动作之间。
  static const minGap = 2600;
  static const maxGap = 7000;

  /// 偶尔发呆这么久（16% 概率），不然节奏还是太规律。
  static const daydreamChance = 0.16;
  static const daydreamMin = 12000;
  static const daydreamMax = 22000;

  final math.Random _rng;

  /// 下一次动眼睛前要等多久。
  int nextDelayMs() {
    if (_rng.nextDouble() < daydreamChance) {
      return daydreamMin + _rng.nextInt(daydreamMax - daydreamMin + 1);
    }
    return minGap + _rng.nextInt(maxGap - minGap + 1);
  }

  /// 按权重挑一个片段。
  int pick(List<double> weights) {
    var r = _rng.nextDouble();
    for (var i = 0; i < weights.length; i++) {
      if (r < weights[i]) return i;
      r -= weights[i];
    }
    return weights.length - 1;
  }
}
