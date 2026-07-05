import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/icons/icon_registry.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/app_transaction.dart';
import '../../data/repositories/app_data.dart';
import '../../providers/app_providers.dart';
import '../../shared/widgets/sheet_scaffold.dart';
import 'widgets/transaction_tile.dart';

/// Keyword search + a filter popup (date/amount range, accounts, pay modes,
/// categories, tags) over all transactions.
class TransactionSearchPage extends ConsumerStatefulWidget {
  const TransactionSearchPage({super.key});

  @override
  ConsumerState<TransactionSearchPage> createState() =>
      _TransactionSearchPageState();
}

class _Filters {
  DateTimeRange? dateRange;
  RangeValues? amountRange;
  final Set<String> accountIds = {};
  final Set<String> modeIds = {};
  final Set<String> categoryIds = {};
  final Set<String> tagIds = {};

  int get activeCount =>
      (dateRange != null ? 1 : 0) +
      (amountRange != null ? 1 : 0) +
      accountIds.length +
      modeIds.length +
      categoryIds.length +
      tagIds.length;

  _Filters clone() {
    final f = _Filters()
      ..dateRange = dateRange
      ..amountRange = amountRange;
    f.accountIds.addAll(accountIds);
    f.modeIds.addAll(modeIds);
    f.categoryIds.addAll(categoryIds);
    f.tagIds.addAll(tagIds);
    return f;
  }
}

class _TransactionSearchPageState extends ConsumerState<TransactionSearchPage> {
  final _queryCtrl = TextEditingController();
  _Filters _filters = _Filters();

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appProvider);
    final query = _queryCtrl.text.trim().toLowerCase();

    final results = data.transactions.where((t) {
      final f = _filters;
      if (f.dateRange != null) {
        final d = DateTime(t.date.year, t.date.month, t.date.day);
        if (d.isBefore(f.dateRange!.start) || d.isAfter(f.dateRange!.end)) {
          return false;
        }
      }
      if (f.amountRange != null &&
          (t.amount < f.amountRange!.start || t.amount > f.amountRange!.end)) {
        return false;
      }
      if (f.accountIds.isNotEmpty &&
          !f.accountIds.contains(t.accountId) &&
          !f.accountIds.contains(t.fromAccountId) &&
          !f.accountIds.contains(t.toAccountId)) {
        return false;
      }
      if (f.modeIds.isNotEmpty &&
          (t.paymentModeId == null || !f.modeIds.contains(t.paymentModeId))) {
        return false;
      }
      if (f.categoryIds.isNotEmpty && !t.categoryIds.any(f.categoryIds.contains)) {
        return false;
      }
      if (f.tagIds.isNotEmpty && !t.tagIds.any(f.tagIds.contains)) return false;
      if (query.isNotEmpty && !_matchesQuery(t, query, data)) return false;
      return true;
    }).toList();

    final activeCount = _filters.activeCount;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _queryCtrl,
          autofocus: true,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            hintText: 'Search amount or keyword...',
            border: InputBorder.none,
            filled: false,
          ),
        ),
        actions: [
          if (_queryCtrl.text.isNotEmpty)
            IconButton(
              onPressed: () => setState(() => _queryCtrl.clear()),
              icon: const Icon(Icons.clear),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Badge(
              isLabelVisible: activeCount > 0,
              label: Text('$activeCount'),
              child: IconButton(
                onPressed: _openFilters,
                icon: const Icon(Icons.tune_rounded),
                tooltip: 'Filters',
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Row(
              children: [
                Text('${results.length} result(s)',
                    style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.5))),
                const Spacer(),
                if (activeCount > 0)
                  TextButton(
                    onPressed: () => setState(() => _filters = _Filters()),
                    child: const Text('Clear filters'),
                  ),
              ],
            ),
          ),
          Expanded(
            child: results.isEmpty
                ? Center(
                    child: Text('No matching transactions',
                        style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.4))),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                    itemCount: results.length,
                    itemBuilder: (_, i) => TransactionTile(txn: results[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _openFilters() async {
    final data = ref.read(appProvider);
    final result = await showModalBottomSheet<_Filters>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FilterSheet(initial: _filters.clone(), data: data),
    );
    if (result != null) setState(() => _filters = result);
  }

  bool _matchesQuery(AppTransaction t, String q, AppData data) {
    if (t.note.toLowerCase().contains(q)) return true;
    if (t.amount.toString().contains(q)) return true;
    if (Formatters.money(t.amount).toLowerCase().contains(q)) return true;
    for (final c in data.categoriesByIds(t.categoryIds)) {
      if (c.name.toLowerCase().contains(q)) return true;
    }
    for (final tag in data.tagsByIds(t.tagIds)) {
      if (tag.name.toLowerCase().contains(q)) return true;
    }
    final mode = data.paymentModeById(t.paymentModeId);
    if (mode != null && mode.name.toLowerCase().contains(q)) return true;
    return false;
  }
}

class _FilterSheet extends StatefulWidget {
  final _Filters initial;
  final AppData data;
  const _FilterSheet({required this.initial, required this.data});

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late _Filters _f = widget.initial;

  double get _maxAmount => widget.data.transactions
      .fold<double>(1000, (m, t) => t.amount > m ? t.amount : m);

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final symbol = data.settings.effectiveSymbol;
    return SheetScaffold(
      title: 'Filters',
      icon: Icons.tune_rounded,
      footer: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => setState(() => _f = _Filters()),
              child: const Text('Clear all'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, _f),
              child: const Text('Apply'),
            ),
          ),
        ],
      ),
      children: [
        SheetSection(
          label: 'Date range',
          child: _rowButton(
            _f.dateRange == null
                ? 'Any date'
                : '${Formatters.shortDate(_f.dateRange!.start)} – ${Formatters.shortDate(_f.dateRange!.end)}',
            () async {
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2015),
                lastDate: DateTime(2100),
                initialDateRange: _f.dateRange,
              );
              if (picked != null) setState(() => _f.dateRange = picked);
            },
            onClear: _f.dateRange == null
                ? null
                : () => setState(() => _f.dateRange = null),
          ),
        ),
        SheetSection(
          label: 'Amount range',
          child: Column(
            children: [
              RangeSlider(
                min: 0,
                max: _maxAmount,
                divisions: 100,
                values: _f.amountRange ?? RangeValues(0, _maxAmount),
                labels: RangeLabels(
                  '$symbol${(_f.amountRange?.start ?? 0).round()}',
                  '$symbol${(_f.amountRange?.end ?? _maxAmount).round()}',
                ),
                onChanged: (v) => setState(() => _f.amountRange = v),
              ),
              if (_f.amountRange != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => setState(() => _f.amountRange = null),
                    child: const Text('Clear amount'),
                  ),
                ),
            ],
          ),
        ),
        if (data.accounts.isNotEmpty)
          _facet('Accounts', [
            for (final a in data.accounts)
              _chip(a.name, AppIcons.of(a.iconKey), _f.accountIds.contains(a.id),
                  () => _toggle(_f.accountIds, a.id)),
          ]),
        if (data.paymentModes.isNotEmpty)
          _facet('Pay modes', [
            for (final m in data.paymentModes)
              _chip(data.paymentModeLabel(m), AppIcons.of(m.brandIconKey),
                  _f.modeIds.contains(m.id), () => _toggle(_f.modeIds, m.id)),
          ]),
        if (data.categories.isNotEmpty)
          _facet('Categories', [
            for (final c in data.categories)
              _chip(c.name, AppIcons.of(c.iconKey),
                  _f.categoryIds.contains(c.id), () => _toggle(_f.categoryIds, c.id)),
          ]),
        if (data.tags.isNotEmpty)
          _facet('Tags', [
            for (final t in data.tags)
              _chip('#${t.name}', null, _f.tagIds.contains(t.id),
                  () => _toggle(_f.tagIds, t.id)),
          ]),
      ],
    );
  }

  void _toggle(Set<String> set, String id) => setState(() {
        if (!set.remove(id)) set.add(id);
      });

  Widget _facet(String label, List<Widget> chips) => SheetSection(
        label: label,
        child: Wrap(spacing: 10, runSpacing: 10, children: chips),
      );

  Widget _chip(String label, IconData? icon, bool selected, VoidCallback onTap) {
    return FilterChip(
      label: Text(label),
      avatar: icon == null ? null : Icon(icon, size: 18),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }

  Widget _rowButton(String label, VoidCallback onTap, {VoidCallback? onClear}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_rounded, size: 20),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            if (onClear != null)
              GestureDetector(
                  onTap: onClear, child: const Icon(Icons.close, size: 18)),
          ],
        ),
      ),
    );
  }
}
