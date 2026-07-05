import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/models/enums.dart';
import 'app_providers.dart';

enum AnalysisPeriod { daily, weekly, monthly, yearly, custom }

class AnalysisState {
  final AnalysisPeriod period;
  final DateTimeRange? customRange;
  const AnalysisState({this.period = AnalysisPeriod.monthly, this.customRange});

  AnalysisState copyWith({AnalysisPeriod? period, DateTimeRange? customRange}) =>
      AnalysisState(
        period: period ?? this.period,
        customRange: customRange ?? this.customRange,
      );
}

final analysisStateProvider =
    NotifierProvider<AnalysisStateNotifier, AnalysisState>(
        AnalysisStateNotifier.new);

class AnalysisStateNotifier extends Notifier<AnalysisState> {
  @override
  AnalysisState build() => const AnalysisState();

  void setPeriod(AnalysisPeriod p) => state = state.copyWith(period: p);
  void setCustomRange(DateTimeRange r) =>
      state = AnalysisState(period: AnalysisPeriod.custom, customRange: r);
}

class CategoryStat {
  final String name;
  final int color;
  final double amount;
  const CategoryStat(this.name, this.color, this.amount);
}

class TimeBucket {
  final String label;
  final double income;
  final double expense;
  const TimeBucket(this.label, this.income, this.expense);
}

class AnalysisResult {
  final double income;
  final double expense;
  final double taggedSavings;
  final String rangeLabel;
  final List<CategoryStat> categoryStats;
  final List<TimeBucket> buckets;
  const AnalysisResult({
    required this.income,
    required this.expense,
    required this.taggedSavings,
    required this.rangeLabel,
    required this.categoryStats,
    required this.buckets,
  });

  double get net => income - expense;
}

DateTimeRange _rangeFor(AnalysisState s) {
  final now = DateTime.now();
  switch (s.period) {
    case AnalysisPeriod.daily:
      final start = DateTime(now.year, now.month, now.day);
      return DateTimeRange(start: start, end: start);
    case AnalysisPeriod.weekly:
      final start = now.subtract(Duration(days: now.weekday - 1));
      return DateTimeRange(
          start: DateTime(start.year, start.month, start.day),
          end: DateTime(now.year, now.month, now.day));
    case AnalysisPeriod.monthly:
      return DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month + 1, 0));
    case AnalysisPeriod.yearly:
      return DateTimeRange(
          start: DateTime(now.year, 1, 1), end: DateTime(now.year, 12, 31));
    case AnalysisPeriod.custom:
      return s.customRange ??
          DateTimeRange(
              start: DateTime(now.year, now.month, 1),
              end: DateTime(now.year, now.month + 1, 0));
  }
}

bool _inRange(DateTime d, DateTimeRange r) {
  final day = DateTime(d.year, d.month, d.day);
  final start = DateTime(r.start.year, r.start.month, r.start.day);
  final end = DateTime(r.end.year, r.end.month, r.end.day);
  return !day.isBefore(start) && !day.isAfter(end);
}

final analysisResultProvider = Provider<AnalysisResult>((ref) {
  final data = ref.watch(appProvider);
  final s = ref.watch(analysisStateProvider);
  final range = _rangeFor(s);
  final txns =
      data.transactions.where((t) => _inRange(t.date, range)).toList();

  double income = 0, expense = 0, savings = 0;
  final byCategory = <String, double>{};
  final catMeta = <String, ({int color, String name})>{};
  double uncategorizedExpense = 0;

  for (final t in txns) {
    final isSavings = t.tagIds.any(data.tagIdIsSavings) ||
        data
            .categoriesByIds(t.categoryIds)
            .any((c) => c.name.toLowerCase() == 'savings');
    if (t.type == TxnType.income) income += t.amount;
    if (t.type == TxnType.expense) {
      expense += t.amount;
      if (isSavings) savings += t.amount;
      final cats = data.categoriesByIds(t.categoryIds);
      if (cats.isEmpty) {
        uncategorizedExpense += t.amount;
      } else {
        // Split evenly across selected categories so totals stay consistent.
        final share = t.amount / cats.length;
        for (final c in cats) {
          byCategory.update(c.id, (v) => v + share, ifAbsent: () => share);
          catMeta[c.id] = (color: c.colorValue, name: c.name);
        }
      }
    }
  }

  final stats = <CategoryStat>[
    for (final e in byCategory.entries)
      CategoryStat(catMeta[e.key]!.name, catMeta[e.key]!.color, e.value),
  ]..sort((a, b) => b.amount.compareTo(a.amount));
  if (uncategorizedExpense > 0) {
    stats.add(CategoryStat('Other', 0xFF94A3B8, uncategorizedExpense));
  }

  return AnalysisResult(
    income: income,
    expense: expense,
    taggedSavings: savings,
    rangeLabel: _rangeLabel(s, range),
    categoryStats: stats,
    buckets: _buckets(s, range, txns, data),
  );
});

String _rangeLabel(AnalysisState s, DateTimeRange r) {
  final f = DateFormat('dd MMM');
  switch (s.period) {
    case AnalysisPeriod.daily:
      return DateFormat('dd MMM yyyy').format(r.start);
    case AnalysisPeriod.weekly:
      return '${f.format(r.start)} – ${f.format(r.end)}';
    case AnalysisPeriod.monthly:
      return DateFormat('MMMM yyyy').format(r.start);
    case AnalysisPeriod.yearly:
      return DateFormat('yyyy').format(r.start);
    case AnalysisPeriod.custom:
      return '${f.format(r.start)} – ${f.format(r.end)}';
  }
}

List<TimeBucket> _buckets(
    AnalysisState s, DateTimeRange r, List txns, data) {
  // Choose bucketing granularity by period.
  final spanDays = r.end.difference(r.start).inDays;
  final byMonth = s.period == AnalysisPeriod.yearly || spanDays > 62;

  final map = <String, ({double income, double expense, DateTime key})>{};
  String keyOf(DateTime d) =>
      byMonth ? DateFormat('yyyy-MM').format(d) : DateFormat('yyyy-MM-dd').format(d);

  for (final t in txns) {
    final k = keyOf(t.date);
    final cur = map[k] ?? (income: 0.0, expense: 0.0, key: t.date);
    map[k] = (
      income: cur.income + (t.type == TxnType.income ? t.amount : 0),
      expense: cur.expense + (t.type == TxnType.expense ? t.amount : 0),
      key: t.date,
    );
  }

  final entries = map.entries.toList()
    ..sort((a, b) => a.value.key.compareTo(b.value.key));
  final labelFmt = byMonth ? DateFormat('MMM') : DateFormat('d');
  return [
    for (final e in entries)
      TimeBucket(labelFmt.format(e.value.key), e.value.income, e.value.expense),
  ];
}
