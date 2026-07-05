import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/icons/icon_registry.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/enums.dart';
import '../../data/models/pending_item.dart';
import '../../providers/app_providers.dart';
import '../../shared/widgets/sheet_scaffold.dart';

/// Completion flow for a To Pay / To Receive item. Picks payment mode (toPay)
/// or destination account (toReceive) + date, then posts the linked txn.
Future<void> showCompletePendingSheet(BuildContext context, PendingItem item) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CompleteSheet(item: item),
  );
}

class _CompleteSheet extends ConsumerStatefulWidget {
  final PendingItem item;
  const _CompleteSheet({required this.item});

  @override
  ConsumerState<_CompleteSheet> createState() => _CompleteSheetState();
}

class _CompleteSheetState extends ConsumerState<_CompleteSheet> {
  String? _paymentModeId;
  String? _accountId;
  late DateTime _date;

  bool get _isPay => widget.item.kind == PendingKind.toPay;

  @override
  void initState() {
    super.initState();
    _date = DateTime.now();
  }

  bool get _valid => _isPay ? _paymentModeId != null : _accountId != null;

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appProvider);
    final symbol = data.settings.currencySymbol;
    return SheetScaffold(
      title: _isPay ? 'Mark as paid' : 'Mark as received',
      icon: Icons.check_circle_rounded,
      iconColor: AppColors.glowDone,
      footer: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.glowDone),
          onPressed: _valid ? _complete : null,
          child: Text(_isPay
              ? 'Pay ${Formatters.money(widget.item.amount ?? 0, symbol: symbol)}'
              : 'Receive ${Formatters.money(widget.item.amount ?? 0, symbol: symbol)}'),
        ),
      ),
      children: [
        Text(
          _isPay
              ? 'This will add an expense to your transactions.'
              : 'This will add an income to your transactions.',
          style: TextStyle(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.6)),
        ),
        if (_isPay)
          SheetSection(
            label: 'Payment mode',
            hint: '*required',
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final m in data.paymentModes)
                  ChoiceChip(
                    label: Text(data.paymentModeLabel(m)),
                    avatar: Icon(AppIcons.of(m.brandIconKey), size: 18),
                    selected: _paymentModeId == m.id,
                    onSelected: (_) => setState(() => _paymentModeId = m.id),
                  ),
              ],
            ),
          )
        else
          SheetSection(
            label: 'Deposit to',
            hint: '*required',
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final a in data.accounts)
                  ChoiceChip(
                    label: Text(a.name),
                    avatar: Icon(AppIcons.of(a.iconKey), size: 18),
                    selected: _accountId == a.id,
                    onSelected: (_) => setState(() => _accountId = a.id),
                  ),
              ],
            ),
          ),
        SheetSection(
          label: 'Date',
          child: InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(2015),
                lastDate: DateTime(2100),
              );
              if (picked != null) setState(() => _date = picked);
            },
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
                  Text(Formatters.dayMonthYear(_date),
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _complete() async {
    final data = ref.read(appProvider);
    final accountId = _isPay
        ? data.paymentModeById(_paymentModeId)?.linkedAccountId
        : _accountId;
    await ref.read(appProvider.notifier).completePending(
          widget.item,
          paymentModeId: _isPay ? _paymentModeId : null,
          accountId: accountId,
          date: _date,
        );
    if (mounted) Navigator.pop(context);
  }
}
