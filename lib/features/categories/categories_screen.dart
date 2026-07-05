import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/app_tag.dart';
import '../../data/models/category.dart';
import '../../data/models/enums.dart';
import '../../providers/app_providers.dart';
import '../../shared/widgets/confirm_dialog.dart';
import '../../shared/widgets/icon_avatar.dart';
import 'editors/account_editor.dart';
import 'editors/autopay_editor.dart';
import 'editors/category_editor.dart';
import 'editors/payment_mode_editor.dart';
import 'editors/tag_editor.dart';

enum _SortMode { az, za, newOld, oldNew }

const _sortCycle = [
  _SortMode.az,
  _SortMode.za,
  _SortMode.newOld,
  _SortMode.oldNew,
];

String _sortLabel(_SortMode m) => switch (m) {
      _SortMode.az => 'Sorted A–Z',
      _SortMode.za => 'Sorted Z–A',
      _SortMode.newOld => 'Sorted New–Old',
      _SortMode.oldNew => 'Sorted Old–New',
    };

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 5, vsync: this)
    ..addListener(_onTabChange);
  int _cycleIndex = 0;

  void _onTabChange() {
    if (!_tab.indexIsChanging) setState(() {});
  }

  bool get _sortableTab => _tab.index == 2 || _tab.index == 4; // Categories, Tags

  @override
  void dispose() {
    _tab.removeListener(_onTabChange);
    _tab.dispose();
    super.dispose();
  }

  void _applySort() {
    final mode = _sortCycle[_cycleIndex % _sortCycle.length];
    _cycleIndex++;
    final data = ref.read(appProvider);
    final notifier = ref.read(appProvider.notifier);

    if (_tab.index == 2) {
      final ids = _sortedIds(
          data.categories, mode, (c) => c.name, (c) => c.createdAt);
      notifier.reorderCategories(ids);
    } else if (_tab.index == 4) {
      final ids =
          _sortedIds(data.tags, mode, (t) => t.name, (t) => t.createdAt);
      notifier.reorderTags(ids);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_sortLabel(mode)), duration: const Duration(seconds: 1)),
    );
  }

  List<String> _sortedIds<T>(
    List<T> items,
    _SortMode mode,
    String Function(T) name,
    DateTime Function(T) created,
  ) {
    final list = [...items];
    switch (mode) {
      case _SortMode.az:
        list.sort((a, b) =>
            name(a).toLowerCase().compareTo(name(b).toLowerCase()));
        break;
      case _SortMode.za:
        list.sort((a, b) =>
            name(b).toLowerCase().compareTo(name(a).toLowerCase()));
        break;
      case _SortMode.newOld:
        list.sort((a, b) => created(b).compareTo(created(a)));
        break;
      case _SortMode.oldNew:
        list.sort((a, b) => created(a).compareTo(created(b)));
        break;
    }
    return list.map((e) => (e as dynamic).id as String).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 2),
              child: Row(
                children: [
                  const Text('Categories',
                      style: TextStyle(
                          fontSize: 28, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  if (_sortableTab)
                    IconButton(
                      onPressed: _applySort,
                      icon: const Icon(Icons.sort_rounded),
                      tooltip: 'Sort (tap to cycle)',
                    ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                    'Long-press to reorder • Swipe to delete/edit',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tab,
                physics: const NeverScrollableScrollPhysics(),
                children: const [
                  _AccountsTab(),
                  _PayModesTab(),
                  _CategoriesTab(),
                  _AutoPayTab(),
                  _TagsTab(),
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 12,
                      offset: const Offset(0, -2)),
                ],
              ),
              child: TabBar(
                controller: _tab,
                isScrollable: true,
                tabAlignment: TabAlignment.center,
                indicatorColor: AppColors.primary,
                labelColor: AppColors.primary,
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: 'Accounts'),
                  Tab(text: 'Pay Modes'),
                  Tab(text: 'Categories'),
                  Tab(text: 'Auto-Pay'),
                  Tab(text: 'Tags'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A full-swipe row: swipe right → Delete (with confirm), left → Edit. Sides
/// flip when [swap] is true. Optional [trailing] (e.g. account toggle).
class SwipeRow extends StatelessWidget {
  final String id;
  final bool swap;
  final String iconKey;
  final int color;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool reorderable;
  final String deleteKind;
  final String deleteName;
  final VoidCallback onEdit;
  final Future<void> Function() onDelete;

  const SwipeRow({
    super.key,
    required this.id,
    required this.swap,
    required this.iconKey,
    required this.color,
    required this.title,
    this.subtitle,
    this.trailing,
    this.reorderable = false,
    required this.deleteKind,
    required this.deleteName,
    required this.onEdit,
    required this.onDelete,
  });

  Widget _pane(bool delete, Alignment align) {
    return Container(
      alignment: align,
      padding: const EdgeInsets.symmetric(horizontal: 26),
      decoration: BoxDecoration(
        color: delete ? Colors.red.shade500 : AppColors.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(delete ? Icons.delete_rounded : Icons.edit_rounded,
              color: Colors.white),
          const SizedBox(width: 8),
          Text(delete ? 'Delete' : 'Edit',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Default: right(startToEnd)=Delete, left(endToStart)=Edit. Swap flips it.
    final rightIsDelete = !swap;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Dismissible(
        key: ValueKey('dis-$id'),
        dismissThresholds: const {
          DismissDirection.startToEnd: 0.4,
          DismissDirection.endToStart: 0.4,
        },
        background: _pane(rightIsDelete, Alignment.centerLeft),
        secondaryBackground: _pane(!rightIsDelete, Alignment.centerRight),
        confirmDismiss: (dir) async {
          final isRight = dir == DismissDirection.startToEnd;
          final isDelete = swap ? !isRight : isRight;
          if (isDelete) {
            return showConfirmDialog(
              context,
              title: 'Delete $deleteKind?',
              message: 'Delete "$deleteName"? This cannot be undone.',
            );
          }
          onEdit();
          return false;
        },
        onDismissed: (_) => onDelete(),
        child: Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                IconAvatar(iconKey: iconKey, colorValue: color),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(subtitle!,
                            style: TextStyle(
                                fontSize: 12.5,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.55))),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
                if (trailing == null && reorderable)
                  Icon(Icons.drag_indicator_rounded,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.25)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

List<String> _reorderedIds(List<String> ids, int oldIndex, int newIndex) {
  final list = [...ids];
  if (newIndex > oldIndex) newIndex -= 1;
  final moved = list.removeAt(oldIndex);
  list.insert(newIndex, moved);
  return list;
}

Widget _addButton(String label, VoidCallback onTap) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
    child: SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.add),
        label: Text(label),
      ),
    ),
  );
}

Widget _sectionLabel(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
      child: Text(text.toUpperCase(),
          style: const TextStyle(
              fontSize: 12,
              letterSpacing: 1,
              fontWeight: FontWeight.w700,
              color: Colors.grey)),
    );

Widget _emptyHint(String text) => Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(text, textAlign: TextAlign.center),
      ),
    );

// --------------------------------------------------------------- Accounts
class _AccountsTab extends ConsumerWidget {
  const _AccountsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(appProvider);
    final notifier = ref.read(appProvider.notifier);
    final swap = data.settings.swapSwipeActions;
    final symbol = data.settings.effectiveSymbol;
    final accounts = data.accounts;
    return Column(
      children: [
        Expanded(
          child: accounts.isEmpty
              ? _emptyHint('No accounts yet.\nAdd your cash and bank balances.')
              : ReorderableListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  itemCount: accounts.length,
                  onReorder: (o, n) => notifier.reorderAccounts(
                      _reorderedIds(accounts.map((a) => a.id).toList(), o, n)),
                  itemBuilder: (_, i) {
                    final a = accounts[i];
                    return SwipeRow(
                      key: ValueKey(a.id),
                      id: a.id,
                      swap: swap,
                      iconKey: a.iconKey,
                      color: a.colorValue,
                      title: a.name,
                      reorderable: true,
                      subtitle:
                          '${a.type == AccountType.cash ? 'Cash' : 'Bank'} • ${Formatters.money(a.balance, symbol: symbol)}',
                      trailing: Switch(
                        value: a.showOnHome,
                        onChanged: (v) =>
                            notifier.upsertAccount(a.copyWith(showOnHome: v)),
                      ),
                      deleteKind: 'account',
                      deleteName: a.name,
                      onEdit: () => showAccountEditor(context, existing: a),
                      onDelete: () => notifier.deleteAccount(a.id),
                    );
                  },
                ),
        ),
        _addButton('Add Balance', () => showAccountEditor(context)),
      ],
    );
  }
}

// --------------------------------------------------------------- Pay Modes
class _PayModesTab extends ConsumerWidget {
  const _PayModesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(appProvider);
    final notifier = ref.read(appProvider.notifier);
    final swap = data.settings.swapSwipeActions;
    final modes = data.paymentModes;
    return Column(
      children: [
        Expanded(
          child: modes.isEmpty
              ? _emptyHint('No payment modes yet.\nAdd Cash, GPay, BHIM, etc.')
              : ReorderableListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  itemCount: modes.length,
                  onReorder: (o, n) => notifier.reorderPaymentModes(
                      _reorderedIds(modes.map((m) => m.id).toList(), o, n)),
                  itemBuilder: (_, i) {
                    final m = modes[i];
                    return SwipeRow(
                      key: ValueKey(m.id),
                      id: m.id,
                      swap: swap,
                      iconKey: m.brandIconKey,
                      color:
                          data.paymentModeColor(m, AppColors.primary.toARGB32()),
                      title: data.paymentModeLabel(m),
                      reorderable: true,
                      subtitle:
                          '${m.type == PaymentModeType.cash ? 'Cash' : 'Digital'} → ${data.accountById(m.linkedAccountId)?.name ?? 'unlinked'}',
                      deleteKind: 'payment mode',
                      deleteName: m.name,
                      onEdit: () => showPaymentModeEditor(context, existing: m),
                      onDelete: () => notifier.deletePaymentMode(m.id),
                    );
                  },
                ),
        ),
        _addButton('Add Payment Mode', () => showPaymentModeEditor(context)),
      ],
    );
  }
}

// --------------------------------------------------------------- Categories
class _CategoriesTab extends ConsumerWidget {
  const _CategoriesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(appProvider);
    final notifier = ref.read(appProvider.notifier);
    final swap = data.settings.swapSwipeActions;
    final expense = data.categories
        .where((c) =>
            c.kind == CategoryKind.expense || c.kind == CategoryKind.both)
        .toList();
    final income = data.categories
        .where((c) =>
            c.kind == CategoryKind.income || c.kind == CategoryKind.both)
        .toList();

    return Column(
      children: [
        Expanded(
          child: data.categories.isEmpty
              ? _emptyHint('No categories yet.')
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  children: [
                    if (expense.isNotEmpty) ...[
                      _sectionLabel('Expense categories (${expense.length})'),
                      _section(context, expense, swap, notifier),
                    ],
                    if (income.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _sectionLabel('Income categories (${income.length})'),
                      _section(context, income, swap, notifier),
                    ],
                  ],
                ),
        ),
        _addButton('Add Category', () => showCategoryEditor(context)),
      ],
    );
  }

  Widget _section(BuildContext context, List<Category> items, bool swap,
      AppNotifier notifier) {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      onReorder: (o, n) => notifier.reorderCategories(
          _reorderedIds(items.map((c) => c.id).toList(), o, n)),
      itemBuilder: (_, i) {
        final c = items[i];
        return SwipeRow(
          key: ValueKey('${c.id}-${c.kind.name}'),
          id: '${c.id}-${c.kind.name}',
          swap: swap,
          iconKey: c.iconKey,
          color: c.colorValue,
          title: c.name,
          reorderable: true,
          subtitle: switch (c.kind) {
            CategoryKind.expense => 'Expense',
            CategoryKind.income => 'Income',
            CategoryKind.both => 'Income & Expense',
          },
          deleteKind: 'category',
          deleteName: c.name,
          onEdit: () => showCategoryEditor(context, existing: c),
          onDelete: () => notifier.deleteCategory(c.id),
        );
      },
    );
  }
}

// --------------------------------------------------------------- Auto-Pay
class _AutoPayTab extends ConsumerWidget {
  const _AutoPayTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(appProvider);
    final notifier = ref.read(appProvider.notifier);
    final swap = data.settings.swapSwipeActions;
    final symbol = data.settings.effectiveSymbol;
    return Column(
      children: [
        Expanded(
          child: data.autoPays.isEmpty
              ? _emptyHint(
                  'No auto-payments yet.\nAdd recurring rent, SIP, salary, etc.')
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  children: [
                    for (final a in data.autoPays)
                      SwipeRow(
                        id: a.id,
                        swap: swap,
                        iconKey: a.iconKey,
                        color: a.colorValue,
                        title: a.name,
                        subtitle:
                            '${a.flow == FlowType.income ? 'Income' : 'Expense'} • ${Formatters.money(a.amount, symbol: symbol)} • ${_repeatLabel(a.repeat)}',
                        deleteKind: 'auto-pay',
                        deleteName: a.name,
                        onEdit: () => showAutoPayEditor(context, existing: a),
                        onDelete: () => notifier.deleteAutoPay(a.id),
                      ),
                  ],
                ),
        ),
        _addButton('Add Auto-Pay', () => showAutoPayEditor(context)),
      ],
    );
  }

  String _repeatLabel(RepeatType r) => switch (r) {
        RepeatType.none => 'One-time',
        RepeatType.daily => 'Daily',
        RepeatType.weekly => 'Weekly',
        RepeatType.monthly => 'Monthly',
        RepeatType.yearly => 'Yearly',
      };
}

// --------------------------------------------------------------- Tags
class _TagsTab extends ConsumerWidget {
  const _TagsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(appProvider);
    final notifier = ref.read(appProvider.notifier);
    final swap = data.settings.swapSwipeActions;
    final tags = data.tags;
    return Column(
      children: [
        Expanded(
          child: tags.isEmpty
              ? _emptyHint('No tags yet.\nAdd #travel, #work, #savings...')
              : ReorderableListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  itemCount: tags.length,
                  onReorder: (o, n) => notifier.reorderTags(
                      _reorderedIds(tags.map((t) => t.id).toList(), o, n)),
                  itemBuilder: (_, i) {
                    final AppTag t = tags[i];
                    return SwipeRow(
                      key: ValueKey(t.id),
                      id: t.id,
                      swap: swap,
                      iconKey: 'star',
                      color: AppColors.accent.toARGB32(),
                      title: '#${t.name}',
                      reorderable: true,
                      subtitle: t.isSavings ? 'Counts as savings' : null,
                      deleteKind: 'tag',
                      deleteName: t.name,
                      onEdit: () => showTagEditor(context, existing: t),
                      onDelete: () => notifier.deleteTag(t.id),
                    );
                  },
                ),
        ),
        _addButton('Add Tag', () => showTagEditor(context)),
      ],
    );
  }
}
