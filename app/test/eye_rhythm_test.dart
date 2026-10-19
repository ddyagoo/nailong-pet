import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:nailong_pet/pet/eye_rhythm.dart';

void main() {
  test('眼睛动作的间隔是随机的，不是固定周期', () {
    final rhythm = EyeRhythm(rng: math.Random(7));
    final gaps = [for (var i = 0; i < 400; i++) rhythm.nextDelayMs()];

    // 都在设定区间内
    for (final g in gaps) {
      final normal = g >= EyeRhythm.minGap && g <= EyeRhythm.maxGap;
      final doze = g >= EyeRhythm.daydreamMin && g <= EyeRhythm.daydreamMax;
      expect(normal || doze, isTrue, reason: '间隔 $g ms 超出范围');
    }

    // 至少几十种不同长度；如果像以前那样是固定周期，这里会是 1
    expect(gaps.toSet().length, greaterThan(50));

    // 发呆态大概占 16%，留点余量
    final doze =
        gaps.where((g) => g > EyeRhythm.maxGap).length / gaps.length;
    expect(doze, inInclusiveRange(0.08, 0.26));
  });

  test('片段按权重挑，三种都会出现', () {
    final rhythm = EyeRhythm(rng: math.Random(11));
    final counts = [0, 0, 0];
    for (var i = 0; i < 3000; i++) {
      counts[rhythm.pick(const [0.70, 0.22, 0.08])]++;
    }
    expect(counts[0], greaterThan(counts[1]));
    expect(counts[1], greaterThan(counts[2]));
    expect(counts[2], greaterThan(0));
    // 眨眼（含连眨）应该是主力
    expect(counts[0] / 3000, closeTo(0.70, 0.04));
  });
}
