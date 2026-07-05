import 'package:finflow/data/models/auto_pay.dart';
import 'package:finflow/data/models/enums.dart';
import 'package:finflow/data/repositories/autopay_engine.dart';
import 'package:flutter_test/flutter_test.dart';

AutoPay ap({
  required RepeatType repeat,
  required DateTime start,
  List<int> weekdays = const [],
  int dayOfMonth = 1,
  int monthOfYear = 1,
  int? yearValue,
  DateTime? lastRun,
}) =>
    AutoPay(
      id: 'x',
      name: 'x',
      amount: 1,
      colorValue: 0,
      iconKey: 'autopay',
      startDate: start,
      repeat: repeat,
      weekdays: weekdays,
      dayOfMonth: dayOfMonth,
      monthOfYear: monthOfYear,
      yearValue: yearValue,
      lastRunDate: lastRun,
    );

void main() {
  group('AutoPayEngine.dueDates', () {
    test('one-time posts on its date, not before', () {
      final a = ap(repeat: RepeatType.none, start: DateTime(2026, 6, 15));
      expect(AutoPayEngine.dueDates(a, DateTime(2026, 6, 20)),
          [DateTime(2026, 6, 15)]);
      expect(AutoPayEngine.dueDates(a, DateTime(2026, 6, 10)), isEmpty);
    });

    test('daily posts every day in range', () {
      final a = ap(repeat: RepeatType.daily, start: DateTime(2026, 6, 18));
      expect(AutoPayEngine.dueDates(a, DateTime(2026, 6, 20)), [
        DateTime(2026, 6, 18),
        DateTime(2026, 6, 19),
        DateTime(2026, 6, 20),
      ]);
    });

    test('weekly posts only on selected weekdays', () {
      // Mondays (1) and Thursdays (4) from Mon 2026-06-01.
      final a = ap(
          repeat: RepeatType.weekly,
          start: DateTime(2026, 6, 1),
          weekdays: [1, 4]);
      final dates = AutoPayEngine.dueDates(a, DateTime(2026, 6, 14));
      expect(dates.isNotEmpty, true);
      expect(dates.every((d) => d.weekday == 1 || d.weekday == 4), true);
    });

    test('monthly posts on the chosen day every month, from the start month',
        () {
      // Day 5, starting June, created 2026-06-01.
      final a = ap(
          repeat: RepeatType.monthly,
          start: DateTime(2026, 6, 1),
          dayOfMonth: 5,
          monthOfYear: 6);
      expect(AutoPayEngine.dueDates(a, DateTime(2026, 8, 31)), [
        DateTime(2026, 6, 5),
        DateTime(2026, 7, 5),
        DateTime(2026, 8, 5),
      ]);
      // Not due before the start month.
      final b = ap(
          repeat: RepeatType.monthly,
          start: DateTime(2026, 6, 1),
          dayOfMonth: 5,
          monthOfYear: 10);
      expect(AutoPayEngine.dueDates(b, DateTime(2026, 8, 31)), isEmpty);
    });

    test('monthly clamps day to short months', () {
      final a = ap(
          repeat: RepeatType.monthly,
          start: DateTime(2026, 1, 1),
          dayOfMonth: 31,
          monthOfYear: 1);
      // February clamps 31 -> 28.
      expect(AutoPayEngine.dueDates(a, DateTime(2026, 2, 28)),
          contains(DateTime(2026, 2, 28)));
    });

    test('yearly posts in the chosen month every year, from the start year',
        () {
      final a = ap(
          repeat: RepeatType.yearly,
          start: DateTime(2026, 1, 1),
          monthOfYear: 3,
          yearValue: 2026);
      expect(AutoPayEngine.dueDates(a, DateTime(2027, 6, 1)), [
        DateTime(2026, 3, 1),
        DateTime(2027, 3, 1),
      ]);
    });

    test('lastRunDate suppresses already-posted occurrences', () {
      final a = ap(
        repeat: RepeatType.daily,
        start: DateTime(2026, 6, 18),
        lastRun: DateTime(2026, 6, 19),
      );
      expect(AutoPayEngine.dueDates(a, DateTime(2026, 6, 20)),
          [DateTime(2026, 6, 20)]);
    });
  });
}
