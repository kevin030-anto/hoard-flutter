import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/icons/icon_registry.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/account.dart';
import '../../data/models/app_transaction.dart';
import '../../data/models/enums.dart';
import '../../providers/app_providers.dart';
import '../../providers/derived_providers.dart';
import '../../shared/widgets/expanding_fab.dart';
import '../../shared/widgets/wheel_pickers.dart';
import 'widgets/transaction_tile.dart';
import 'transaction_search_page.dart';
import '../add_transaction/transaction_sheet.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(appProvider);
    final view = ref.watch(homeViewProvider);
    final viewNotifier = ref.read(homeViewProvider.notifier);
    final totals = ref.watch(monthTotalsProvider);
    final txns = ref.watch(monthTransactionsProvider);
    final symbol = data.settings.effectiveSymbol;
    final homeAccounts = data.homeAccounts;
    final groups = _groupByDay(txns);

    final label = view.isRange
        ? '${Formatters.monthShortYear(view.rangeStart)} – ${Formatters.monthShortYear(view.rangeEnd)}'
        : Formatters.monthYear(view.month);

    return Scaffold(
      floatingActionButton: ExpandingFab(
        actions: [
          FabAction(
            icon: Icons.arrow_downward_rounded,
            label: 'Income',
            color: AppColors.income,
            onTap: () =>
                showTransactionSheet(context, initialType: TxnType.income),
          ),
          FabAction(
            icon: Icons.arrow_upward_rounded,
            label: 'Expense',
            color: AppColors.expense,
            onTap: () =>
                showTransactionSheet(context, initialType: TxnType.expense),
          ),
          FabAction(
            icon: Icons.swap_horiz_rounded,
            label: 'Transfer',
            color: AppColors.transfer,
            onTap: () =>
                showTransactionSheet(context, initialType: TxnType.transfer),
          ),
        ],
      ),
      body: Column(
        children: [
          _Header(
            label: label,
            isRange: view.isRange,
            canReset: viewNotifier.canReset,
            balance: data.shownBalance,
            income: totals.income,
            expense: totals.expense,
            symbol: symbol,
            onReset: viewNotifier.reset,
            onFilter: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const TransactionSearchPage()),
            ),
            onPickMonth: () async {
              final result = await showMonthYearPicker(
                context,
                initialMonth: view.isRange ? null : view.month,
                initialRange: view.isRange
                    ? DateTimeRange(start: view.rangeStart, end: view.rangeEnd)
                    : null,
              );
              if (result == null) return;
              if (result.isRange && result.range != null) {
                viewNotifier.setRange(result.range!.start, result.range!.end);
              } else if (result.month != null) {
                viewNotifier.setMonth(result.month!);
              }
            },
          ),
          Expanded(
            child: GestureDetector(
              onHorizontalDragEnd: (details) {
                final v = details.primaryVelocity ?? 0;
                if (v < -200) {
                  viewNotifier.next();
                } else if (v > 200) {
                  viewNotifier.prev();
                }
              },
              child: ListView(
                padding: const EdgeInsets.only(bottom: 120),
                children: [
                  if (homeAccounts.isNotEmpty)
                    SizedBox(
                      height: 130,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                        itemCount: homeAccounts.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 14),
                        itemBuilder: (_, i) => _AccountCard(
                            account: homeAccounts[i], symbol: symbol),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                    child: Text('Transactions (${txns.length})',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w800)),
                  ),
                  if (txns.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 60),
                      child: _EmptyState(),
                    )
                  else
                    for (final g in groups) ...[
                      _DayHeader(group: g, symbol: symbol),
                      for (final t in g.txns)
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 20),
                          child: TransactionTile(txn: t),
                        ),
                    ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<_DayGroup> _groupByDay(List<AppTransaction> txns) {
    final map = <DateTime, _DayGroup>{};
    for (final t in txns) {
      final key = DateTime(t.date.year, t.date.month, t.date.day);
      (map[key] ??= _DayGroup(key)).txns.add(t);
    }
    final groups = map.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return groups;
  }
}

class _DayGroup {
  final DateTime date;
  final List<AppTransaction> txns = [];
  _DayGroup(this.date);

  double get net => txns.fold(0.0, (sum, t) {
        if (t.type == TxnType.income) return sum + t.amount;
        if (t.type == TxnType.expense) return sum - t.amount;
        return sum;
      });
}

class _DayHeader extends StatelessWidget {
  final _DayGroup group;
  final String symbol;
  const _DayHeader({required this.group, required this.symbol});

  @override
  Widget build(BuildContext context) {
    final net = group.net;
    final color = net >= 0 ? AppColors.income : AppColors.expense;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
      child: Row(
        children: [
          Text(Formatters.dayLabel(group.date),
              style: const TextStyle(
                  fontSize: 26, fontWeight: FontWeight.w800)),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(Formatters.weekdayName(group.date),
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700)),
              Text(Formatters.monthYear(group.date),
                  style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5))),
            ],
          ),
          const Spacer(),
          Text(
            net == 0
                ? '—'
                : Formatters.money(net, symbol: symbol, sign: true),
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String label;
  final bool isRange;
  final bool canReset;
  final double balance;
  final double income;
  final double expense;
  final String symbol;
  final VoidCallback onReset;
  final VoidCallback onPickMonth;
  final VoidCallback onFilter;

  const _Header({
    required this.label,
    required this.isRange,
    required this.canReset,
    required this.balance,
    required this.income,
    required this.expense,
    required this.symbol,
    required this.onReset,
    required this.onPickMonth,
    required this.onFilter,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, MediaQuery.of(context).padding.top + 10, 12, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onPickMonth,
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: isRange ? 22 : 30,
                              fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.keyboard_arrow_down,
                          color: Colors.white70, size: 26),
                    ],
                  ),
                ),
              ),
              if (canReset)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: onReset,
                  icon: const Icon(Icons.restart_alt_rounded,
                      color: Colors.white),
                  tooltip: 'Reset to current month',
                ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: onFilter,
                icon: const Icon(Icons.tune_rounded, color: Colors.white),
                tooltip: 'Search & filter',
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.only(bottom: 2),
            child: Text('Tap to pick month/range • Swipe to change month',
                style: TextStyle(color: Colors.white70, fontSize: 12)),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              children: [
                _SummaryCard(
                    label: 'Balance',
                    value: Formatters.money(balance, symbol: symbol),
                    icon: Icons.account_balance_wallet_rounded,
                    valueColor: Colors.white),
                const SizedBox(width: 10),
                _SummaryCard(
                    label: 'Income',
                    value:
                        Formatters.money(income, symbol: symbol, sign: true),
                    icon: Icons.arrow_upward_rounded,
                    valueColor: const Color(0xFFB9F6CA)),
                const SizedBox(width: 10),
                _SummaryCard(
                    label: 'Expenses',
                    value: '-${Formatters.money(expense, symbol: symbol)}',
                    icon: Icons.arrow_downward_rounded,
                    valueColor: const Color(0xFFFFCDD2)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color valueColor;
  const _SummaryCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.white70, size: 15),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(label,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value,
                  style: TextStyle(
                      color: valueColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  final Account account;
  final String symbol;
  const _AccountCard({required this.account, required this.symbol});

  @override
  Widget build(BuildContext context) {
    final color = Color(account.colorValue);
    return Container(
      width: 200,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, Color.lerp(color, Colors.black, 0.25)!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
              color: color.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(AppIcons.of(account.iconKey),
                  color: Colors.white70, size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Text(account.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(Formatters.money(account.balance, symbol: symbol),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_rounded,
              size: 64,
              color:
                  Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2)),
          const SizedBox(height: 12),
          Text('No Logs',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5))),
          const SizedBox(height: 4),
          Text('Tap + to add income, expense or transfer',
              style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.4))),
        ],
      ),
    );
  }
}
