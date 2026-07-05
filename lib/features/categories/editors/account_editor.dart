import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/account.dart';
import '../../../data/models/enums.dart';
import '../../../providers/app_providers.dart';
import '../../../shared/widgets/pickers.dart';
import '../../../shared/widgets/sheet_scaffold.dart';

Future<void> showAccountEditor(BuildContext context, {Account? existing}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AccountEditor(existing: existing),
  );
}

class _AccountEditor extends ConsumerStatefulWidget {
  final Account? existing;
  const _AccountEditor({this.existing});

  @override
  ConsumerState<_AccountEditor> createState() => _AccountEditorState();
}

class _AccountEditorState extends ConsumerState<_AccountEditor> {
  final _nameCtrl = TextEditingController();
  final _balanceCtrl = TextEditingController();
  late AccountType _type;
  late int _color;
  late String _icon;
  bool _initialized = false;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _type = e?.type ?? AccountType.bank;
    _color = e?.colorValue ?? AppColors.palette.first.toARGB32();
    _icon = e?.iconKey ?? 'bank';
    if (e != null) {
      _nameCtrl.text = e.name;
      _balanceCtrl.text =
          e.balance == e.balance.roundToDouble() ? e.balance.toStringAsFixed(0) : '${e.balance}';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _balanceCtrl.dispose();
    super.dispose();
  }

  void _applyTypeDefaults() {
    final data = ref.read(appProvider);
    final count =
        data.accounts.where((a) => a.type == _type).length + 1;
    _nameCtrl.text = _type == AccountType.cash ? 'Cash $count' : 'Bank $count';
    _icon = _type == AccountType.cash ? 'cash' : 'bank';
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized && !_editing) {
      _applyTypeDefaults();
      _initialized = true;
    }
    return SheetScaffold(
      title: _editing ? 'Edit Account' : 'Add Balance',
      icon: Icons.account_balance_wallet_rounded,
      footer: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _nameCtrl.text.trim().isEmpty ? null : _save,
          child: Text(_editing ? 'Save' : 'Add'),
        ),
      ),
      children: [
        if (!_editing)
          SheetSection(
            label: 'Type',
            child: Row(
              children: [
                _typeOption(AccountType.cash, 'Cash', Icons.payments_rounded),
                const SizedBox(width: 12),
                _typeOption(
                    AccountType.bank, 'Bank Account', Icons.account_balance_rounded),
              ],
            ),
          ),
        SheetSection(
          label: 'Name',
          child: TextField(
            controller: _nameCtrl,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(hintText: 'Account name'),
          ),
        ),
        SheetSection(
          label: _editing ? 'Current balance' : 'Opening balance',
          child: TextField(
            controller: _balanceCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
            ],
            decoration: const InputDecoration(hintText: '0'),
          ),
        ),
        SheetSection(
          label: 'Color',
          child: ColorPicker(
              selected: _color, onChanged: (c) => setState(() => _color = c)),
        ),
        SheetSection(
          label: 'Icon',
          child: IconPicker(
            iconKeys: const ['bank', 'cash', 'wallet', 'card', 'savings'],
            selected: _icon,
            color: _color,
            onChanged: (k) => setState(() => _icon = k),
          ),
        ),
      ],
    );
  }

  Widget _typeOption(AccountType type, String label, IconData icon) {
    final selected = _type == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _type = type;
          _applyTypeDefaults();
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.15)
                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: selected ? AppColors.primary : Colors.transparent,
                width: 1.6),
          ),
          child: Column(
            children: [
              Icon(icon, color: selected ? AppColors.primary : null),
              const SizedBox(height: 6),
              Text(label,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: selected ? AppColors.primary : null)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final notifier = ref.read(appProvider.notifier);
    final balance = double.tryParse(_balanceCtrl.text.trim()) ?? 0;
    final account = (widget.existing ??
            Account(
              id: notifier.newId(),
              name: '',
              type: _type,
              colorValue: _color,
              iconKey: _icon,
              order: ref.read(appProvider).nextAccountOrder,
            ))
        .copyWith(
      name: _nameCtrl.text.trim(),
      type: _type,
      colorValue: _color,
      iconKey: _icon,
      balance: balance,
    );
    await notifier.upsertAccount(account);
    if (mounted) Navigator.pop(context);
  }
}
