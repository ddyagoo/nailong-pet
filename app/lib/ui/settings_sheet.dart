import 'package:flutter/material.dart';

import '../services/settings_service.dart';
import '../theme.dart';

Future<void> showSettingsSheet(
  BuildContext context, {
  required SettingsService settings,
  required VoidCallback onResetPosition,
  required VoidCallback onOpenTodos,
  bool showResetPosition = true,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x553E2A1C),
    builder: (_) => _SettingsSheet(
      settings: settings,
      onResetPosition: onResetPosition,
      onOpenTodos: onOpenTodos,
      showResetPosition: showResetPosition,
    ),
  );
}

class _SettingsSheet extends StatefulWidget {
  const _SettingsSheet({
    required this.settings,
    required this.onResetPosition,
    required this.onOpenTodos,
    required this.showResetPosition,
  });

  final SettingsService settings;
  final VoidCallback onResetPosition;
  final VoidCallback onOpenTodos;
  final bool showResetPosition;

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.settings,
      builder: (context, _) {
        final s = widget.settings;
        final pct = (s.sliderValue * 100).round();
        return Container(
          decoration: const BoxDecoration(
            color: Palette.cream,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(top: BorderSide(color: Palette.brown, width: 2)),
          ),
          padding: EdgeInsets.only(
            left: 22,
            right: 22,
            top: 10,
            bottom: 18 + MediaQuery.of(context).padding.bottom,
          ),
          child: SafeArea(
            top: true,
            child: SingleChildScrollView(
              child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Palette.line,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                Text('设置', style: T.display),
                const SizedBox(height: 18),
                _Card(
                  children: [
                    Row(
                      children: [
                        Icon(
                          s.muted
                              ? Icons.volume_off_rounded
                              : Icons.volume_up_rounded,
                          color: Palette.orange,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text('音量', style: T.label),
                        const Spacer(),
                        Text('$pct%', style: T.caption),
                        const SizedBox(width: 10),
                        _PillButton(
                          label: s.muted ? '静音中' : '静音',
                          active: s.muted,
                          onTap: s.toggleMute,
                        ),
                      ],
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 6,
                        activeTrackColor: Palette.yellow,
                        inactiveTrackColor: Palette.line,
                        thumbColor: Palette.card,
                        overlayColor: const Color(0x22F5B93F),
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 11,
                          elevation: 1,
                        ),
                        trackShape: const RoundedRectSliderTrackShape(),
                      ),
                      child: Slider(
                        value: s.sliderValue,
                        onChanged: (v) => s.setVolume(v),
                      ),
                    ),
                    _SwitchRow(
                      title: '静音时轻振动',
                      subtitle: '点了没声音，但会抖一下告诉你它听见了',
                      value: s.hapticOn,
                      onChanged: s.setHapticOn,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _Card(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.aspect_ratio_rounded,
                            color: Palette.orange, size: 20),
                        const SizedBox(width: 8),
                        Text('奶龙大小', style: T.label),
                        const Spacer(),
                        Text('${(s.petScale * 100).round()}%', style: T.caption),
                      ],
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 6,
                        activeTrackColor: Palette.yellow,
                        inactiveTrackColor: Palette.line,
                        thumbColor: Palette.card,
                        overlayColor: const Color(0x22F5B93F),
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 11,
                          elevation: 1,
                        ),
                      ),
                      child: Slider(
                        min: 0.6,
                        max: 1.6,
                        value: s.petScale,
                        onChanged: (v) =>
                            s.setPetScale((v * 20).round() / 20),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _Card(
                  children: [
                    _SwitchRow(
                      title: '放久了会笑',
                      subtitle: '点了 / 拖了奶龙才重新计时，碰屏幕别处不算',
                      value: s.laughOn,
                      onChanged: s.setLaughOn,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.timer_outlined,
                            size: 18, color: Palette.orange),
                        const SizedBox(width: 8),
                        Text('静置区间', style: T.label),
                        const Spacer(),
                        Text(
                          '${s.idleMin.round()}–${s.idleMax.round()} 秒',
                          style: T.caption,
                        ),
                      ],
                    ),
                    RangeSlider(
                      values: RangeValues(s.idleMin, s.idleMax),
                      min: 10,
                      max: 300,
                      divisions: 58,
                      activeColor: Palette.yellow,
                      inactiveColor: Palette.line,
                      labels: RangeLabels(
                        '${s.idleMin.round()}s',
                        '${s.idleMax.round()}s',
                      ),
                      onChanged: (v) =>
                          s.setIdleRange(v.start.roundToDouble(), v.end.roundToDouble()),
                    ),
                    Text(
                      '在这个区间的随机一秒笑，笑完重新计时进入下一轮',
                      style: T.caption.copyWith(fontSize: 11),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const Icon(Icons.remove_red_eye_outlined,
                            size: 18, color: Palette.orange),
                        const SizedBox(width: 8),
                        Text('眨眼间隔', style: T.label),
                        const Spacer(),
                        Text(
                          '${s.blinkMin.toStringAsFixed(1)}–'
                          '${s.blinkMax.toStringAsFixed(1)} 秒',
                          style: T.caption,
                        ),
                      ],
                    ),
                    RangeSlider(
                      values: RangeValues(s.blinkMin, s.blinkMax),
                      min: 0.5,
                      max: 10,
                      divisions: 19,
                      activeColor: Palette.yellow,
                      inactiveColor: Palette.line,
                      labels: RangeLabels(
                        '${s.blinkMin.toStringAsFixed(1)}s',
                        '${s.blinkMax.toStringAsFixed(1)}s',
                      ),
                      onChanged: (v) => s.setBlinkRange(v.start, v.end),
                    ),
                    Text(
                      '待机动画播完停这么久再播，随机取；改动下一段生效',
                      style: T.caption.copyWith(fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _Card(
                  children: [
                    _LinkRow(
                      icon: Icons.checklist_rounded,
                      title: '管理待办',
                      subtitle: '真机读系统日历；浏览器里是本地清单',
                      onTap: widget.onOpenTodos,
                    ),
                    if (widget.showResetPosition) ...[
                      const SizedBox(height: 12),
                      _LinkRow(
                        icon: Icons.open_with_rounded,
                        title: '让奶龙回到右下角',
                        subtitle: '拖到别处了可以一键叫回来',
                        onTap: () {
                          widget.onResetPosition();
                          Navigator.of(context).pop();
                        },
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 18),
                Center(
                  child: Text('奶龙桌宠 · 0.1.0',
                      style: T.caption.copyWith(
                          color: Palette.brownSoft.withValues(alpha: 0.55))),
                ),
              ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Palette.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Palette.line, width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: T.label),
              const SizedBox(height: 3),
              Text(subtitle, style: T.caption),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: Palette.card,
          activeTrackColor: Palette.yellow,
          inactiveThumbColor: Palette.card,
          inactiveTrackColor: Palette.line,
        ),
      ],
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: Color(0xFFFFEFC9),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 19, color: Palette.orange),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: T.label),
                const SizedBox(height: 2),
                Text(subtitle, style: T.caption),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Palette.brownSoft),
        ],
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? Palette.brown : const Color(0xFFFFEFC9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: active ? Palette.brown : const Color(0xFFF0D49B)),
        ),
        child: Text(
          label,
          style: T.caption.copyWith(
            color: active ? Palette.cream : Palette.brown,
          ),
        ),
      ),
    );
  }
}
