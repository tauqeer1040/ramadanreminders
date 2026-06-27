import 'package:hijri/hijri_calendar.dart';

/// Hijri date helpers.
/// Location-based prayer times have been removed to reduce permissions.
class PrayerTimeService {
  static String getHijriDate(DateTime date) {
    final hDate = HijriCalendar.fromDate(date);
    return '${hDate.hDay} ${hDate.longMonthName} ${hDate.hYear} AH';
  }

  static String getCurrentHijriDate() {
    final now = DateTime.now();
    final hDate = HijriCalendar.fromDate(now);
    return '${hDate.hDay} ${hDate.longMonthName} ${hDate.hYear} AH';
  }

  static HijriCalendar getDynamicHijriDate() {
    final DateTime now = DateTime.now();
    final int tzOffset = now.timeZoneOffset.inHours;

    int adjustment = 0;
    if (tzOffset >= 3 && tzOffset <= 4) {
      adjustment = 1;
    } else if (tzOffset >= 5) {
      adjustment = -1;
    } else {
      adjustment = 0;
    }

    final adjustedDate = now.add(Duration(days: adjustment));
    return HijriCalendar.fromDate(adjustedDate);
  }
}
