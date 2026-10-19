import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../pet/pet_brain.dart';
import '../pet/sprite_player.dart';
import '../services/audio_service.dart';
import '../services/desktop_bridge.dart';
import '../services/holiday_service.dart';
import '../services/settings_service.dart';
import '../services/todo_store.dart';
import 'bubble.dart';
import 'idle_pet.dart';

/// 画布宽高比（来自抠图裁切框 597x804）。
const double kSpriteAspect = 597 / 804;

class PetLayer extends StatefulWidget {
  const PetLayer({
    super.key,
    required this.brain,
    required this.settings,
    required this.audio,
    required this.todos,
    this.desktop = false,
  });

  final PetBrain brain;
  final SettingsService settings;
  final AudioService audio;
  final TodoStore todos;

  /// Windows 桌面模式：奶龙固定在窗口底部，拖动移动的是整个窗口。
  final bool desktop;

  @override
  State<PetLayer> createState() => PetLayerState();
}

class PetLayerState extends State<PetLayer> with TickerProviderStateMixin {
  static const _posKey = 'pet_pos';

  final _holiday = const HolidayService();
  final _laughKey = GlobalKey<SpritePlayerState>();
  final _bubbleKey = GlobalKey();

  late final AnimationController _bounce;
  late final Animation<double> _scale;

  /// 笑完切回站立时的一次快速压扁，用来遮住姿势跳变。
  late final AnimationController _snap;
  late final Animation<double> _snapScale;
  late final Listenable _pulse;

  Offset? _pos;
  double _petW = 200;
  Size _scene = Size.zero;
  Size? _lastPetSize;

  bool _bubble = false;
  String _laughAsset = 'assets/pet/laugh.webp';
  bool _desktopReserved = false;

  DayInfo? _day;
  List<TodoItem> _todos = const [];
  int _more = 0;

  @override
  void initState() {
    super.initState();
    _bounce = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 640));
    _scale = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween(begin: 1.0, end: 1.18)
              .chain(CurveTween(curve: Curves.easeOutCubic)),
          weight: 20),
      TweenSequenceItem(
          tween: Tween(begin: 1.18, end: 0.94)
              .chain(CurveTween(curve: Curves.easeInOutCubic)),
          weight: 24),
      TweenSequenceItem(
          tween: Tween(begin: 0.94, end: 1.05)
              .chain(CurveTween(curve: Curves.easeInOutCubic)),
          weight: 22),
      TweenSequenceItem(
          tween: Tween(begin: 1.05, end: 1.0)
              .chain(CurveTween(curve: Curves.easeOutCubic)),
          weight: 34),
    ]).animate(_bounce);
    _snap = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 220));
    _snapScale = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween(begin: 1.0, end: 0.90)
              .chain(CurveTween(curve: Curves.easeOutCubic)),
          weight: 35),
      TweenSequenceItem(
          tween: Tween(begin: 0.90, end: 1.04)
              .chain(CurveTween(curve: Curves.easeOutCubic)),
          weight: 33),
      TweenSequenceItem(
          tween: Tween(begin: 1.04, end: 1.0)
              .chain(CurveTween(curve: Curves.easeInOutCubic)),
          weight: 32),
    ]).animate(_snap);
    _pulse = Listenable.merge([_scale, _snapScale]);
    widget.brain.onLaughStart = _onLaughStart;
    widget.settings.addListener(_onSettings);
    _restorePosition();
  }

  void _onSettings() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.settings.removeListener(_onSettings);
    _bounce.dispose();
    _snap.dispose();
    super.dispose();
  }

  /// 设置里「让奶龙回到右下角」。
  void resetPosition() {
    setState(() {
      _pos = Offset(_scene.width - _petW - 18, _scene.height - _petH - 6);
    });
    if (_pos != null) _savePosition(_pos!);
  }

  Future<void> _restorePosition() async {
    final p = await SharedPreferences.getInstance();
    final dx = p.getDouble('${_posKey}_x');
    final dy = p.getDouble('${_posKey}_y');
    if (dx != null && dy != null && mounted) {
      setState(() => _pos = Offset(dx, dy));
    }
  }

  Future<void> _savePosition(Offset o) async {
    final p = await SharedPreferences.getInstance();
    await p.setDouble('${_posKey}_x', o.dx);
    await p.setDouble('${_posKey}_y', o.dy);
  }

  /// 桌面模式下气泡弹出会让 Electron 把窗口往上撑高，关掉时再收回去。
  void _setBubble(bool visible) {
    if (_bubble == visible) return;
    setState(() => _bubble = visible);
    if (widget.desktop && _desktopReserved != visible) {
      _desktopReserved = visible;
      DesktopBridge.reserveBubble(visible);
    }
  }

  void _onLaughStart() {
    final egg = widget.brain.isEgg;
    setState(() {
      _bubble = false;
      if (egg) _laughAsset = 'assets/pet/egg.webp';
    });
    if (widget.desktop && _desktopReserved) {
      _desktopReserved = false;
      DesktopBridge.reserveBubble(false);
    }
    widget.audio.laugh(full: egg);
    if (widget.settings.hapticOn) HapticFeedback.mediumImpact();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _laughKey.currentState?.restart();
    });
  }

  void _onLaughFinished() {
    final wasEgg = widget.brain.laughsSinceCooldown % 3 == 0;
    if (wasEgg) {
      // 完整段最后一帧就是站立姿势，直接切回 idle 不会有跳变
      widget.brain.finishLaugh();
      setState(() => _laughAsset = 'assets/pet/laugh.webp');
    } else {
      // 6 秒版本停在笑到一半，用一次压扁遮住姿势切换
      _snap.forward(from: 0);
      Future.delayed(const Duration(milliseconds: 92), () {
        if (mounted) widget.brain.finishLaugh();
      });
    }
  }

  // ---------------- 交互 ----------------

  void _poke() {
    if (widget.brain.mood != PetMood.idle) {
      widget.audio.stopLaugh();
      widget.brain.interrupt();
    }
    widget.brain.poke();
    _bounce.forward(from: 0);
    widget.audio.tap();
    widget.audio.unlock();
    if (widget.settings.hapticOn) HapticFeedback.selectionClick();
    if (_bubble) {
      _setBubble(false);
    } else {
      final now = DateTime.now();
      final ids = widget.todos.today;
      setState(() {
        _day = _holiday.day(now);
        _todos = ids.take(5).toList();
        _more = math.max(0, ids.length - 5);
      });
      _setBubble(true);
      Future.delayed(const Duration(seconds: 12), () {
        if (mounted && _bubble) _setBubble(false);
      });
    }
  }

  void _longPress() {
    // 长按 = 让它笑。前两次只播 6 秒那段，第三次起笑到躺下。
    _setBubble(false);
    widget.brain.triggerLaugh();
    if (widget.settings.hapticOn) HapticFeedback.mediumImpact();
  }

  void _clampAndStore() {
    final maxLeft = _scene.width - _petW - 6;
    final maxTop = _scene.height - _petH - 4;
    final o = Offset(
      _pos!.dx.clamp(6.0, math.max(6.0, maxLeft)).toDouble(),
      _pos!.dy.clamp(8.0, math.max(8.0, maxTop)).toDouble(),
    );
    setState(() => _pos = o);
  }

  double get _petH => _petW / kSpriteAspect;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      _scene = Size(c.maxWidth, c.maxHeight);
      final base = (c.maxWidth * 0.56).clamp(150.0, 300.0);
      _petW = (base * widget.settings.petScale).clamp(90.0, 460.0);
      final petH = _petH;

      if (widget.desktop) {
        // 桌面模式：奶龙钉在窗口底部居中，拖动移动的是整个窗口
        _pos = Offset((c.maxWidth - _petW) / 2, c.maxHeight - petH);
        _lastPetSize = Size(_petW, petH);
      } else {
        // 改大小时保持「脚」的位置不动，不然会往屏幕外长
        final size = Size(_petW, petH);
        if (_lastPetSize != null && _lastPetSize != size) {
          final d = _lastPetSize!;
          _pos = (_pos ?? Offset.zero) +
              Offset((d.width - size.width) / 2, d.height - size.height);
        }
        _lastPetSize = size;

        _pos ??= Offset(c.maxWidth - _petW - 18, c.maxHeight - petH - 6);
        _pos = Offset(
          _pos!.dx
              .clamp(6.0, math.max(6.0, c.maxWidth - _petW - 6))
              .toDouble(),
          _pos!.dy
              .clamp(8.0, math.max(8.0, c.maxHeight - petH - 4))
              .toDouble(),
        );
      }
      final pos = _pos!;
      final bubbleAbove = widget.desktop || pos.dy > 360;

      _reportHitArea(c.maxWidth, pos, petH, bubbleAbove);

      return Stack(
        children: [
          if (_bubble && _day != null)
            Positioned(
              left: _bubbleLeft(c.maxWidth, pos),
              top: bubbleAbove ? null : pos.dy + petH + 12,
              bottom: bubbleAbove ? c.maxHeight - pos.dy + 6 : null,
              child: BubbleReveal(
                key: _bubbleKey,
                child: PetBubble(
                  info: _day!,
                  todos: _todos,
                  moreCount: _more,
                  tailAlign: _tailAlign(pos, c.maxWidth),
                  tailUp: !bubbleAbove,
                ),
              ),
            ),
          Positioned(
            left: pos.dx,
            top: pos.dy,
            width: _petW,
            height: petH,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _poke,
              onLongPress: _longPress,
              onSecondaryTap: widget.desktop ? DesktopBridge.menu : null,
              onPanStart: (_) {
                widget.brain.poke();
                if (widget.desktop) DesktopBridge.dragStart();
              },
              onPanUpdate: (d) {
                if (widget.desktop) return; // 窗口由 Electron 跟着光标移动
                _pos = _pos! + d.delta;
                _clampAndStore();
              },
              onPanEnd: (_) {
                if (widget.desktop) {
                  DesktopBridge.dragEnd();
                  return;
                }
                // 贴近边缘时轻轻吸附
                final left = _pos!.dx;
                if (left < 30) _pos = Offset(12, _pos!.dy);
                if (left + _petW > _scene.width - 30) {
                  _pos = Offset(_scene.width - _petW - 12, _pos!.dy);
                }
                _clampAndStore();
                _savePosition(_pos!);
              },
              onPanCancel: () {
                if (widget.desktop) DesktopBridge.dragEnd();
              },
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (context, child) {
                  final s = _scale.value * _snapScale.value;
                  return Transform(
                    alignment: Alignment.bottomCenter,
                    transform: Matrix4.identity()
                      ..translateByDouble(0.0, (s - 1) * -18, 0.0, 1.0)
                      ..scaleByDouble(1 + (s - 1) * -0.28, s, 1.0, 1.0),
                    child: child,
                  );
                },
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    // 地面投影
                    Positioned(
                      bottom: 0,
                      child: Container(
                        width: _petW * 0.52,
                        height: 16,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(100),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x3A3E2A1C),
                              blurRadius: 14,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                    IndexedStack(
                      index: widget.brain.mood == PetMood.idle ? 0 : 1,
                      children: [
                        IdlePet(
                          settings: widget.settings,
                          enabled: widget.brain.mood == PetMood.idle,
                        ),
                        SpritePlayer(
                          key: _laughKey,
                          asset: _laughAsset,
                          loop: false,
                          playing: widget.brain.mood == PetMood.laughing,
                          onFinished: _onLaughFinished,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    });
  }

  /// 把「奶龙 + 气泡」的范围报给 Windows 外壳，用来做点击穿透。
  void _reportHitArea(double sceneW, Offset pos, double petH, bool bubbleAbove) {
    if (!widget.desktop) return;
    final petRect = Rect.fromLTWH(pos.dx, pos.dy, _petW, petH);
    var hit = petRect.inflate(_petW * 0.12);

    if (_bubble && _day != null) {
      final box = _bubbleKey.currentContext?.findRenderObject() as RenderBox?;
      final w = box?.size.width ?? PetBubble.maxWidth.toDouble();
      final h = box?.size.height ?? 260;
      final left = _bubbleLeft(sceneW, pos);
      final top = bubbleAbove ? pos.dy - h - 6 : pos.dy + petH + 12;
      hit = hit.expandToInclude(Rect.fromLTWH(left, top, w, h));
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) DesktopBridge.reportHitArea(hit);
    });
  }

  double _bubbleLeft(double sceneW, Offset pos) {
    const w = PetBubble.maxWidth;
    final center = pos.dx + _petW / 2;
    return (center - w / 2).clamp(10.0, math.max(10.0, sceneW - w - 10)).toDouble();
  }

  double _tailAlign(Offset pos, double sceneW) {
    const w = PetBubble.maxWidth;
    final left = _bubbleLeft(sceneW, pos);
    final center = pos.dx + _petW / 2;
    return ((center - left) / w).clamp(0.12, 0.88).toDouble();
  }
}
