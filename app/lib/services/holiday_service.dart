import 'package:lunar/lunar.dart';

/// 一天里奶龙要播报的东西（纯数据，不含界面）。
class DayInfo {
  const DayInfo({
    required this.date,
    required this.headline,
    required this.lunarLine,
    this.festivals = const [],
    this.jieQi,
    this.legalHoliday,
    this.isRestDay = false,
    this.adjustment,
    this.nextFestival,
  });

  final DateTime date;
  final String headline; // 10月18日 星期六
  final String lunarLine; // 农历九月初八
  final List<String> festivals; // 重阳节 / 万圣节
  final String? jieQi; // 霜降
  final String? legalHoliday; // 国庆节
  final bool isRestDay;
  final String? adjustment; // 今天调休上班
  final String? nextFestival; // 距离 中秋 还有 12 天

  /// 气泡里除日期外要展示的“标签行”。
  List<String> get tags => [
        if (festivals.isNotEmpty) festivals.join(' · '),
        ?jieQi,
        ?_legalLine,
        ?adjustment,
      ];

  String? get _legalLine {
    final h = legalHoliday;
    if (h == null) return null;
    return isRestDay ? '$h · 假期' : h;
  }
}

class HolidayService {
  const HolidayService();

  DayInfo day(DateTime now) {
    final solar = Solar.fromDate(now);
    final lunar = solar.getLunar();

    final festivals = <String>[
      ...lunar.getFestivals(),
      ...solar.getFestivals(),
    ];
    // 去重并保持顺序（传统节日优先）
    final seen = <String>{};
    festivals.retainWhere(seen.add);

    final jieQi = lunar.getJieQi();
    final holiday = HolidayUtil.getHolidayByYmd(now.year, now.month, now.day);

    final lunarLine =
        '农历${lunar.getMonthInChinese()}月${lunar.getDayInChinese()}';

    return DayInfo(
      date: DateTime(now.year, now.month, now.day),
      headline: '${now.month}月${now.day}日 星期${solar.getWeekInChinese()}',
      lunarLine: lunarLine,
      festivals: festivals,
      jieQi: jieQi.isEmpty ? null : jieQi,
      legalHoliday: holiday?.getName(),
      isRestDay: holiday != null && !holiday.isWork(),
      adjustment: (holiday != null && holiday.isWork()) ? '今天调休上班' : null,
      nextFestival: _nextFestival(now),
    );
  }

  /// 未来 20 天里最近的一个节日/节气。
  String? _nextFestival(DateTime now) {
    for (var i = 1; i <= 20; i++) {
      final d = now.add(Duration(days: i));
      final lunar = Solar.fromDate(d).getLunar();
      final names = <String>[
        ...lunar.getFestivals(),
        ...Solar.fromDate(d).getFestivals(),
      ];
      if (names.isEmpty) continue;
      return '${i == 1 ? '明天' : '$i 天后'}是${names.first}';
    }
    return null;
  }
}
