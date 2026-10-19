import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TodoItem {
  TodoItem({
    required this.id,
    required this.title,
    required this.due,
    this.done = false,
    this.source = 'demo',
    this.allDay = false,
  });

  final String id;
  final String title;
  final DateTime due;
  bool done;
  final String source; // demo | calendar
  final bool allDay;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'due': due.toIso8601String(),
        'done': done,
        'source': source,
        'allDay': allDay,
      };

  static TodoItem fromJson(Map<String, dynamic> j) => TodoItem(
        id: j['id'] as String,
        title: j['title'] as String,
        due: DateTime.parse(j['due'] as String),
        done: j['done'] as bool? ?? false,
        source: j['source'] as String? ?? 'demo',
        allDay: j['allDay'] as bool? ?? false,
      );

  /// 2026-10-18 09:30 这种给人看的格式
  String get timeLabel {
    if (allDay) return '全天';
    final h = due.hour.toString().padLeft(2, '0');
    final m = due.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

/// 待办数据源。web 版用本地示例清单，Android 版之后换成系统日历，
/// 两者对界面暴露的接口保持一致。
class TodoStore extends ChangeNotifier {
  static const _key = 'todos';

  final List<TodoItem> _items = [];
  bool _loaded = false;

  List<TodoItem> get all => List.unmodifiable(_items);
  bool get loaded => _loaded;

  /// 今天到期 + 已经过期没勾掉的。
  List<TodoItem> get today {
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
    return _items
        .where((t) => !t.done && !t.due.isAfter(end))
        .toList()
      ..sort((a, b) => a.due.compareTo(b.due));
  }

  List<TodoItem> get upcoming {
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
    return _items.where((t) => !t.done && t.due.isAfter(end)).toList()
      ..sort((a, b) => a.due.compareTo(b.due));
  }

  int get remaining => _items.where((t) => !t.done).length;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) {
      _seedDemo();
    } else {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        _items
          ..clear()
          ..addAll(list.map((e) => TodoItem.fromJson(e as Map<String, dynamic>)));
      } catch (_) {
        _seedDemo();
      }
    }
    _loaded = true;
    notifyListeners();
    await _persist();
  }

  void _seedDemo() {
    final now = DateTime.now();
    final base = DateTime(now.year, now.month, now.day);
    _items
      ..clear()
      ..addAll([
        TodoItem(
            id: 'demo1',
            title: '把周报发给组长',
            due: base.add(const Duration(hours: 10))),
        TodoItem(
            id: 'demo2',
            title: '取快递（驿站 18:00 关门）',
            due: base.add(const Duration(hours: 15, minutes: 30))),
        TodoItem(
            id: 'demo3',
            title: '给奶龙换个姿势',
            due: base.add(const Duration(hours: 21))),
      ]);
  }

  Future<void> add(String title, {DateTime? due}) async {
    if (title.trim().isEmpty) return;
    final now = DateTime.now();
    _items.add(TodoItem(
      id: now.microsecondsSinceEpoch.toString(),
      title: title.trim(),
      due: due ?? DateTime(now.year, now.month, now.day, 23, 59),
    ));
    notifyListeners();
    await _persist();
  }

  Future<void> toggle(String id) async {
    final item = _items.where((t) => t.id == id).firstOrNull;
    if (item == null) return;
    item.done = !item.done;
    notifyListeners();
    await _persist();
  }

  Future<void> remove(String id) async {
    _items.removeWhere((t) => t.id == id);
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(_items.map((e) => e.toJson()).toList()));
  }
}
