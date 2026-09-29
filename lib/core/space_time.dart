import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Calendar boundaries shared by every viewer of a space.
class SpaceTime {
  SpaceTime._();
  static bool _ready = false;

  static tz.Location location(String? zone) {
    if (!_ready) {
      tzdata.initializeTimeZones();
      _ready = true;
    }
    try {
      return tz.getLocation(zone ?? 'UTC');
    } catch (_) {
      return tz.UTC;
    }
  }

  static DateTime nextMidnight(String? zone, DateTime instant) {
    final loc = location(zone);
    final local = tz.TZDateTime.from(instant, loc);
    return tz.TZDateTime(loc, local.year, local.month, local.day + 1);
  }

  static String localDate(String? zone, DateTime instant) {
    final local = tz.TZDateTime.from(instant, location(zone));
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }

  static DateTime basicHistoryStart(String? zone, DateTime instant) {
    final loc = location(zone);
    final local = tz.TZDateTime.from(instant, loc);
    return tz.TZDateTime(loc, local.year, local.month, local.day - 3);
  }
}
