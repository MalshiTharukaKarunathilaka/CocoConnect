import 'package:flutter/foundation.dart';
import 'api_client.dart';

/// A Sri Lankan public holiday or observance.
class Holiday {
  final String name;

  /// True for a public holiday, false for an observance such as Valentine's Day.
  final bool isPublic;

  const Holiday(this.name, {required this.isPublic});

  /// "Duruthu Full Moon Poya Day · Public holiday"
  String get label => '$name · ${isPublic ? 'Public holiday' : 'Observance'}';
}

/// Sri Lankan holidays for the calendars, from the backend (`GET /api/holidays`),
/// which reads Google's free public holiday calendar. Each year is fetched once
/// and remembered; calendars listen to [revision] to redraw when it arrives.
class HolidayService {
  HolidayService._();

  /// Goes up whenever holidays for another year have been loaded.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static final Map<int, Map<String, Holiday>> _years = {};
  static final Set<int> _loading = {};
  static final Map<int, DateTime> _failedAt = {};
  static const Duration _retryAfter = Duration(minutes: 5);

  static String keyOf(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// The holiday on [day], if it is one and its year has been loaded.
  static Holiday? of(DateTime day) => _years[day.year]?[keyOf(day)];

  /// Starts loading a year if it is not loaded yet. Safe to call on every
  /// build: it does nothing when the year is loaded, loading, or failed a
  /// moment ago.
  static void ensure(int year) {
    if (_years.containsKey(year) || _loading.contains(year)) return;
    final DateTime? failed = _failedAt[year];
    if (failed != null && DateTime.now().difference(failed) < _retryAfter) {
      return;
    }
    _loading.add(year);
    ApiClient.get('/api/holidays', query: {'year': '$year'})
        .then((dynamic data) {
          final Map<String, Holiday> found = parse(data);
          final bool stale = data is Map && data['stale'] == true;
          if (found.isEmpty && stale) {
            _failedAt[year] = DateTime.now(); // try again later
          } else {
            _years[year] = found;
            _failedAt.remove(year);
          }
        })
        .catchError((Object _) {
          // Not signed in, offline, or the server is down: no marks for now.
          _failedAt[year] = DateTime.now();
        })
        .whenComplete(() {
          _loading.remove(year);
          revision.value++;
        });
  }

  /// `{ holidays: [{ date, name, type }] }` into a map by date.
  @visibleForTesting
  static Map<String, Holiday> parse(dynamic data) {
    final Map<String, Holiday> out = {};
    if (data is! Map || data['holidays'] is! List) return out;
    for (final dynamic row in data['holidays'] as List) {
      if (row is! Map) continue;
      final String date = '${row['date']}';
      final String name = '${row['name']}';
      if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date) || name.isEmpty) {
        continue;
      }
      final bool isPublic = row['type'] == 'public';
      final Holiday? already = out[date];
      // Two events on one day: keep the public holiday.
      if (already == null || (!already.isPublic && isPublic)) {
        out[date] = Holiday(name, isPublic: isPublic);
      }
    }
    return out;
  }

  /// Forgets everything (used by tests).
  @visibleForTesting
  static void reset() {
    _years.clear();
    _loading.clear();
    _failedAt.clear();
    revision.value = 0;
  }

  /// Puts holidays in directly (used by tests).
  @visibleForTesting
  static void seed(int year, Map<String, Holiday> holidays) {
    _years[year] = holidays;
    revision.value++;
  }
}
