import 'package:flutter/material.dart';

import '../services/todo_store.dart';
import '../theme.dart';

Future<void> showTodoSheet(BuildContext context, TodoStore store) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x553E2A1C),
    builder: (_) => _TodoSheet(store: store),
  );
}

class _TodoSheet extends StatefulWidget {
  const _TodoSheet({required this.store});
  final TodoStore store;

  @override
  State<_TodoSheet> createState() => _TodoSheetState();
}

class _TodoSheetState extends State<_TodoSheet> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    await widget.store.add(text);
    _controller.clear();
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final today = widget.store.today;
        final later = widget.store.upcoming;
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.78,
            ),
            decoration: const BoxDecoration(
              color: Palette.cream,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              border: Border(top: BorderSide(color: Palette.brown, width: 2)),
            ),
            padding: const EdgeInsets.fromLTRB(22, 10, 22, 16),
            child: SafeArea(
              top: false,
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('待办', style: T.display),
                      const SizedBox(width: 10),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('今天 ${today.length} 项', style: T.caption),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded,
                            color: Palette.brownSoft),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        if (today.isEmpty)
                          _EmptyHint()
                        else
                          for (final t in today) _TodoRow(store: widget.store, item: t),
                        if (later.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Text('之后', style: T.label.copyWith(color: Palette.brownSoft)),
                          const SizedBox(height: 4),
                          for (final t in later)
                            _TodoRow(store: widget.store, item: t, dim: true),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          focusNode: _focus,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _add(),
                          style: T.body,
                          decoration: InputDecoration(
                            hintText: '加一件今天要做的事…',
                            hintStyle: T.caption,
                            filled: true,
                            fillColor: Palette.card,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide:
                                  const BorderSide(color: Palette.line, width: 1.4),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide:
                                  const BorderSide(color: Palette.line, width: 1.4),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide:
                                  const BorderSide(color: Palette.yellow, width: 1.8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: _add,
                        child: Container(
                          width: 46,
                          height: 46,
                          decoration: const BoxDecoration(
                            color: Palette.yellow,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Color(0x33E0992B),
                                blurRadius: 12,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.add_rounded,
                              color: Palette.brown, size: 26),
                        ),
                      ),
                    ],
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

class _TodoRow extends StatelessWidget {
  const _TodoRow({required this.store, required this.item, this.dim = false});

  final TodoStore store;
  final TodoItem item;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final done = item.done;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => store.toggle(item.id),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: done ? Palette.leaf : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: done ? Palette.leaf : Palette.line,
                  width: 2,
                ),
              ),
              child: done
                  ? const Icon(Icons.check_rounded,
                      size: 15, color: Palette.cream)
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: T.body.copyWith(
                    decoration: done ? TextDecoration.lineThrough : null,
                    color: done ? Palette.brownSoft : Palette.brown,
                  ),
                ),
                Text(
                  '${item.timeLabel} · ${_sourceLabel(item.source)}',
                  style: T.caption.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.delete_outline_rounded,
                size: 19, color: dim ? Palette.line : Palette.brownSoft),
            onPressed: () => store.remove(item.id),
          ),
        ],
      ),
    );
  }

  String _sourceLabel(String source) =>
      source == 'calendar' ? '系统日历' : '本地';
}

class _EmptyHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 26),
      alignment: Alignment.center,
      child: Column(
        children: [
          const Text('🎉', style: TextStyle(fontSize: 28)),
          const SizedBox(height: 8),
          Text('今天没有待办', style: T.label),
          const SizedBox(height: 4),
          Text('奶龙可以陪你玩一天', style: T.caption),
        ],
      ),
    );
  }
}
