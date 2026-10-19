import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../pet/eye_rhythm.dart';
import '../pet/sprite_player.dart';

/// 待机画面：一张定帧 + 随机的眼睛小动作。
///
/// 源视频里待机时身体本来就是静止的，动的只有眼皮。之前把「眨眼 + 眼珠
/// 漂移」压成了一个固定周期的循环，看起来像上了发条。现在拆成
/// 眨眼 / 连眨两下 / 转眼珠三个小片段，间隔随机，偶尔还会发呆久一点。
class IdlePet extends StatefulWidget {
  const IdlePet({super.key, this.enabled = true});

  /// 笑的时候要关掉，不然眼睛会在笑到一半的时候被插进来。
  final bool enabled;

  @override
  State<IdlePet> createState() => _IdlePetState();
}

class _EyeClip {
  const _EyeClip(this.asset, this.ms);

  final String asset;

  /// 片段时长，用来兜底：万一 onFinished 没回来也不至于卡住。
  final int ms;
}

class _IdlePetState extends State<IdlePet> {
  static const _clips = <_EyeClip>[
    _EyeClip('assets/pet/blink.webp', 460),
    _EyeClip('assets/pet/glance.webp', 1800),
    _EyeClip('assets/pet/blink2.webp', 950),
  ];
  static const _weights = <double>[0.70, 0.22, 0.08];

  final _rhythm = EyeRhythm(rng: math.Random());

  Timer? _next;
  Timer? _guard;
  String? _asset;

  @override
  void initState() {
    super.initState();
    _arm();
  }

  @override
  void didUpdateWidget(covariant IdlePet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled == widget.enabled) return;
    if (widget.enabled) {
      _arm();
    } else {
      _disarm();
      if (_asset != null) setState(() => _asset = null);
    }
  }

  @override
  void dispose() {
    _disarm();
    super.dispose();
  }

  void _arm() {
    _disarm();
    if (!widget.enabled) return;
    _next = Timer(Duration(milliseconds: _rhythm.nextDelayMs()), _fire);
  }

  void _disarm() {
    _next?.cancel();
    _next = null;
    _guard?.cancel();
    _guard = null;
  }

  void _fire() {
    _next = null;
    if (!mounted || !widget.enabled) return;
    final clip = _clips[_rhythm.pick(_weights)];
    setState(() => _asset = clip.asset);
    _guard?.cancel();
    _guard = Timer(Duration(milliseconds: clip.ms + 600), _done);
  }

  /// 一次眼睛动作结束，回到定帧并排下一轮。
  void _done() {
    _guard?.cancel();
    _guard = null;
    if (!mounted) return;
    if (_asset != null) setState(() => _asset = null);
    _arm();
  }

  @override
  Widget build(BuildContext context) {
    final eye = _asset;
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        const SpritePlayer(
          asset: 'assets/pet/idle.webp',
          loop: true,
          playing: true,
        ),
        if (eye != null)
          SpritePlayer(
            // 每个片段的首尾都是站立定帧，和底下的 idle 严丝合缝
            asset: eye,
            loop: false,
            playing: true,
            onFinished: _done,
          ),
      ],
    );
  }
}
