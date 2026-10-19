import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../pet/pet_brain.dart';
import '../services/audio_service.dart';
import '../services/desktop_bridge.dart';
import '../services/holiday_service.dart';
import '../services/settings_service.dart';
import '../services/todo_store.dart';
import '../theme.dart';
import '../ui/pet_layer.dart';
import '../ui/settings_sheet.dart';
import '../ui/todo_sheet.dart';

/// 模拟「手机桌面」：一层暖色壁纸 + 浮在上面的奶龙。
class HomeScene extends StatefulWidget {
  const HomeScene({
    super.key,
    required this.brain,
    required this.settings,
    required this.audio,
    required this.todos,
  });

  final PetBrain brain;
  final SettingsService settings;
  final AudioService audio;
  final TodoStore todos;

  @override
  State<HomeScene> createState() => _HomeSceneState();
}

class _HomeSceneState extends State<HomeScene> {
  final _petKey = GlobalKey<PetLayerState>();
  final _holiday = const HolidayService();
  late DayInfo _day;
  late final AppLifecycleListener _lifecycle;
  Timer? _clock;
  bool _hint = true;

  @override
  void initState() {
    super.initState();
    _day = _holiday.day(DateTime.now());
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _day = _holiday.day(DateTime.now()));
    });
    Future.delayed(const Duration(seconds: 9), () {
      if (mounted) setState(() => _hint = false);
    });
    _lifecycle = AppLifecycleListener(
      onShow: () {
        widget.brain.restartIdle();
        if (mounted) setState(() => _day = _holiday.day(DateTime.now()));
      },
    );
    widget.brain.start();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _clock?.cancel();
    super.dispose();
  }

  void _openSettings() {
    // 设置面板比奶龙大，得让整个窗口都能点，不然点击穿透会把面板吃掉
    DesktopBridge.setInteractive(true);
    showSettingsSheet(
      context,
      settings: widget.settings,
      onResetPosition: () => _petKey.currentState?.resetPosition(),
      onOpenTodos: () => showTodoSheet(context, widget.todos),
    ).whenComplete(() => DesktopBridge.setInteractive(false));
  }

  @override
  Widget build(BuildContext context) {
    if (DesktopBridge.active) {
      // Windows 桌面模式：只有奶龙，背景透明，拖动移动整个窗口
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: PetLayer(
          brain: widget.brain,
          settings: widget.settings,
          audio: widget.audio,
          todos: widget.todos,
          desktop: true,
        ),
      );
    }
    return Scaffold(
      body: LayoutBuilder(builder: (context, c) {
        final scene = Stack(
          children: [
            const Positioned.fill(child: _Wallpaper()),
            Positioned(
              left: 14,
              right: 12,
              top: MediaQuery.of(context).padding.top + 42,
              child: Row(
                children: [
                  Flexible(child: _ClockChip(day: _day)),
                  const SizedBox(width: 8),
                  _RoundIcon(
                    icon: Icons.checklist_rounded,
                    onTap: () => showTodoSheet(context, widget.todos),
                  ),
                  const SizedBox(width: 6),
                  _RoundIcon(
                    icon: widget.settings.muted
                        ? Icons.volume_off_rounded
                        : Icons.volume_up_rounded,
                    onTap: () => setState(widget.settings.toggleMute),
                  ),
                  const SizedBox(width: 6),
                  _RoundIcon(
                    icon: Icons.tune_rounded,
                    onTap: _openSettings,
                  ),
                ],
              ),
            ),
            Positioned.fill(
              child: PetLayer(
                key: _petKey,
                brain: widget.brain,
                settings: widget.settings,
                audio: widget.audio,
                todos: widget.todos,
              ),
            ),
            if (_hint)
              Positioned(
                left: 16,
                bottom: MediaQuery.of(context).padding.bottom + 26,
                child: IgnorePointer(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeOut,
                      builder: (context, t, child) => Opacity(opacity: t, child: child),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xCC3E2A1C),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '点一下看今天 · 长按让它笑',
                          style: T.caption.copyWith(color: Palette.cream),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );

        if (c.maxWidth < 620) return scene;

        return ColoredBox(
          color: const Color(0xFFF6EBDC),
          child: Stack(
            children: [
              const Positioned.fill(child: _DeskBackdrop()),
              Positioned(
                left: 0,
                right: 0,
                top: 14,
                child: Center(
                  child: Text(
                    'web 预览 · 装到手机上时，奶龙会浮在任何 App 之上',
                    style: T.caption.copyWith(color: Palette.brownSoft),
                  ),
                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 44, 24, 24),
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: _PhoneShell(child: scene),
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _PhoneShell extends StatelessWidget {
  const _PhoneShell({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 390,
      height: 844,
      decoration: BoxDecoration(
        color: const Color(0xFF3E2A1C),
        borderRadius: BorderRadius.circular(52),
        boxShadow: const [
          BoxShadow(
              color: Color(0x333E2A1C), blurRadius: 40, offset: Offset(0, 18)),
        ],
      ),
      padding: const EdgeInsets.all(9),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(44),
        child: Stack(
          children: [
            Positioned.fill(child: child),
            // 刘海
            Align(
              alignment: Alignment.topCenter,
              child: Container(
                width: 108,
                height: 26,
                margin: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B1410),
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeskBackdrop extends StatelessWidget {
  const _DeskBackdrop();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF9F0E3), Color(0xFFF3E2CD)],
        ),
      ),
    );
  }
}

class _Wallpaper extends StatelessWidget {
  const _Wallpaper();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _WallpaperPainter());
  }
}

class _WallpaperPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFF8EC), Color(0xFFFFDFB4), Color(0xFFFFC68F)],
          stops: [0, 0.52, 1],
        ).createShader(rect),
    );

    void blob(Offset c, double r, Color color) {
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }

    blob(Offset(size.width * 0.86, size.height * 0.16), size.width * 0.52,
        const Color(0x66FFC96B));
    blob(Offset(size.width * 0.12, size.height * 0.34), size.width * 0.46,
        const Color(0x55FFB98E));
    blob(Offset(size.width * 0.6, size.height * 0.92), size.width * 0.7,
        const Color(0x44FFE0A8));

    // 几颗很小的亮点，让壁纸不那么空
    final rnd = math.Random(7);
    for (var i = 0; i < 26; i++) {
      final p = Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height * 0.7);
      canvas.drawCircle(p, rnd.nextDouble() * 1.6 + 0.6,
          Paint()..color = Colors.white.withValues(alpha: 0.35));
    }

    // 底部一点暖光
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.82, size.width, size.height * 0.18),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0x00FFB877),
            const Color(0x33FF9E4F),
          ],
        ).createShader(
            Rect.fromLTWH(0, size.height * 0.82, size.width, size.height * 0.18)),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ClockChip extends StatelessWidget {
  const _ClockChip({required this.day});
  final DayInfo day;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xCCFFFDF7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x33A07A50)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$hh:$mm',
              style: T.label.copyWith(
                  fontSize: 17, fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Container(width: 1, height: 12, color: Palette.line),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              day.headline.replaceFirst(' ', ' · '),
              style: T.caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: const Color(0xCCFFFDF7),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0x33A07A50)),
        ),
        child: Icon(icon, size: 19, color: Palette.brown),
      ),
    );
  }
}
