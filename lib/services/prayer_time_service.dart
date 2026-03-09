import 'package:adhan/adhan.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hijri/hijri_calendar.dart';

import 'package:shared_preferences/shared_preferences.dart';

class PrayerTimeService {
  /// Fetches the user's current coordinates.
  /// Requests permission if not granted.
  static Future<Position?> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      // We don't request it automatically here anymore,
      // let the user explicitly tap the action prompt.
      // But for backward compatibility we leave this or comment it out?
      // Actually let's return null if denied to prevent random popups without user intent.
      return null;
    }

    if (permission == LocationPermission.deniedForever) {
      return null;
    }

    return await Geolocator.getCurrentPosition();
  }

  static Future<bool> requestLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  /// Calculates prayer times for today at the user's location.
  static Future<PrayerTimes?> getPrayerTimes() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble('cached_latitude');
    final lon = prefs.getDouble('cached_longitude');

    if (lat != null && lon != null) {
      final coordinates = Coordinates(lat, lon);
      final params = CalculationMethod.muslim_world_league.getParameters();
      params.madhab = Madhab.hanafi;
      final date = DateComponents.from(DateTime.now());
      return PrayerTimes(coordinates, date, params);
    }

    final position = await _determinePosition();
    if (position == null) return null;

    await prefs.setDouble('cached_latitude', position.latitude);
    await prefs.setDouble('cached_longitude', position.longitude);

    final coordinates = Coordinates(position.latitude, position.longitude);
    final params = CalculationMethod.muslim_world_league.getParameters();
    params.madhab = Madhab.hanafi;
    final date = DateComponents.from(DateTime.now());
    return PrayerTimes(coordinates, date, params);
  }

  /// Returns localized Hijri calculation adjusted by timezone offset (+1 Middle East, -1 Asia, etc).
  static HijriCalendar getDynamicHijriDate() {
    final DateTime now = DateTime.now();
    final int tzOffset = now.timeZoneOffset.inHours;

    // Based on user: Middle East is +1, Asia is -1 relative to some baseline.
    // Let's use UTC+3 (Middle East) as standard +1, UTC+5 or more (Asia) as -1.
    // If standard zero is Makkah (UTC+3) according to library (Umm al-Qura).
    // Let's model their specific request exactly:
    int adjustment = 0;

    // Middle East roughly UTC+3 to UTC+4
    if (tzOffset >= 3 && tzOffset <= 4) {
      adjustment = 1;
    }
    // Asia roughly UTC+5 and above
    else if (tzOffset >= 5) {
      adjustment = -1;
    }
    // Europe/Africa/Americas (below UTC+3)
    else {
      adjustment = 0;
    }

    // Adjusting Hijri by shifting the Gregorian date we feed into its calculator.
    final adjustedDate = now.add(Duration(days: adjustment));
    return HijriCalendar.fromDate(adjustedDate);
  }
}
