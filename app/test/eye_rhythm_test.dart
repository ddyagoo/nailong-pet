import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:nailong_pet/pet/eye_rhythm.dart';

void main() {
  test('默认停顿在 0.5–2 秒之间，而且是随机的', () {
    final rhythm = BlinkRhythm(rng: math.Random(7));
    final gaps = [for (var i = 0; i < 400; i++) rhythm.nextGapMs()];

    for (final g in gaps) {
      expect(g, inInclusiveRange(BlinkRhythm.defaultMinMs,
          BlinkRhythm.defaultMaxMs), reason: '停顿 $g ms 超出默认区间');
    }
    // 固定周期的话这里会是 1
    expect(gaps.toSet().length, greaterThan(50));
  });

  test('区间会被收进 0.5–10 秒的硬上下限', () {
    final tooSmall = BlinkRhythm(minMs: 100, maxMs: 300);
    expect(tooSmall.minMs, BlinkRhythm.floorMs);
    expect(tooSmall.maxMs, BlinkRhythm.floorMs);
    for (var i = 0; i < 20; i++) {
      expect(tooSmall.nextGapMs(), BlinkRhythm.floorMs);
    }

    final tooBig = BlinkRhythm(minMs: 20000, maxMs: 60000);
    expect(tooBig.minMs, BlinkRhythm.ceilMs);
    expect(tooBig.maxMs, BlinkRhythm.ceilMs);
    expect(tooBig.nextGapMs(), BlinkRhythm.ceilMs);
  });

  test('min 和 max 给反了会自动交换', () {
    final (lo, hi) = BlinkRhythm.clampRange(4000, 1500);
    expect(lo, 1500);
    expect(hi, 4000);

    final rhythm = BlinkRhythm(minMs: 3000, maxMs: 1000, rng: math.Random(3));
    expect(rhythm.minMs, 1000);
    expect(rhythm.maxMs, 3000);
    for (final g in [for (var i = 0; i < 100; i++) rhythm.nextGapMs()]) {
      expect(g, inInclusiveRange(1000, 3000));
    }
  });

  test('min == max 时是固定间隔', () {
    final rhythm = BlinkRhythm(minMs: 1200, maxMs: 1200, rng: math.Random(5));
    for (var i = 0; i < 50; i++) {
      expect(rhythm.nextGapMs(), 1200);
    }
  });
}
