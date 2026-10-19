import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// 某一天的法定节假日覆盖（来自在线数据）。
class HolidayOverride {
  const HolidayOverride(this.name, this.off);

  final String name;
  final bool off;
}

/// 法定节假日 / 调休的在线同步（Flutter 侧，web 与 Windows 共用）。
///
/// 数据源和 Android 原生层是同一个：NateScarlet/holiday-cn，
/// 每年国务院公告后更新，raw.githubusercontent.com 带 `Access-Control-Allow-Origin: *`，
/// 浏览器里也能直接取。缓存到 SharedPreferences，7 天同步一次。
class HolidaySync {
  static const _base =
      'https://raw.githubusercontent.com/NateScarlet/holiday-cn/master/%d.json';
  static const _lastKey = 'holiday_sync_at';
  static const _yearPrefix = 'holiday_json_';
  static const _interval = Duration(days: 7);

  static final Map<String, HolidayOverride> _overrides = {};

  /// 覆盖表（key = yyyy-MM-dd）。
  static HolidayOverride? lookup(DateTime day) =>
      _overrides[_key(day)];

  static String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// 启动时调一次：先读本地缓存（同步生效），再在后台按需刷新。
  static Future<void> init() async {
    await _loadCache();
    // 故意不 await：网络慢不该拖慢启动
    unawaited(_refreshIfStale());
  }

  static Future<void> _loadCache() async {
    final prefs = await SharedPreferences.getInstance();
    final year = DateTime.now().year;
    for (var y = year - 1; y <= year + 1; y++) {
      final raw = prefs.getString('$_yearPrefix$y');
      if (raw != null) mergeJson(raw);
    }
  }

  /// 解析一份 holiday-cn 的 JSON 并合并进覆盖表。
  @visibleForTesting
  static void mergeJson(String raw) {
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final days = map['days'] as List<dynamic>? ?? const [];
      for (final e in days) {
        if (e is! Map<String, dynamic>) continue;
        final date = e['date'] as String?;
        final name = e['name'] as String?;
        if (date == null || name == null || name.isEmpty) continue;
        _overrides[date] = HolidayOverride(name, e['isOffDay'] != false);
      }
    } catch (_) {
      // 坏数据就当没有
    }
  }

  @visibleForTesting
  static void clearForTest() => _overrides.clear();

  static Future<void> _refreshIfStale() async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getInt(_lastKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - last < _interval.inMilliseconds) return;

    final year = DateTime.now().year;
    var ok = false;
    for (final y in [year, year + 1]) {
      final body = await _fetch(y);
      if (body == null) continue;
      await prefs.setString('$_yearPrefix$y', body);
      mergeJson(body);
      ok = true;
    }
    if (ok) await prefs.setInt(_lastKey, now);
  }

  static Future<String?> _fetch(int year) async {
    try {
      final res = await http
          .get(
            Uri.parse(_base.replaceFirst('%d', '$year')),
            headers: const {'User-Agent': 'nailong-pet'},
          )
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final map = jsonDecode(res.body) as Map<String, dynamic>;
      final days = map['days'] as List<dynamic>? ?? const [];
      // 还没公布的年份（比如 2027 现在）是空 days，不当作有效数据
      if (days.isEmpty) return null;
      return res.body;
    } catch (_) {
      return null;
    }
  }
}
