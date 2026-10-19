// 生成 Android 悬浮窗用的「今日播报」数据表。
//
// 原生层不重复实现农历/节气/调休，直接用同一个 lunar 包在构建期算好，
// 打包成 assets/data/calendar.json，运行时按日期查表。
//
// 用法：dart run tool/gen_calendar.dart
import 'dart:convert';
import 'dart:io';

import 'package:lunar/lunar.dart';

String _key(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

void main() {
  final start = DateTime(2024, 1, 1);
  final end = DateTime(2031, 12, 31);
  final out = <String, Map<String, dynamic>>{};

  for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
    final solar = Solar.fromDate(d);
    final lunar = solar.getLunar();

    final festivals = <String>[
      ...lunar.getFestivals(),
      ...solar.getFestivals(),
    ];
    final seen = <String>{};
    festivals.retainWhere(seen.add);

    final jieQi = lunar.getJieQi();
    final holiday = HolidayUtil.getHolidayByYmd(d.year, d.month, d.day);

    String? next;
    for (var i = 1; i <= 20; i++) {
      final n = d.add(Duration(days: i));
      final nl = Solar.fromDate(n).getLunar();
      final names = <String>[
        ...nl.getFestivals(),
        ...Solar.fromDate(n).getFestivals(),
      ];
      if (names.isNotEmpty) {
        next = '${i == 1 ? '明天' : '$i 天后'}是${names.first}';
        break;
      }
    }

    out[_key(d)] = {
      'md': '${d.month}月${d.day}日',
      'wk': '星期${solar.getWeekInChinese()}',
      'l': '农历${lunar.getMonthInChinese()}月${lunar.getDayInChinese()}',
      if (festivals.isNotEmpty) 'f': festivals,
      if (jieQi.isNotEmpty) 'j': jieQi,
      if (holiday != null) 'h': holiday.getName(),
      if (holiday != null) 'rest': !holiday.isWork(),
      if (holiday != null && holiday.isWork()) 'adj': '今天调休上班',
      if (next != null) 'n': next,
    };
  }

  final file = File('android/app/src/main/assets/calendar.json');
  file.createSync(recursive: true);
  file.writeAsStringSync(jsonEncode(out));
  stdout.writeln('${out.length} days -> ${file.path} '
      '(${(file.lengthSync() / 1024).toStringAsFixed(0)} kB)');
}
