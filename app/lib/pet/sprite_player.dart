import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';


/// 逐帧播放一张 animated WebP。
///
/// 没有用 `Image` widget，因为它的多帧播放会无限循环、也不给结束回调；
/// 奶龙需要「播一次就停、播完通知状态机」，所以自己驱动 `ui.Codec`。
class SpritePlayer extends StatefulWidget {
  const SpritePlayer({
    super.key,
    required this.asset,
    this.loop = true,
    this.playing = true,
    this.onFinished,
    this.decodeWidth,
  });

  final String asset;
  final bool loop;
  final bool playing;
  final VoidCallback? onFinished;

  /// 解码目标宽度（物理像素）。给 null 就按原图解码。
  final int? decodeWidth;

  @override
  State<SpritePlayer> createState() => SpritePlayerState();
}

class SpritePlayerState extends State<SpritePlayer>
    with SingleTickerProviderStateMixin {
  Duration _step = const Duration(milliseconds: 33);

  late final Ticker _ticker;
  ui.Codec? _codec;
  ui.Image? _image;
  int _frameCount = 0;
  int _shown = 0;
  bool _loading = false;
  bool _decoding = false;
  bool _finished = false;
  Duration _accum = Duration.zero;
  Duration _lastElapsed = Duration.zero;

  bool get finished => _finished;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    if (widget.playing) _ticker.start();
    _load();
  }

  @override
  void didUpdateWidget(covariant SpritePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset != widget.asset) {
      _load();
    }
    if (widget.playing && !_ticker.isActive) {
      _lastElapsed = Duration.zero;
      _ticker.start();
    } else if (!widget.playing && _ticker.isActive) {
      _ticker.stop();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _image?.dispose();
    _codec?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    _loading = true;
    try {
      final data = await rootBundle.load(widget.asset);
      final target = widget.decodeWidth;
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
        targetWidth: target != null && target > 32 ? target : null,
      );
      if (!mounted) {
        codec.dispose();
        return;
      }
      _codec?.dispose();
      _codec = codec;
      _frameCount = codec.frameCount;
      _shown = 0;
      _finished = false;
      final first = await codec.getNextFrame();
      if (!mounted) {
        first.image.dispose();
        return;
      }
      if (first.duration > Duration.zero) _step = first.duration;
      setState(() {
        _image?.dispose();
        _image = first.image;
        _shown = 1;
      });
    } catch (e) {
      debugPrint('sprite load failed (${widget.asset}): $e');
    } finally {
      _loading = false;
    }
  }

  void _onTick(Duration elapsed) {
    final dt = elapsed - _lastElapsed;
    _lastElapsed = elapsed;
    if (!widget.playing ||
        _loading ||
        _finished ||
        _decoding ||
        _codec == null) {
      return;
    }
    // 单帧素材（定帧待机）不用逐帧重解码
    if (_frameCount <= 1) return;
    _accum += dt;
    if (_accum < _step) return;
    _accum = Duration.zero;
    _advance();
  }

  Future<void> _advance() async {
    final codec = _codec;
    if (codec == null || _decoding) return;
    _decoding = true;
    ui.FrameInfo info;
    try {
      info = await codec.getNextFrame();
    } catch (_) {
      _decoding = false;
      return;
    }
    _decoding = false;
    if (!mounted) {
      info.image.dispose();
      return;
    }
    if (info.duration > Duration.zero) _step = info.duration;
    setState(() {
      _image?.dispose();
      _image = info.image;
      _shown++;
    });
    if (_shown >= _frameCount) {
      if (widget.loop) {
        _shown = 0; // codec 自己会回到第一帧
      } else {
        _finished = true;
        widget.onFinished?.call();
      }
    }
  }

  /// 让一次性动画从头再播（codec 停在末尾，下一次解码正好回到第 0 帧）。
  void restart() {
    _finished = false;
    _shown = 0;
    _accum = Duration.zero;
  }

  /// 从头重新解码播放，用于「动画被暂停在中间帧之后」的场景。
  ///
  /// restart() 只重置计数，画面会从停住的那一帧接着走（笑完回来停在半闭眼
  /// 就是这个问题），所以被打断后要用这个重新解码。
  void reset() {
    _finished = false;
    _accum = Duration.zero;
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final img = _image;
    if (img == null) return const SizedBox.expand();
    return RawImage(
      image: img,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
    );
  }
}
