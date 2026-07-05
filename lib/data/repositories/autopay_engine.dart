import 'dart:convert';

import 'package:hive_ce_flutter/hive_flutter.dart';

import '../models/account.dart';
import '../models/app_transaction.dart';
import '../models/auto_pay.dart';
import '../models/enums.dart';
import '../models/payment_mode.dart';

/// Pure recurrence + posting logic for auto-pays, operating directly on Hive
/// boxes. Shared by the in-app notifier and the background alarm isolate so the
/// rules stay identical in both places.
class AutoPayEngine {
  AutoPayEngine._();

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static int _daysInMonth(int year, int month) =>
      DateTime(year, month + 1, 0).day;

  /// Day-of-month clamped to the month's length (e.g. 31 → 30/28).
  static DateTime _monthlyDate(int year, int month, int day) =>
      DateTime(year, month, day.clamp(1, _daysInMonth(year, month)));

  /// Occurrence dates that are due on/before [today] and not yet posted.
  static List<DateTime> dueDates(AutoPay ap, DateTime today) {
    final start = _dateOnly(ap.startDate);
    final after = ap.lastRunDate == null ? null : _dateOnly(ap.lastRunDate!);
    final t = _dateOnly(today);
    bool ok(DateTime d) =>
        !d.isAfter(t) && !d.isBefore(start) && (after == null || d.isAfter(after));

    final out = <DateTime>[];
    switch (ap.repeat) {
      case RepeatType.none:
        if (ok(start)) out.add(start);
        break;
      case RepeatType.daily:
        for (var d = start; !d.isAfter(t); d = d.add(const Duration(days: 1))) {
          if (ok(d)) out.add(d);
        }
        break;
      case RepeatType.weekly:
        if (ap.weekdays.isEmpty) break;
        for (var d = start; !d.isAfter(t); d = d.add(const Duration(days: 1))) {
          if (ap.weekdays.contains(d.weekday) && ok(d)) out.add(d);
        }
        break;
      case RepeatType.monthly:
        // Every month on dayOfMonth, from the later of creation and the
        // chosen (start month, day) anchor.
        final anchor =
            _monthlyDate(start.year, ap.monthOfYear, ap.dayOfMonth);
        final effStart = anchor.isAfter(start) ? anchor : start;
        var y = effStart.year, m = effStart.month;
        while (true) {
          final d = _monthlyDate(y, m, ap.dayOfMonth);
          if (d.isAfter(t)) break;
          if (!d.isBefore(effStart) && (after == null || d.isAfter(after))) {
            out.add(d);
          }
          m++;
          if (m > 12) {
            m = 1;
            y++;
          }
        }
        break;
      case RepeatType.yearly:
        // Every year in monthOfYear (day 1), from yearValue.
        for (var y = ap.yearValue; y <= t.year; y++) {
          final d = DateTime(y, ap.monthOfYear, 1);
          if (ok(d)) out.add(d);
        }
        break;
    }
    return out;
  }

  /// The next future occurrence datetime (date + [ap.notifyMinutes]) after [now],
  /// or null if none / no reminder configured.
  static DateTime? nextOccurrence(AutoPay ap, DateTime now) {
    if (!ap.notifyEnabled || ap.notifyMinutes == null) return null;
    final minutes = ap.notifyMinutes!;
    DateTime at(DateTime day) =>
        DateTime(day.year, day.month, day.day, minutes ~/ 60, minutes % 60);

    final start = _dateOnly(ap.startDate);
    switch (ap.repeat) {
      case RepeatType.none:
        final dt = at(start);
        return dt.isAfter(now) ? dt : null;
      case RepeatType.daily:
        var day = _dateOnly(now);
        for (var i = 0; i < 2; i++) {
          if (!day.isBefore(start) && at(day).isAfter(now)) return at(day);
          day = day.add(const Duration(days: 1));
        }
        return at(day);
      case RepeatType.weekly:
        if (ap.weekdays.isEmpty) return null;
        for (var i = 0; i < 8; i++) {
          final day = _dateOnly(now).add(Duration(days: i));
          if (!day.isBefore(start) &&
              ap.weekdays.contains(day.weekday) &&
              at(day).isAfter(now)) {
            return at(day);
          }
        }
        return null;
      case RepeatType.monthly:
        final anchor =
            _monthlyDate(start.year, ap.monthOfYear, ap.dayOfMonth);
        final effStart = anchor.isAfter(start) ? anchor : start;
        var y = now.year, m = now.month;
        if (DateTime(y, m, 1).isBefore(DateTime(effStart.year, effStart.month, 1))) {
          y = effStart.year;
          m = effStart.month;
        }
        for (var i = 0; i < 14; i++) {
          final day = _monthlyDate(y, m, ap.dayOfMonth);
          if (!day.isBefore(effStart) && at(day).isAfter(now)) return at(day);
          m++;
          if (m > 12) {
            m = 1;
            y++;
          }
        }
        return null;
      case RepeatType.yearly:
        for (var y = ap.yearValue; y <= now.year + 2; y++) {
          final day = DateTime(y, ap.monthOfYear, 1);
          if (!day.isBefore(start) && at(day).isAfter(now)) return at(day);
        }
        return null;
    }
  }

  /// Posts all due auto-pay transactions onto the given boxes (adjusting account
  /// balances). Returns the auto-pays that fired. Idempotent via lastRunDate.
  static Future<List<AutoPay>> run({
    required Box<String> autoPays,
    required Box<String> transactions,
    required Box<String> accounts,
    required Box<String> paymentModes,
    required String Function() newId,
    DateTime? now,
  }) async {
    final today = now ?? DateTime.now();
    final fired = <AutoPay>[];

    for (final key in autoPays.keys.toList()) {
      final raw = autoPays.get(key);
      if (raw == null) continue;
      final ap = AutoPay.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      final dates = dueDates(ap, today);
      if (dates.isEmpty) continue;

      String? accountId;
      if (ap.flow == FlowType.expense) {
        final pmRaw = paymentModes.get(ap.paymentModeId);
        if (pmRaw != null) {
          accountId = PaymentMode.fromJson(
                  jsonDecode(pmRaw) as Map<String, dynamic>)
              .linkedAccountId;
        }
      } else {
        accountId = ap.accountId;
      }

      for (final date in dates) {
        final txn = AppTransaction(
          id: newId(),
          type: ap.flow == FlowType.expense ? TxnType.expense : TxnType.income,
          amount: ap.amount,
          date: date,
          categoryIds: ap.flow == FlowType.expense ? ap.categoryIds : const [],
          paymentModeId: ap.flow == FlowType.expense ? ap.paymentModeId : null,
          accountId: accountId,
          note: 'Auto: ${ap.name}',
          source: TxnSource.autopay,
          linkRefId: ap.id,
        );
        await transactions.put(txn.id, jsonEncode(txn.toJson()));
        await _adjust(accounts, accountId,
            ap.flow == FlowType.expense ? -ap.amount : ap.amount);
      }

      final updated = ap.copyWith(lastRunDate: dates.last);
      await autoPays.put(ap.id, jsonEncode(updated.toJson()));
      fired.add(updated);
    }
    return fired;
  }

  static Future<void> _adjust(
      Box<String> accounts, String? id, double delta) async {
    if (id == null) return;
    final raw = accounts.get(id);
    if (raw == null) return;
    final a = Account.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    await accounts.put(
        id, jsonEncode(a.copyWith(balance: a.balance + delta).toJson()));
  }
}
