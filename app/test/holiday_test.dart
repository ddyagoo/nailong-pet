import 'package:flutter_test/flutter_test.dart';
import 'package:nailong_pet/services/holiday_service.dart';

void main() {
  const service = HolidayService();

  test('播报日期与农历', () {
    final day = service.day(DateTime(2026, 10, 18));
    expect(day.headline, '10月18日 星期日');
    expect(day.lunarLine, contains('农历'));
  });

  test('国庆节识别为法定假期', () {
    final day = service.day(DateTime(2026, 10, 1));
    expect(day.legalHoliday, isNotNull);
    expect(day.tags, isNotEmpty);
  });

  test('春节这类农历节日能拿到名字', () {
    final day = service.day(DateTime(2026, 2, 17));
    expect(day.festivals, isNotEmpty);
  });
}
