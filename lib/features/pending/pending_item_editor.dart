import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/icons/icon_registry.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/enums.dart';
import '../../data/models/pending_item.dart';
import '../../providers/app_providers.dart';
import '../../shared/widgets/sheet_scaffold.dart';

Future<void> showPendingEditor(
  BuildContext context, {
  required PendingKind kind,
  PendingItem? existing,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PendingEditor(kind: kind, existing: existing),
  );
}

class _PendingEditor extends ConsumerStatefulWidget {
  final PendingKind kind;
  final PendingItem? existing;
  const _PendingEditor({required this.kind, this.existing});

  @override
  ConsumerState<_PendingEditor> createState() => _PendingEditorState();
}

class _PendingEditorState extends ConsumerState<_PendingEditor> {
  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final Set<String> _categoryIds = {};
  final Set<String> _tagIds = {};
  late DateTime _date;

  bool get _editing => widget.existing != null;
  PendingKind get _kind => widget.existing?.kind ?? widget.kind;
  bool get _isTodo => _kind == PendingKind.todo;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _date = e?.date ?? DateTime.now();
    if (e != null) {
      _titleCtrl.text = e.title;
      if (e.amount != null) {
        _amountCtrl.text = e.amount == e.amount!.roundToDouble()
            ? e.amount!.toStringAsFixed(0)
            : '${e.amount}';
      }
      _noteCtrl.text = e.note;
      _categoryIds.addAll(e.categoryIds);
      _tagIds.addAll(e.tagIds);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Color get _accent => switch (_kind) {
        PendingKind.toPay => AppColors.glowToPay,
        PendingKind.toReceive => AppColors.glowToReceive,
        PendingKind.todo => AppColors.glowTodo,
      };

  String get _titleLabel => switch (_kind) {
        PendingKind.toPay => 'To Pay (you owe)',
        PendingKind.toReceive => 'To Receive (owed to you)',
        PendingKind.todo => 'To-Do',
      };

  bool get _valid {
    if (_titleCtrl.text.trim().isEmpty) return false;
    if (!_isTodo) {
      final amt = double.tryParse(_amountCtrl.text.trim());
      return amt != null && amt > 0;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appProvider);
    return SheetScaffold(
      title: _editing ? 'Edit $_titleLabel' : 'Add $_titleLabel',
      icon: switch (_kind) {
        PendingKind.toPay => Icons.call_made_rounded,
        PendingKind.toReceive => Icons.call_received_rounded,
        PendingKind.todo => Icons.check_circle_outline_rounded,
      },
      iconColor: _accent,
      footer: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: _accent),
          onPressed: _valid ? _save : null,
          child: Text(_editing ? 'Save' : 'Add'),
        ),
      ),
      children: [
        SheetSection(
          label: _isTodo ? 'What to do?' : 'Person / reason',
          hint: '*required',
          child: TextField(
            controller: _titleCtrl,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
                hintText: _isTodo ? 'e.g. Pay electricity bill' : 'e.g. Chandan'),
          ),
        ),
        if (!_isTodo)
          SheetSection(
            label: 'Amount',
            hint: '*required',
            child: TextField(
              controller: _amountCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
              ],
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                  prefixText: '${data.settings.currencySymbol} ',
                  hintText: '0'),
            ),
          ),
        if (!_isTodo && data.categories.isNotEmpty)
          SheetSection(
            label: 'Category (optional)',
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final c in data.categories)
                  FilterChip(
                    label: Text(c.name),
                    avatar: Icon(AppIcons.of(c.iconKey), size: 18),
                    selected: _categoryIds.contains(c.id),
                    onSelected: (_) => setState(() {
                      if (!_categoryIds.remove(c.id)) _categoryIds.add(c.id);
                    }),
                  ),
              ],
            ),
          ),
        SheetSection(
          label: _isTodo ? 'Due date (optional)' : 'Date',
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
        if (!_isTodo && data.tags.isNotEmpty)
          SheetSection(
            label: 'Tags (optional)',
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final t in data.tags)
                  FilterChip(
                    label: Text('#${t.name}'),
                    selected: _tagIds.contains(t.id),
                    onSelected: (_) => setState(() {
                      if (!_tagIds.remove(t.id)) _tagIds.add(t.id);
                    }),
                  ),
              ],
            ),
          ),
        SheetSection(
          label: 'Note (optional)',
          child: TextField(
            controller: _noteCtrl,
            maxLines: 2,
            decoration: InputDecoration(
                hintText: _isTodo ? 'Details...' : 'Why / how to pay...'),
          ),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final notifier = ref.read(appProvider.notifier);
    final amt = double.tryParse(_amountCtrl.text.trim());
    final item = (widget.existing ??
            PendingItem(
              id: notifier.newId(),
              kind: _kind,
              title: '',
              date: _date,
            ))
        .copyWith(
      title: _titleCtrl.text.trim(),
      amount: _isTodo ? null : amt,
      categoryIds: _categoryIds.toList(),
      tagIds: _tagIds.toList(),
      date: _date,
      note: _noteCtrl.text.trim(),
    );
    await notifier.upsertPending(item);
    if (mounted) Navigator.pop(context);
  }
}
