import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../providers/analysis_providers.dart';
import '../../providers/app_providers.dart';

class AnalysisScreen extends ConsumerWidget {
  const AnalysisScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(analysisStateProvider);
    final result = ref.watch(analysisResultProvider);
    final symbol = ref.watch(appProvider).settings.currencySymbol;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          children: [
            const Text('Analysis',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            _PeriodSelector(state: state),
            const SizedBox(height: 8),
            Text(result.rangeLabel,
                style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            Row(
              children: [
                _StatCard(
                    label: 'Income',
                    value: Formatters.money(result.income, symbol: symbol),
                    color: AppColors.income,
                    icon: Icons.arrow_upward_rounded),
                const SizedBox(width: 12),
                _StatCard(
                    label: 'Expenses',
                    value: Formatters.money(result.expense, symbol: symbol),
                    color: AppColors.expense,
                    icon: Icons.arrow_downward_rounded),
              ],
            ),
            const SizedBox(height: 12),
            _NetCard(result: result, symbol: symbol),
            const SizedBox(height: 20),
            _ChartCard(
              title: 'Income vs Expenses',
              child: result.buckets.isEmpty
                  ? const _NoData()
                  : _IncomeExpenseChart(buckets: result.buckets),
            ),
            const SizedBox(height: 16),
            _ChartCard(
              title: 'Expenses by Category',
              child: result.categoryStats.isEmpty
                  ? const _NoData()
                  : _CategoryBreakdown(
                      stats: result.categoryStats,
                      total: result.expense,
                      symbol: symbol),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeriodSelector extends ConsumerWidget {
  final AnalysisState state;
  const _PeriodSelector({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const labels = {
      AnalysisPeriod.daily: 'Daily',
      AnalysisPeriod.weekly: 'Weekly',
      AnalysisPeriod.monthly: 'Monthly',
      AnalysisPeriod.yearly: 'Yearly',
      AnalysisPeriod.custom: 'Custom',
    };
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final p in AnalysisPeriod.values)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: ChoiceChip(
                label: Text(labels[p]!),
                selected: state.period == p,
                onSelected: (_) async {
                  if (p == AnalysisPeriod.custom) {
                    final now = DateTime.now();
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2015),
                      lastDate: DateTime(2100),
                      initialDateRange: state.customRange ??
                          DateTimeRange(
                              start: DateTime(now.year, now.month, 1),
                              end: now),
                    );
                    if (picked != null) {
                      ref
                          .read(analysisStateProvider.notifier)
                          .setCustomRange(picked);
                    }
                  } else {
                    ref.read(analysisStateProvider.notifier).setPeriod(p);
                  }
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  const _StatCard(
      {required this.label,
      required this.value,
      required this.color,
      required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 8),
                Text(label,
                    style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6))),
              ],
            ),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value,
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: color)),
            ),
          ],
        ),
      ),
    );
  }
}

class _NetCard extends StatelessWidget {
  final AnalysisResult result;
  final String symbol;
  const _NetCard({required this.result, required this.symbol});

  @override
  Widget build(BuildContext context) {
    final positive = result.net >= 0;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: AppColors.savings.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.savings_rounded, color: AppColors.savings),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Net Savings',
                    style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6))),
                if (result.taggedSavings > 0)
                  Text(
                      'Tagged savings: ${Formatters.money(result.taggedSavings, symbol: symbol)}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.savings)),
              ],
            ),
          ),
          Text(
            Formatters.money(result.net, symbol: symbol, sign: true),
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: positive ? AppColors.income : AppColors.expense),
          ),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _ChartCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _IncomeExpenseChart extends StatelessWidget {
  final List<TimeBucket> buckets;
  const _IncomeExpenseChart({required this.buckets});

  @override
  Widget build(BuildContext context) {
    final maxY = buckets.fold<double>(
        1,
        (m, b) => [m, b.income, b.expense]
            .reduce((a, c) => a > c ? a : c));
    final show = buckets.length > 14
        ? buckets.sublist(buckets.length - 14)
        : buckets;

    return Column(
      children: [
        Row(
          children: const [
            _Legend(color: AppColors.expense, label: 'Expenses'),
            SizedBox(width: 16),
            _Legend(color: AppColors.income, label: 'Income'),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 200,
          child: BarChart(
            BarChartData(
              maxY: maxY * 1.2,
              alignment: BarChartAlignment.spaceAround,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (v) => FlLine(
                    color: Colors.grey.withValues(alpha: 0.15), strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      if (i < 0 || i >= show.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(show[i].label,
                            style: const TextStyle(fontSize: 10)),
                      );
                    },
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < show.length; i++)
                  BarChartGroupData(x: i, barRods: [
                    BarChartRodData(
                      toY: show[i].expense,
                      color: AppColors.expense,
                      width: 7,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    BarChartRodData(
                      toY: show[i].income,
                      color: AppColors.income,
                      width: 7,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ]),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CategoryBreakdown extends StatelessWidget {
  final List<CategoryStat> stats;
  final double total;
  final String symbol;
  const _CategoryBreakdown(
      {required this.stats, required this.total, required this.symbol});

  @override
  Widget build(BuildContext context) {
    final top = stats.take(8).toList();
    return Column(
      children: [
        SizedBox(
          height: 180,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 45,
              sections: [
                for (final s in top)
                  PieChartSectionData(
                    value: s.amount,
                    color: Color(s.color),
                    radius: 38,
                    showTitle: total > 0 && s.amount / total > 0.07,
                    title: '${(s.amount / total * 100).round()}%',
                    titleStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        for (final s in top)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                      color: Color(s.color), shape: BoxShape.circle),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(s.name)),
                Text(Formatters.money(s.amount, symbol: symbol),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
            width: 12,
            height: 12,
            decoration:
                BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _NoData extends StatelessWidget {
  const _NoData();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: Center(
        child: Text('No data for this period',
            style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.4))),
      ),
    );
  }
}
