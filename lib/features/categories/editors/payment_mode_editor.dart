import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/icons/icon_registry.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/payment_mode.dart';
import '../../../providers/app_providers.dart';
import '../../../shared/widgets/pickers.dart';
import '../../../shared/widgets/sheet_scaffold.dart';

Future<void> showPaymentModeEditor(BuildContext context,
    {PaymentMode? existing}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PaymentModeEditor(existing: existing),
  );
}

class _PaymentModeEditor extends ConsumerStatefulWidget {
  final PaymentMode? existing;
  const _PaymentModeEditor({this.existing});

  @override
  ConsumerState<_PaymentModeEditor> createState() => _PaymentModeEditorState();
}

class _PaymentModeEditorState extends ConsumerState<_PaymentModeEditor> {
  final _nameCtrl = TextEditingController();
  late PaymentModeType _type;
  String? _accountId;
  late String _icon;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _type = e?.type ?? PaymentModeType.digital;
    _accountId = e?.linkedAccountId;
    _icon = e?.brandIconKey ?? 'upi';
    if (e != null) _nameCtrl.text = e.name;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  bool get _valid => _nameCtrl.text.trim().isNotEmpty && _accountId != null;

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appProvider);
    // Cash modes link to cash accounts; digital modes link to bank accounts.
    final accounts = data.accounts
        .where((a) => _type == PaymentModeType.cash
            ? a.type == AccountType.cash
            : a.type == AccountType.bank)
        .toList();
    if (_accountId != null && accounts.every((a) => a.id != _accountId)) {
      _accountId = accounts.isNotEmpty ? accounts.first.id : null;
    }
    _accountId ??= accounts.isNotEmpty ? accounts.first.id : null;

    return SheetScaffold(
      title: _editing ? 'Edit Payment Mode' : 'Add Payment Mode',
      icon: Icons.payment_rounded,
      footer: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
            onPressed: _valid ? _save : null,
            child: Text(_editing ? 'Save' : 'Add')),
      ),
      children: [
        SheetSection(
          label: 'Name',
          child: TextField(
            controller: _nameCtrl,
            onChanged: (_) => setState(() {}),
            decoration:
                const InputDecoration(hintText: 'e.g. Google Pay, Cash, BHIM'),
          ),
        ),
        SheetSection(
          label: 'Type',
          child: Row(
            children: [
              _typeOption(PaymentModeType.cash, 'Cash'),
              const SizedBox(width: 12),
              _typeOption(PaymentModeType.digital, 'Digital (UPI/Bank)'),
            ],
          ),
        ),
        SheetSection(
          label: _type == PaymentModeType.cash
              ? 'Linked cash account'
              : 'Linked bank account',
          hint: '*required',
          child: accounts.isEmpty
              ? Text(
                  'No ${_type == PaymentModeType.cash ? 'cash' : 'bank'} account yet — add one first.',
                  style: const TextStyle(color: Colors.redAccent))
              : Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final a in accounts)
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
          label: 'Icon',
          child: IconPicker(
            iconKeys: AppIcons.paymentIcons,
            selected: _icon,
            color: AppColors.primary.toARGB32(),
            onChanged: (k) => setState(() => _icon = k),
          ),
        ),
      ],
    );
  }

  Widget _typeOption(PaymentModeType type, String label) {
    final selected = _type == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _type = type;
          _accountId = null;
          _icon = type == PaymentModeType.cash ? 'cash' : 'upi';
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.15)
                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: selected ? AppColors.primary : Colors.transparent,
                width: 1.6),
          ),
          child: Text(label,
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: selected ? AppColors.primary : null)),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final notifier = ref.read(appProvider.notifier);
    final mode = (widget.existing ??
            PaymentMode(
              id: notifier.newId(),
              name: '',
              type: _type,
              linkedAccountId: '',
              brandIconKey: _icon,
              order: ref.read(appProvider).nextPaymentModeOrder,
            ))
        .copyWith(
      name: _nameCtrl.text.trim(),
      type: _type,
      linkedAccountId: _accountId,
      brandIconKey: _icon,
    );
    await notifier.upsertPaymentMode(mode);
    if (mounted) Navigator.pop(context);
  }
}
