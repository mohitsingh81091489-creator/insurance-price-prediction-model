import 'package:flutter_test/flutter_test.dart';
import 'package:mindgate/core/utils/date_utils.dart';

void main() {
  group('day keys', () {
    test('formats as yyyy-MM-dd', () {
      expect(AppDateUtils.dayKey(DateTime(2026, 7, 28)), '2026-07-28');
      expect(AppDateUtils.dayKey(DateTime(2026, 1, 5)), '2026-01-05');
    });

    test('round-trips through parse', () {
      final date = DateTime(2026, 3, 17);
      expect(AppDateUtils.parseDayKey(AppDateUtils.dayKey(date)), date);
    });

    test('counts whole days between keys', () {
      expect(AppDateUtils.daysBetween('2026-07-27', '2026-07-28'), 1);
      expect(AppDateUtils.daysBetween('2026-07-28', '2026-07-28'), 0);
      // Across a month boundary — the case a naive subtraction gets wrong.
      expect(AppDateUtils.daysBetween('2026-06-30', '2026-07-01'), 1);
      // Across a leap day.
      expect(AppDateUtils.daysBetween('2028-02-28', '2028-03-01'), 2);
    });

    test('yesterday is exactly one day before today', () {
      expect(AppDateUtils.daysBetween(AppDateUtils.yesterday(), AppDateUtils.today()), 1);
    });

    // Guards the DST hazard. Duration(days: 1) is 24 real hours, so on a
    // spring-forward day a local-time difference is 23h (truncates to 0) and on
    // a fall-back day it is 25h — either one silently breaks a live streak.
    // These assertions only fail when the suite runs in a DST timezone, which
    // is exactly when the bug would reach a user, so they earn their place in CI.
    test('consecutive days are one apart across a whole year, DST included', () {
      var date = DateTime(2026, 1, 1);
      while (date.year == 2026) {
        final next = DateTime(date.year, date.month, date.day + 1);
        expect(
          AppDateUtils.daysBetween(AppDateUtils.dayKey(date), AppDateUtils.dayKey(next)),
          1,
          reason: 'from ${AppDateUtils.dayKey(date)} to ${AppDateUtils.dayKey(next)}',
        );
        date = next;
      }
    });

    test('day keys stay stable through a US and EU DST changeover', () {
      // US spring forward 2026-03-08, fall back 2026-11-01;
      // EU spring forward 2026-03-29, fall back 2026-10-25.
      for (final day in ['2026-03-08', '2026-11-01', '2026-03-29', '2026-10-25']) {
        expect(AppDateUtils.dayKey(AppDateUtils.parseDayKey(day)), day);
      }
      expect(AppDateUtils.daysBetween('2026-03-07', '2026-03-09'), 2);
      expect(AppDateUtils.daysBetween('2026-10-31', '2026-11-02'), 2);
    });
  });

  group('lastNDayKeys', () {
    test('returns n keys, oldest first, ending today', () {
      final keys = AppDateUtils.lastNDayKeys(7);
      expect(keys, hasLength(7));
      expect(keys.last, AppDateUtils.today());
      for (var i = 1; i < keys.length; i++) {
        expect(AppDateUtils.daysBetween(keys[i - 1], keys[i]), 1);
      }
    });
  });

  group('week boundaries', () {
    test('starts the week on Monday', () {
      // 2026-07-28 is a Tuesday.
      final start = AppDateUtils.startOfWeek(DateTime(2026, 7, 28));
      expect(start.weekday, DateTime.monday);
      expect(AppDateUtils.dayKey(start), '2026-07-27');
    });

    test('a Monday is its own week start', () {
      final monday = DateTime(2026, 7, 27);
      expect(AppDateUtils.startOfWeek(monday), AppDateUtils.startOfDay(monday));
    });
  });

  group('duration formatting', () {
    test('drops to the largest meaningful unit', () {
      expect(AppDateUtils.formatDuration(0), '0m');
      expect(AppDateUtils.formatDuration(-30), '0m');
      expect(AppDateUtils.formatDuration(45), '45s');
      expect(AppDateUtils.formatDuration(120), '2m');
      expect(AppDateUtils.formatDuration(3600), '1h');
      expect(AppDateUtils.formatDuration(3660), '1h 1m');
      expect(AppDateUtils.formatDuration(8040), '2h 14m');
    });

    test('formats response seconds to one decimal', () {
      expect(AppDateUtils.formatSeconds(6.44), '6.4s');
      expect(AppDateUtils.formatSeconds(0), '—');
    });
  });
}
