import 'package:flutter_test/flutter_test.dart';
import 'package:nailong_pet/services/holiday_service.dart';
import 'package:nailong_pet/services/holiday_sync.dart';

void main() {
  setUp(HolidaySync.clearForTest);

  test('在线节假日数据覆盖内置表', () {
    HolidaySync.mergeJson('''
    {"year":2026,"days":[
      {"name":"国庆节","date":"2026-10-01","isOffDay":true},
      {"name":"国庆节","date":"2026-10-08","isOffDay":true},
      {"name":"国庆节","date":"2026-09-27","isOffDay":false}
    ]}
    ''');

    final off = HolidaySync.lookup(DateTime(2026, 10, 1));
    expect(off?.name, '国庆节');
    expect(off?.off, true);

    final work = HolidaySync.lookup(DateTime(2026, 9, 27));
    expect(work?.off, false);

    final restDay = const HolidayService().day(DateTime(2026, 10, 1));
    expect(restDay.legalHoliday, '国庆节');
    expect(restDay.isRestDay, true);
    expect(restDay.adjustment, isNull);

    final adjusted = const HolidayService().day(DateTime(2026, 9, 27));
    expect(adjusted.adjustment, '今天调休上班');
  });

  test('没有覆盖时用内置表', () {
    final day = const HolidayService().day(DateTime(2026, 10, 1));
    expect(day.legalHoliday, isNotNull);
    expect(day.isRestDay, true);
  });

  test('空 days 的年份不会覆盖已有数据', () {
    HolidaySync.mergeJson('{"year":2027,"days":[]}');
    expect(HolidaySync.lookup(DateTime(2027, 1, 1)), isNull);
  });
}
