import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/icons/icon_registry.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/images/image_store.dart';
import '../../data/models/account.dart';
import '../../data/models/app_transaction.dart';
import '../../data/models/enums.dart';
import '../../data/repositories/app_data.dart';
import '../../providers/app_providers.dart';
import '../../shared/widgets/sheet_scaffold.dart';

/// Opens the add/edit transaction sheet. Pass [existing] to edit.
Future<void> showTransactionSheet(
  BuildContext context, {
  required TxnType initialType,
  AppTransaction? existing,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) =>
        _TransactionSheet(initialType: initialType, existing: existing),
  );
}

class _TransactionSheet extends ConsumerStatefulWidget {
  final TxnType initialType;
  final AppTransaction? existing;
  const _TransactionSheet({required this.initialType, this.existing});

  @override
  ConsumerState<_TransactionSheet> createState() => _TransactionSheetState();
}

class _TransactionSheetState extends ConsumerState<_TransactionSheet> {
  late TxnType _type;
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final Set<String> _categoryIds = {};
  final Set<String> _tagIds = {};
  String? _paymentModeId;
  String? _accountId; // income destination
  String? _fromAccountId;
  String? _toAccountId;
  late DateTime _date;
  final List<String> _imagePaths = [];
  late final List<String> _originalImagePaths;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _type = e?.type ?? widget.initialType;
    _date = e?.date ?? DateTime.now();
    if (e != null) {
      _amountCtrl.text =
          e.amount == e.amount.roundToDouble() ? e.amount.toStringAsFixed(0) : '${e.amount}';
      _noteCtrl.text = e.note;
      _categoryIds.addAll(e.categoryIds);
      _tagIds.addAll(e.tagIds);
      _paymentModeId = e.paymentModeId;
      _accountId = e.accountId;
      _fromAccountId = e.fromAccountId;
      _toAccountId = e.toAccountId;
      _imagePaths.addAll(e.imagePaths);
    }
    _originalImagePaths = List.of(_imagePaths);
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Color get _accent => switch (_type) {
        TxnType.income => AppColors.income,
        TxnType.expense => AppColors.expense,
        TxnType.transfer => AppColors.transfer,
      };

  double? get _amount => double.tryParse(_amountCtrl.text.trim());

  bool get _valid {
    final amt = _amount;
    if (amt == null || amt <= 0) return false;
    switch (_type) {
      case TxnType.expense:
        return _categoryIds.isNotEmpty && _paymentModeId != null;
      case TxnType.income:
        return _accountId != null;
      case TxnType.transfer:
        return _fromAccountId != null &&
            _toAccountId != null &&
            _fromAccountId != _toAccountId;
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2015),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final data = ref.read(appProvider);
    final notifier = ref.read(appProvider.notifier);
    final amt = _amount!;
    String? accountId = _accountId;
    if (_type == TxnType.expense) {
      accountId = data.paymentModeById(_paymentModeId)?.linkedAccountId;
    }

    final txn = AppTransaction(
      id: widget.existing?.id ?? notifier.newId(),
      type: _type,
      amount: amt,
      date: _date,
      categoryIds: _categoryIds.toList(),
      paymentModeId: _type == TxnType.expense ? _paymentModeId : null,
      accountId: _type == TxnType.transfer ? null : accountId,
      fromAccountId: _type == TxnType.transfer ? _fromAccountId : null,
      toAccountId: _type == TxnType.transfer ? _toAccountId : null,
      note: _noteCtrl.text.trim(),
      tagIds: _tagIds.toList(),
      source: widget.existing?.source ?? TxnSource.manual,
      linkRefId: widget.existing?.linkRefId,
      imagePaths: _type == TxnType.transfer ? const [] : _imagePaths.toList(),
    );

    // Delete receipt files the user removed while editing.
    for (final old in _originalImagePaths) {
      if (!_imagePaths.contains(old)) await ImageStore.remove(old);
    }

    if (_editing) {
      await notifier.updateTransaction(txn);
    } else {
      await notifier.addTransaction(txn);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appProvider);
    final symbol = data.settings.currencySymbol;

    return SheetScaffold(
      title: _editing
          ? 'Edit ${_type.name}'
          : 'Add ${_type.name[0].toUpperCase()}${_type.name.substring(1)}',
      icon: switch (_type) {
        TxnType.income => Icons.arrow_downward_rounded,
        TxnType.expense => Icons.arrow_upward_rounded,
        TxnType.transfer => Icons.swap_horiz_rounded,
      },
      iconColor: _accent,
      footer: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: _accent),
          onPressed: _valid ? _save : null,
          child: Text(_editing ? 'Save changes' : 'Add ${_type.name}'),
        ),
      ),
      children: [
        if (!_editing) _typeSelector(),
        SheetSection(
          label: 'Amount',
          hint: '*required',
          child: TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              prefixText: '$symbol ',
              prefixStyle: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface),
              hintText: '0',
            ),
          ),
        ),
        if (_type == TxnType.transfer) ..._transferFields(data),
        if (_type == TxnType.expense) _categorySection(data, required: true),
        if (_type == TxnType.income) _incomeAccountSection(data),
        if (_type == TxnType.income) _categorySection(data, required: false),
        _dateSection(),
        if (_type == TxnType.expense) _paymentModeSection(data),
        _tagSection(data),
        if (_type != TxnType.transfer) _receiptsSection(),
        _noteSection(),
      ],
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_imagePaths.length >= 3) return;
    try {
      final picked = await ImagePicker()
          .pickImage(source: source, imageQuality: 70, maxWidth: 1600);
      if (picked == null) return;
      final stored = await ImageStore.add(picked.path);
      if (mounted) setState(() => _imagePaths.add(stored));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not add image: $e')));
      }
    }
  }

  Widget _receiptsSection() {
    return SheetSection(
      label: 'Receipts (optional, up to 3)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final path in _imagePaths)
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: File(path).existsSync()
                          ? Image.file(File(path),
                              width: 72, height: 72, fit: BoxFit.cover)
                          : Container(
                              width: 72,
                              height: 72,
                              color: Colors.black12,
                              child: const Icon(Icons.broken_image_outlined)),
                    ),
                    Positioned(
                      top: -6,
                      right: -6,
                      child: IconButton(
                        iconSize: 18,
                        onPressed: () =>
                            setState(() => _imagePaths.remove(path)),
                        icon: const CircleAvatar(
                          radius: 11,
                          backgroundColor: Colors.black54,
                          child: Icon(Icons.close,
                              size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              if (_imagePaths.length < 3) ...[
                _addImageButton(Icons.photo_library_rounded, 'Gallery',
                    () => _pickImage(ImageSource.gallery)),
                _addImageButton(Icons.photo_camera_rounded, 'Camera',
                    () => _pickImage(ImageSource.camera)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _addImageButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.4)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.primary, size: 22),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    fontSize: 10, color: AppColors.primary)),
          ],
        ),
      ),
    );
  }

  Widget _typeSelector() {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            for (final t in TxnType.values)
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _type = t),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _type == t
                          ? switch (t) {
                              TxnType.income => AppColors.income,
                              TxnType.expense => AppColors.expense,
                              TxnType.transfer => AppColors.transfer,
                            }
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Text(
                      '${t.name[0].toUpperCase()}${t.name.substring(1)}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _type == t
                            ? Colors.white
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _transferFields(data) {
    return [
      SheetSection(
        label: 'From account',
        hint: '*required',
        child: _accountChips(
          data.accounts,
          selectedId: _fromAccountId,
          onTap: (id) => setState(() => _fromAccountId = id),
        ),
      ),
      SheetSection(
        label: 'To account',
        hint: '*required',
        child: _accountChips(
          data.accounts,
          selectedId: _toAccountId,
          disabledId: _fromAccountId,
          onTap: (id) => setState(() => _toAccountId = id),
        ),
      ),
    ];
  }

  Widget _accountChips(
    List<Account> accounts, {
    required String? selectedId,
    String? disabledId,
    required ValueChanged<String> onTap,
  }) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final a in accounts)
          _ChoiceChipTile(
            label: a.name,
            icon: AppIcons.of(a.iconKey),
            color: Color(a.colorValue),
            selected: selectedId == a.id,
            disabled: disabledId == a.id,
            onTap: () => onTap(a.id),
          ),
      ],
    );
  }

  Widget _incomeAccountSection(data) {
    return SheetSection(
      label: 'Deposit to',
      hint: '*required',
      child: _accountChips(
        data.accounts,
        selectedId: _accountId,
        onTap: (id) => setState(() => _accountId = id),
      ),
    );
  }

  Widget _categorySection(data, {required bool required}) {
    final cats = (data.categories as List).where((c) {
      if (_type == TxnType.income) {
        return c.kind == CategoryKind.income || c.kind == CategoryKind.both;
      }
      return c.kind == CategoryKind.expense || c.kind == CategoryKind.both;
    }).toList();
    return SheetSection(
      label: 'Categories${_type == TxnType.expense ? '' : ' (optional)'}',
      hint: required ? '*select 1+' : null,
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final c in cats)
            _ChoiceChipTile(
              label: c.name,
              icon: AppIcons.of(c.iconKey),
              color: Color(c.colorValue),
              selected: _categoryIds.contains(c.id),
              onTap: () => setState(() {
                if (!_categoryIds.remove(c.id)) _categoryIds.add(c.id);
              }),
            ),
        ],
      ),
    );
  }

  Widget _dateSection() {
    return SheetSection(
      label: 'Date',
      child: InkWell(
        onTap: _pickDate,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.calendar_today_rounded, size: 20),
              const SizedBox(width: 12),
              Text(Formatters.weekday(_date),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              const Icon(Icons.edit_rounded, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _paymentModeSection(AppData data) {
    final modes = data.paymentModes;
    return SheetSection(
      label: 'Payment mode',
      hint: '*required',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final m in modes)
            _ChoiceChipTile(
              label: data.paymentModeLabel(m),
              icon: AppIcons.of(m.brandIconKey),
              color: Color(
                  data.paymentModeColor(m, AppColors.primary.toARGB32())),
              selected: _paymentModeId == m.id,
              onTap: () => setState(() => _paymentModeId = m.id),
            ),
        ],
      ),
    );
  }

  Widget _tagSection(data) {
    final tags = data.tags as List;
    if (tags.isEmpty) return const SizedBox.shrink();
    return SheetSection(
      label: 'Tags (optional)',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final t in tags)
            _ChoiceChipTile(
              label: '#${t.name}',
              color: AppColors.accent,
              selected: _tagIds.contains(t.id),
              onTap: () => setState(() {
                if (!_tagIds.remove(t.id)) _tagIds.add(t.id);
              }),
            ),
        ],
      ),
    );
  }

  Widget _noteSection() {
    return SheetSection(
      label: 'Note (optional)',
      child: TextField(
        controller: _noteCtrl,
        maxLines: 2,
        decoration: const InputDecoration(hintText: 'Add a note...'),
      ),
    );
  }
}

/// A pill-style selectable chip with an optional leading icon.
class _ChoiceChipTile extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color color;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;

  const _ChoiceChipTile({
    required this.label,
    this.icon,
    required this.color,
    required this.selected,
    this.disabled = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.onSurface;
    return Opacity(
      opacity: disabled ? 0.35 : 1,
      child: GestureDetector(
        onTap: disabled ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.18) : base.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? color : Colors.transparent,
              width: 1.6,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: selected ? color : base.withValues(alpha: 0.7)),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? color : base.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
