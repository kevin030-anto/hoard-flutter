import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/icons/icon_registry.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/enums.dart';
import '../../data/models/pending_item.dart';
import '../../providers/app_providers.dart';
import '../../shared/widgets/confirm_dialog.dart';
import '../../shared/widgets/expanding_fab.dart';
import '../../shared/widgets/glow_card.dart';
import 'complete_pending_sheet.dart';
import 'pending_item_editor.dart';

class PendingScreen extends ConsumerWidget {
  const PendingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(appProvider.select((d) => d.pending));
    final pending = items.where((i) => !i.isDone).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final completed = items.where((i) => i.isDone).toList()
      ..sort((a, b) =>
          (b.doneDate ?? b.date).compareTo(a.doneDate ?? a.date));

    return Scaffold(
      floatingActionButton: ExpandingFab(
        actions: [
          FabAction(
            icon: Icons.check_circle_outline_rounded,
            label: 'To-Do',
            color: AppColors.glowTodo,
            onTap: () => showPendingEditor(context, kind: PendingKind.todo),
          ),
          FabAction(
            icon: Icons.call_received_rounded,
            label: 'To Receive',
            color: AppColors.glowToReceive,
            onTap: () =>
                showPendingEditor(context, kind: PendingKind.toReceive),
          ),
          FabAction(
            icon: Icons.call_made_rounded,
            label: 'To Pay',
            color: AppColors.glowToPay,
            onTap: () => showPendingEditor(context, kind: PendingKind.toPay),
          ),
        ],
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Pending Payments',
                        style: TextStyle(
                            fontSize: 26, fontWeight: FontWeight.w800)),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('${pending.length} pending',
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
            ),
            if (pending.isEmpty && completed.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyPending(),
              ),
            if (pending.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                sliver: SliverList.builder(
                  itemCount: pending.length,
                  itemBuilder: (_, i) => _PendingCard(item: pending[i]),
                ),
              ),
            if (completed.isNotEmpty) ...[
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Text('Completed',
                      style: TextStyle(
                          fontSize: 14,
                          letterSpacing: 1,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey)),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                sliver: SliverList.builder(
                  itemCount: completed.length,
                  itemBuilder: (_, i) => _PendingCard(item: completed[i]),
                ),
              ),
            ] else
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
    );
  }
}

class _PendingCard extends ConsumerStatefulWidget {
  final PendingItem item;
  const _PendingCard({required this.item});

  @override
  ConsumerState<_PendingCard> createState() => _PendingCardState();
}

class _PendingCardState extends ConsumerState<_PendingCard> {
  bool _expanded = false;

  Color _kindColor(PendingKind k) => switch (k) {
        PendingKind.toPay => AppColors.glowToPay,
        PendingKind.toReceive => AppColors.glowToReceive,
        PendingKind.todo => AppColors.glowTodo,
      };

  String _kindLabel(PendingKind k) => switch (k) {
        PendingKind.toPay => 'To Pay',
        PendingKind.toReceive => 'To Receive',
        PendingKind.todo => 'To-Do',
      };

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final data = ref.watch(appProvider);
    final symbol = data.settings.currencySymbol;
    final glow = item.isDone ? AppColors.glowDone : _kindColor(item.kind);
    final cats = data.categoriesByIds(item.categoryIds);

    return GlowCard(
      glow: glow,
      onTap: () => setState(() => _expanded = !_expanded),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: glow.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  item.isDone
                      ? Icons.check_circle_rounded
                      : switch (item.kind) {
                          PendingKind.toPay => Icons.call_made_rounded,
                          PendingKind.toReceive => Icons.call_received_rounded,
                          PendingKind.todo => Icons.check_circle_outline_rounded,
                        },
                  color: glow,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(_kindLabel(item.kind),
                            style: TextStyle(
                                color: glow,
                                fontWeight: FontWeight.w700,
                                fontSize: 12.5)),
                        if (cats.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Icon(AppIcons.of(cats.first.iconKey),
                              size: 13,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.45)),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(cats.map((c) => c.name).join(', '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.5))),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(Formatters.dayMonthYear(item.date),
                        style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.5))),
                  ],
                ),
              ),
              if (item.amount != null)
                Text(Formatters.money(item.amount!, symbol: symbol),
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: item.isDone
                            ? AppColors.glowDone
                            : _kindColor(item.kind))),
            ],
          ),
          if (item.note.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(item.note,
                style: TextStyle(
                    fontSize: 12.5,
                    fontStyle: FontStyle.italic,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6))),
          ],
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _actions(item),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actions(PendingItem item) {
    final notifier = ref.read(appProvider.notifier);
    if (item.isDone) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => notifier.undoPending(item),
              icon: const Icon(Icons.undo_rounded, size: 18),
              label: const Text('Undo'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              style:
                  OutlinedButton.styleFrom(foregroundColor: Colors.red.shade600),
              onPressed: () => _delete(item),
              icon: const Icon(Icons.delete_rounded, size: 18),
              label: const Text('Delete'),
            ),
          ),
        ],
      );
    }
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () =>
                showPendingEditor(context, kind: item.kind, existing: item),
            icon: const Icon(Icons.edit_rounded, size: 18),
            label: const Text('Edit'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            style:
                OutlinedButton.styleFrom(foregroundColor: Colors.red.shade600),
            onPressed: () => _delete(item),
            icon: const Icon(Icons.delete_rounded, size: 18),
            label: const Text('Delete'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.glowDone),
            onPressed: () {
              if (item.kind == PendingKind.todo) {
                notifier.completePending(item);
              } else {
                showCompletePendingSheet(context, item);
              }
            },
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text('Done'),
          ),
        ),
      ],
    );
  }

  Future<void> _delete(PendingItem item) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Delete item?',
      message: 'Delete "${item.title}"? This cannot be undone.',
    );
    if (ok) await ref.read(appProvider.notifier).deletePending(item.id);
  }
}

class _EmptyPending extends StatelessWidget {
  const _EmptyPending();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_turned_in_outlined,
              size: 64,
              color:
                  Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2)),
          const SizedBox(height: 12),
          Text('Nothing pending',
              style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5))),
          const SizedBox(height: 4),
          Text('Tap + to track money to pay, receive, or a to-do',
              textAlign: TextAlign.center,
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
