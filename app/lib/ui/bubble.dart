import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/holiday_service.dart';
import '../services/todo_store.dart';
import '../theme.dart';

/// 点一下奶龙弹出来的那张「今日播报」卡片。
class PetBubble extends StatelessWidget {
  const PetBubble({
    super.key,
    required this.info,
    required this.todos,
    required this.moreCount,
    this.tailAlign = 0.5,
    this.tailUp = false,
  });

  final DayInfo info;
  final List<TodoItem> todos;
  final int moreCount;

  /// 尾巴在卡片底部的相对位置（0..1），用来对准奶龙。
  final double tailAlign;

  /// 气泡在奶龙下方时，尾巴朝上。
  final bool tailUp;

  static const double maxWidth = 292;
  static const double tailSize = 15;

  @override
  Widget build(BuildContext context) {
    final shown = todos.take(5).toList();
    final tail = Align(
      alignment: Alignment(tailAlign * 2 - 1, 0),
      child: Transform.translate(
        offset: Offset(0, tailUp ? 2.4 : -2.4),
        child: CustomPaint(
          size: const Size(tailSize * 1.3, tailSize),
          painter: _TailPainter(up: tailUp),
        ),
      ),
    );

    final card = Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: Palette.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Palette.brown, width: 2.4),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2E3E2A1C),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFEFC9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.wb_sunny_rounded,
                  size: 16,
                  color: Palette.orange,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(info.headline, style: T.title),
                    const SizedBox(height: 2),
                    Text(
                      info.jieQi == null
                          ? info.lunarLine
                          : '${info.lunarLine} · ${info.jieQi}',
                      style: T.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (info.tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final tag in info.tags) _Tag(text: tag)],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: Container(height: 1, color: Palette.line)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.checklist_rounded,
                size: 17,
                color: Palette.orange,
              ),
              const SizedBox(width: 6),
              Text(
                todos.isEmpty ? '今天没有待办' : '今日 ${todos.length + moreCount} 项待办',
                style: T.label,
              ),
            ],
          ),
          if (todos.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 23),
              child: Text('可以放心玩啦', style: T.caption),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                children: [
                  for (final t in shown)
                    Padding(
                      padding: const EdgeInsets.only(top: 6, left: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 6),
                            width: 5,
                            height: 5,
                            decoration: const BoxDecoration(
                              color: Palette.yellow,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(t.timeLabel, style: T.caption),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              t.title,
                              style: T.body,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (moreCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 6, left: 13),
                      child: Text('还有 $moreCount 项…', style: T.caption),
                    ),
                ],
              ),
            ),
          if (info.nextFestival != null) ...[
            const SizedBox(height: 10),
            Text('· ${info.nextFestival}', style: T.caption),
          ],
        ],
      ),
    );

    return SizedBox(
      width: maxWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [if (tailUp) tail, card, if (!tailUp) tail],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0CC),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0xFFF0D49B), width: 1),
      ),
      child: Text(text, style: T.caption.copyWith(color: Palette.brown)),
    );
  }
}

class _TailPainter extends CustomPainter {
  const _TailPainter({required this.up});

  final bool up;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Path();
    final border = Path();
    if (up) {
      fill
        ..moveTo(size.width / 2, 0)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      border
        ..moveTo(0, size.height)
        ..lineTo(size.width / 2, 0)
        ..lineTo(size.width, size.height);
    } else {
      fill
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width / 2, size.height)
        ..close();
      border
        ..moveTo(0, 0)
        ..lineTo(size.width / 2, size.height)
        ..lineTo(size.width, 0);
    }
    canvas.drawPath(fill, Paint()..color = Palette.card);
    canvas.drawPath(
      border,
      Paint()
        ..color = Palette.brown
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _TailPainter oldDelegate) =>
      oldDelegate.up != up;
}

/// 气泡出现时的一点弹性。
class BubbleReveal extends StatelessWidget {
  const BubbleReveal({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutBack,
      builder: (context, t, _) {
        final clamped = math.min(t, 1.06);
        // Transform 要在 Opacity 外面：反过来 Opacity 的图层会按未缩放的
        // 尺寸裁掉放大后的内容（尾巴和最后一行字会被切掉）。
        return Transform.scale(
          scale: 0.86 + clamped * 0.16,
          alignment: Alignment.bottomCenter,
          child: Opacity(
            opacity: t.clamp(0, 1),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
