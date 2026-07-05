import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/app_transaction.dart';
import '../../../data/models/enums.dart';
import '../../../providers/app_providers.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/icon_avatar.dart';
import '../../../shared/widgets/receipt_viewer.dart';
import '../../add_transaction/transaction_sheet.dart';

/// A single register row. Tap to expand and reveal Edit / Delete.
class TransactionTile extends ConsumerStatefulWidget {
  final AppTransaction txn;
  const TransactionTile({super.key, required this.txn});

  @override
  ConsumerState<TransactionTile> createState() => _TransactionTileState();
}

class _TransactionTileState extends ConsumerState<TransactionTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.txn;
    final data = ref.watch(appProvider);
    final symbol = data.settings.effectiveSymbol;
    final cats = data.categoriesByIds(t.categoryIds);

    final isTransfer = t.type == TxnType.transfer;
    final isIncome = t.type == TxnType.income;

    final title = isTransfer
        ? 'Transfer'
        : (cats.isNotEmpty
            ? cats.map((c) => c.name).join(', ')
            : (isIncome ? 'Income' : 'Expense'));

    final iconKey = isTransfer
        ? 'banktransfer'
        : (cats.isNotEmpty ? cats.first.iconKey : (isIncome ? 'salary' : 'category'));
    final iconColor = isTransfer
        ? AppColors.transfer.toARGB32()
        : (cats.isNotEmpty ? cats.first.colorValue : (isIncome ? AppColors.income.toARGB32() : AppColors.expense.toARGB32()));

    final amountColor = switch (t.type) {
      TxnType.income => AppColors.income,
      TxnType.expense => AppColors.expense,
      TxnType.transfer => AppColors.transfer,
    };
    // Expense shows '-', income shows '+', transfer has no sign.
    final amountText = switch (t.type) {
      TxnType.income => Formatters.money(t.amount, symbol: symbol, sign: true),
      TxnType.expense => '-${Formatters.money(t.amount, symbol: symbol)}',
      TxnType.transfer => Formatters.money(t.amount, symbol: symbol),
    };

    String? subLine2;
    if (isTransfer) {
      final from = data.accountById(t.fromAccountId)?.name ?? '?';
      final to = data.accountById(t.toAccountId)?.name ?? '?';
      subLine2 = '$from  →  $to';
    } else if (t.note.isNotEmpty) {
      subLine2 = t.note;
    }

    final mode = data.paymentModeById(t.paymentModeId);
    final account = data.accountById(t.accountId);
    final tags = data.tagsByIds(t.tagIds);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                children: [
                  IconAvatar(iconKey: iconKey, colorValue: iconColor),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.schedule,
                                size: 13,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.4)),
                            const SizedBox(width: 4),
                            Text(Formatters.dayMonthYear(t.date),
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.5))),
                            const SizedBox(width: 8),
                            if (mode != null)
                              _chip(
                                context,
                                data.paymentModeLabel(mode),
                                Color(data.paymentModeColor(
                                    mode, AppColors.primary.toARGB32())),
                              ),
                            if (mode == null && account != null && !isTransfer)
                              _chip(context, account.name,
                                  Color(account.colorValue)),
                            if (t.imagePaths.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () =>
                                    showReceiptViewer(context, t.imagePaths),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.accent
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(9),
                                    border: Border.all(
                                        color: AppColors.accent
                                            .withValues(alpha: 0.5)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.receipt_long_rounded,
                                          size: 16, color: AppColors.accent),
                                      const SizedBox(width: 3),
                                      Text('${t.imagePaths.length}',
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.accent,
                                              fontWeight: FontWeight.w800)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (subLine2 != null) ...[
                          const SizedBox(height: 4),
                          Text(subLine2,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontStyle: isTransfer
                                      ? FontStyle.normal
                                      : FontStyle.italic,
                                  fontSize: 12.5,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.6))),
                        ],
                        if (tags.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            children: [
                              for (final tag in tags)
                                Text('#${tag.name}',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.accent,
                                        fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(amountText,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: amountColor)),
                ],
              ),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 200),
                crossFadeState: _expanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                firstChild: const SizedBox(width: double.infinity),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => showTransactionSheet(context,
                              initialType: t.type, existing: t),
                          icon: const Icon(Icons.edit_rounded, size: 18),
                          label: const Text('Edit'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red.shade600),
                          onPressed: () async {
                            final ok = await showConfirmDialog(
                              context,
                              title: 'Delete transaction?',
                              message:
                                  'This will permanently remove it and adjust your balance.',
                            );
                            if (ok) {
                              await ref
                                  .read(appProvider.notifier)
                                  .deleteTransaction(t.id);
                            }
                          },
                          icon: const Icon(Icons.delete_rounded, size: 18),
                          label: const Text('Delete'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }
}
