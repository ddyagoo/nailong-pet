import 'dart:async';

import 'package:flutter/material.dart';

import '../pet/eye_rhythm.dart';
import '../pet/sprite_player.dart';
import '../services/settings_service.dart';

/// 待机画面：整段站立动画，播一次、停一会儿、再播。
///
/// `idle.webp` 是源视频 0–1.5s 正放 + 倒放的整段（2.93 秒，眨眼和眼珠
/// 来回都在这段里），和第一版用的是同一份素材。区别只在播放方式：
/// 不再是死循环，而是每次播完停 0.5–2 秒（设置里可调，上限 10 秒）再播，
/// 所以节奏不固定。
class IdlePet extends StatefulWidget {
  const IdlePet({
    super.key,
    required this.settings,
    this.enabled = true,
    this.decodeWidth,
  });

  /// 解码目标宽度（物理像素）。
  final int? decodeWidth;

  final SettingsService settings;

  /// 笑的时候要关掉，不然待机会在笑到一半的时候插进来。
  final bool enabled;

  @override
  State<IdlePet> createState() => _IdlePetState();
}

class _IdlePetState extends State<IdlePet> {
  final _playerKey = GlobalKey<SpritePlayerState>();

  late BlinkRhythm _rhythm;
  Timer? _gap;

  @override
  void initState() {
    super.initState();
    _rhythm = _makeRhythm();
    widget.settings.addListener(_onSettings);
  }

  @override
  void didUpdateWidget(covariant IdlePet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled == widget.enabled) return;
    if (widget.enabled) {
      _restartNow();
    } else {
      _cancelGap();
    }
  }

  @override
  void dispose() {
    widget.settings.removeListener(_onSettings);
    _cancelGap();
    super.dispose();
  }

  BlinkRhythm _makeRhythm() => BlinkRhythm(
        minMs: (widget.settings.blinkMin * 1000).round(),
        maxMs: (widget.settings.blinkMax * 1000).round(),
      );

  void _onSettings() {
    // 只影响下一段，正在播的这段不打断
    _rhythm = _makeRhythm();
    if (mounted) setState(() {});
  }

  void _cancelGap() {
    _gap?.cancel();
    _gap = null;
  }

  void _restartNow() {
    _cancelGap();
    // 笑的时候播放器被暂停在中间帧，必须重新解码才会回到第一帧（睁眼）
    _playerKey.currentState?.reset();
  }

  /// 一段播完：按随机停顿排下一段。
  void _onFinished() {
    if (!mounted || !widget.enabled) return;
    _cancelGap();
    _gap = Timer(Duration(milliseconds: _rhythm.nextGapMs()), () {
      if (!mounted || !widget.enabled) return;
      _playerKey.currentState?.restart();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SpritePlayer(
      key: _playerKey,
      asset: 'assets/pet/idle.webp',
      decodeWidth: widget.decodeWidth,
      loop: false,
      playing: widget.enabled,
      onFinished: _onFinished,
    );
  }
}
