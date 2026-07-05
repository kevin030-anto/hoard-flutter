import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/app_transaction.dart';
import '../data/models/enums.dart';
import 'app_providers.dart';

enum HomeViewMode { month, range }

/// The Home screen's current view: either a single month or a date range.
class HomeView {
  final HomeViewMode mode;
  final DateTime month; // first day of the month
  final DateTime rangeStart; // inclusive
  final DateTime rangeEnd; // inclusive

  const HomeView({
    required this.mode,
    required this.month,
    required this.rangeStart,
    required this.rangeEnd,
  });

  bool get isRange => mode == HomeViewMode.range;
}

final homeViewProvider =
    NotifierProvider<HomeViewNotifier, HomeView>(HomeViewNotifier.new);

class HomeViewNotifier extends Notifier<HomeView> {
  static DateTime get _currentMonth {
    final now = DateTime.now();
    return DateTime(now.year, now.month);
  }

  @override
  HomeView build() {
    final m = _currentMonth;
    return HomeView(mode: HomeViewMode.month, month: m, rangeStart: m, rangeEnd: m);
  }

  bool get canReset =>
      state.mode == HomeViewMode.range ||
      state.month.year != _currentMonth.year ||
      state.month.month != _currentMonth.month;

  bool get canGoForward =>
      state.mode == HomeViewMode.month && state.month.isBefore(_currentMonth);

  void setMonth(DateTime d) {
    var m = DateTime(d.year, d.month);
    if (m.isAfter(_currentMonth)) m = _currentMonth;
    state = HomeView(
        mode: HomeViewMode.month, month: m, rangeStart: m, rangeEnd: m);
  }

  void setRange(DateTime start, DateTime end) {
    state = HomeView(
      mode: HomeViewMode.range,
      month: state.month,
      rangeStart: DateTime(start.year, start.month, start.day),
      rangeEnd: DateTime(end.year, end.month, end.day),
    );
  }

  void next() {
    if (state.mode != HomeViewMode.month) return;
    final n = DateTime(state.month.year, state.month.month + 1);
    if (!n.isAfter(_currentMonth)) setMonth(n);
  }

  void prev() {
    if (state.mode != HomeViewMode.month) return;
    setMonth(DateTime(state.month.year, state.month.month - 1));
  }

  void reset() => state = build();
}

bool _sameMonth(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month;

bool _inView(DateTime date, HomeView v) {
  if (v.mode == HomeViewMode.month) return _sameMonth(date, v.month);
  final d = DateTime(date.year, date.month, date.day);
  return !d.isBefore(v.rangeStart) && !d.isAfter(v.rangeEnd);
}

/// Transactions for the current Home view (month or range).
final monthTransactionsProvider = Provider<List<AppTransaction>>((ref) {
  final all = ref.watch(appProvider).transactions;
  final view = ref.watch(homeViewProvider);
  return all.where((t) => _inView(t.date, view)).toList();
});

class MonthTotals {
  final double income;
  final double expense;
  const MonthTotals(this.income, this.expense);
  double get net => income - expense;
}

/// Income/expense totals for the current Home view (transfers excluded).
final monthTotalsProvider = Provider<MonthTotals>((ref) {
  final txns = ref.watch(monthTransactionsProvider);
  double income = 0, expense = 0;
  for (final t in txns) {
    if (t.type == TxnType.income) income += t.amount;
    if (t.type == TxnType.expense) expense += t.amount;
  }
  return MonthTotals(income, expense);
});
