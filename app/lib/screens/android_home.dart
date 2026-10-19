import 'package:flutter/material.dart';

import '../services/overlay_bridge.dart';
import '../services/settings_service.dart';
import '../services/todo_store.dart';
import '../theme.dart';
import '../ui/settings_sheet.dart';
import '../ui/todo_sheet.dart';

/// Android 上的「主页」：把奶龙放到桌面上、检查权限、进设置。
class AndroidHome extends StatefulWidget {
  const AndroidHome({
    super.key,
    required this.settings,
    required this.todos,
  });

  final SettingsService settings;
  final TodoStore todos;

  @override
  State<AndroidHome> createState() => _AndroidHomeState();
}

class _AndroidHomeState extends State<AndroidHome> with WidgetsBindingObserver {
  Map<String, bool> _status = const {};
  bool _busy = false;
  bool _askedOverlayOnce = false;
  String _version = '';

  bool get _overlay => _status['overlay'] == true;
  bool get _calendar => _status['calendar'] == true;
  bool get _notification => _status['notification'] == true;
  bool get _running => _status['running'] == true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    OverlayBridge.init();
    OverlayBridge.onRefresh = _refresh;
    _refresh();
    OverlayBridge.version().then((v) {
      if (mounted) setState(() => _version = v);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    OverlayBridge.onRefresh = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final s = await OverlayBridge.status();
    if (mounted) setState(() => _status = s);
  }

  Future<void> _toggleOverlay() async {
    if (_busy) return;
    setState(() => _busy = true);
    final wasRunning = _running;
    try {
      if (_running) {
        await OverlayBridge.stop();
        await Future<void>.delayed(const Duration(milliseconds: 300));
      } else {
        if (!_overlay) {
          _askedOverlayOnce = true;
          await OverlayBridge.requestOverlay();
        } else {
          final ok = await OverlayBridge.start();
          if (!ok) await OverlayBridge.requestOverlay();
        }
      }
      await _refresh();
      if (!wasRunning && _running && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('奶龙已经放到桌面了，回到主屏幕就能看到'),
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _checkUpdate() async {
    final r = await OverlayBridge.checkUpdate();
    if (!mounted) return;
    final message = (r['message'] ?? '检查失败').toString();
    if (r['newer'] == true) {
      final url = (r['url'] ?? '').toString();
      final notes = (r['notes'] ?? '').toString().trim();
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Palette.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Palette.brown, width: 2),
          ),
          title: Text(message, style: T.title),
          content: notes.isEmpty
              ? null
              : ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: SingleChildScrollView(
                    child: Text(notes, style: T.caption),
                  ),
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('以后再说', style: T.caption),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Palette.yellow,
                foregroundColor: Palette.brown,
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
                if (url.isNotEmpty) OverlayBridge.openUrl(url);
              },
              child: const Text('去 GitHub 下载'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _openSettings() {
    showSettingsSheet(
      context,
      settings: widget.settings,
      onResetPosition: () {},
      onOpenTodos: () => showTodoSheet(context, widget.todos),
      showResetPosition: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFF8EC), Color(0xFFFFE3C4), Color(0xFFFFD3AC)],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            children: [
              Row(
                children: [
                  Text('奶龙桌宠', style: T.display),
                  const Spacer(),
                  _CircleButton(
                    icon: Icons.tune_rounded,
                    onTap: _openSettings,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text('把奶龙放到桌面上：点一下听今天，长按让它笑。', style: T.caption),
              const SizedBox(height: 18),
              _PreviewCard(running: _running, scale: widget.settings.petScale),
              const SizedBox(height: 16),
              _Card(
                children: [
                  _PermissionRow(
                    icon: Icons.layers_rounded,
                    title: '悬浮窗权限',
                    subtitle: '让奶龙浮在其他 App 之上',
                    ok: _overlay,
                    onTap: () async {
                      await OverlayBridge.requestOverlay();
                      _askedOverlayOnce = true;
                    },
                  ),
                  const SizedBox(height: 14),
                  _PermissionRow(
                    icon: Icons.calendar_month_rounded,
                    title: '日历权限',
                    subtitle: '读取今天的日程，用来播报待办',
                    ok: _calendar,
                    onTap: OverlayBridge.requestCalendar,
                  ),
                  const SizedBox(height: 14),
                  _PermissionRow(
                    icon: Icons.notifications_active_rounded,
                    title: '通知权限',
                    subtitle: '悬浮窗运行时会有一条常驻通知',
                    ok: _notification,
                    onTap: OverlayBridge.requestNotification,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 54,
                child: FilledButton(
                  onPressed: _busy ? null : _toggleOverlay,
                  style: FilledButton.styleFrom(
                    backgroundColor: _running ? Palette.card : Palette.yellow,
                    foregroundColor: Palette.brown,
                    side: const BorderSide(color: Palette.brown, width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    elevation: 0,
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          _running
                              ? '收回奶龙'
                              : (_overlay ? '把奶龙放到桌面' : '先开启悬浮窗权限'),
                          style: T.label.copyWith(fontSize: 17),
                        ),
                ),
              ),
              if (_askedOverlayOnce && !_overlay) ...[
                const SizedBox(height: 10),
                Text(
                  '在系统页面里找到「奶龙桌宠」，允许它显示在其他应用上层，然后返回这里。',
                  style: T.caption,
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _SmallButton(
                      icon: Icons.checklist_rounded,
                      label: '待办',
                      onTap: () => showTodoSheet(context, widget.todos),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SmallButton(
                      icon: Icons.battery_saver_rounded,
                      label: '电池白名单',
                      onTap: OverlayBridge.openBatterySettings,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              _Card(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _checkUpdate,
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFFEFC9),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.system_update_rounded,
                              size: 19, color: Palette.orange),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('检查更新', style: T.label),
                              const SizedBox(height: 2),
                              Text(
                                _version.isEmpty
                                    ? '去 GitHub 看有没有新版本'
                                    : '当前版本 $_version · 去 GitHub 看有没有新版本',
                                style: T.caption,
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded,
                            color: Palette.brownSoft),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Center(
                child: Text(
                  '放到桌面后，回到这里改大小 / 音量会立刻生效',
                  style: T.caption.copyWith(
                      color: Palette.brownSoft.withValues(alpha: 0.7)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.running, required this.scale});

  final bool running;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 240,
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9F0),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Palette.line, width: 1.4),
      ),
      child: Stack(
        children: [
          Center(
            child: Image.asset(
              'assets/pet/idle.webp',
              height: 190,
              fit: BoxFit.contain,
            ),
          ),
          Positioned(
            left: 14,
            top: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: running ? Palette.leaf : const Color(0xFFE9D6BC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                running ? '在桌面上' : '还没放出去',
                style: T.caption.copyWith(
                  color: running ? Palette.cream : Palette.brown,
                ),
              ),
            ),
          ),
          Positioned(
            right: 14,
            bottom: 12,
            child: Text(
              '${(scale * 100).round()}%',
              style: T.caption.copyWith(color: Palette.brownSoft),
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.ok,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool ok;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: ok ? null : onTap,
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
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: ok ? const Color(0xFFE7F0E2) : const Color(0xFFFFEFC9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  ok ? Icons.check_rounded : Icons.arrow_forward_rounded,
                  size: 14,
                  color: ok ? Palette.leaf : Palette.orange,
                ),
                const SizedBox(width: 3),
                Text(ok ? '已开启' : '去开启',
                    style: T.caption.copyWith(
                      color: ok ? Palette.leaf : Palette.orange,
                    )),
              ],
            ),
          ),
        ],
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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

class _SmallButton extends StatelessWidget {
  const _SmallButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: Palette.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Palette.line, width: 1.4),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: Palette.orange),
            const SizedBox(width: 6),
            Text(label, style: T.label),
          ],
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Palette.card,
          shape: BoxShape.circle,
          border: Border.all(color: Palette.line, width: 1.4),
        ),
        child: Icon(icon, size: 19, color: Palette.brown),
      ),
    );
  }
}
