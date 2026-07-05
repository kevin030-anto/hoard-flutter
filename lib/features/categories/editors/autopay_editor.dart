import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/icons/icon_registry.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/auto_pay.dart';
import '../../../data/models/enums.dart';
import '../../../providers/app_providers.dart';
import '../../../shared/widgets/pickers.dart';
import '../../../shared/widgets/sheet_scaffold.dart';
import '../../../shared/widgets/wheel_pickers.dart';

Future<void> showAutoPayEditor(BuildContext context, {AutoPay? existing}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AutoPayEditor(existing: existing),
  );
}

const _shortMonths = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

class _AutoPayEditor extends ConsumerStatefulWidget {
  final AutoPay? existing;
  const _AutoPayEditor({this.existing});

  @override
  ConsumerState<_AutoPayEditor> createState() => _AutoPayEditorState();
}

class _AutoPayEditorState extends ConsumerState<_AutoPayEditor> {
  final _nameCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  late int _color;
  late String _icon;
  late FlowType _flow;
  late RepeatType _repeat;
  late DateTime _startDate;
  final Set<int> _weekdays = {};
  late int _dayOfMonth;
  late int _monthOfYear;
  late int _yearValue;
  late bool _notify;
  int? _notifyMinutes;
  final Set<String> _categoryIds = {};
  String? _paymentModeId;
  String? _accountId;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final now = DateTime.now();
    _color = e?.colorValue ?? AppColors.palette.first.toARGB32();
    _icon = e?.iconKey ?? 'autopay';
    _flow = e?.flow ?? FlowType.expense;
    _repeat = e?.repeat ?? RepeatType.monthly;
    _startDate = e?.startDate ?? DateTime(now.year, now.month, now.day);
    _dayOfMonth = e?.dayOfMonth ?? now.day;
    _monthOfYear = e?.monthOfYear ?? now.month;
    _yearValue = e?.yearValue ?? now.year;
    _notify = e?.notifyEnabled ?? false;
    _notifyMinutes = e?.notifyMinutes;
    _paymentModeId = e?.paymentModeId;
    _accountId = e?.accountId;
    if (e != null) {
      _nameCtrl.text = e.name;
      _amountCtrl.text = e.amount == e.amount.roundToDouble()
          ? e.amount.toStringAsFixed(0)
          : '${e.amount}';
      _weekdays.addAll(e.weekdays);
      _categoryIds.addAll(e.categoryIds);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  double? get _amount => double.tryParse(_amountCtrl.text.trim());

  bool get _valid {
    if (_nameCtrl.text.trim().isEmpty) return false;
    if ((_amount ?? 0) <= 0) return false;
    if (_repeat == RepeatType.weekly && _weekdays.isEmpty) return false;
    if (_flow == FlowType.expense) {
      return _categoryIds.isNotEmpty && _paymentModeId != null;
    }
    return _accountId != null;
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appProvider);
    return SheetScaffold(
      title: _editing ? 'Edit Auto-Pay' : 'Add Auto-Pay',
      icon: AppIcons.of(_icon),
      iconColor: Color(_color),
      footer: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
            onPressed: _valid ? _save : null,
            child: Text(_editing ? 'Save' : 'Add')),
      ),
      children: [
        // 1. Name
        SheetSection(
          label: 'Name',
          child: TextField(
            controller: _nameCtrl,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(hintText: 'e.g. Rent, SIP, Salary'),
          ),
        ),
        // 2. Amount
        SheetSection(
          label: 'Amount',
          hint: '*required',
          child: TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
            ],
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
                prefixText: '${data.settings.currencySymbol} ', hintText: '0'),
          ),
        ),
        // 3. Type
        SheetSection(
          label: 'Type',
          child: Row(
            children: [
              _flowOption(FlowType.expense, 'Expense', AppColors.expense),
              const SizedBox(width: 12),
              _flowOption(FlowType.income, 'Income', AppColors.income),
            ],
          ),
        ),
        // 4. Repeat
        SheetSection(
          label: 'Repeat',
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final r in RepeatType.values)
                ChoiceChip(
                  label: Text(_repeatLabel(r)),
                  selected: _repeat == r,
                  onSelected: (_) => setState(() => _repeat = r),
                ),
            ],
          ),
        ),
        // 4b. Conditional recurrence detail
        _recurrenceDetail(),
        // 5. Notification
        SheetSection(
          label: 'Reminder & auto-add',
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _notify,
                title: const Text('Notify & auto-add at a set time'),
                onChanged: (v) => setState(() {
                  _notify = v;
                  _notifyMinutes ??= 9 * 60;
                }),
              ),
              if (_notify)
                _tappableRow(
                  Icons.access_time_rounded,
                  _notifyMinutes == null
                      ? 'Pick a time'
                      : _formatMinutes(_notifyMinutes!),
                  () async {
                    final t = await showTimeWheel(context,
                        initial: _timeFromMinutes(_notifyMinutes ?? 9 * 60));
                    if (t != null) {
                      setState(() => _notifyMinutes = t.hour * 60 + t.minute);
                    }
                  },
                ),
            ],
          ),
        ),
        // 6. Categories / payment mode (expense) or account (income)
        if (_flow == FlowType.expense) ...[
          SheetSection(
            label: 'Categories',
            hint: '*select 1+',
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final c in data.categories.where((c) =>
                    c.kind == CategoryKind.expense ||
                    c.kind == CategoryKind.both))
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
          ),
        ] else
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
        // 7. Color
        SheetSection(
          label: 'Color',
          child: ColorPicker(
              selected: _color, onChanged: (c) => setState(() => _color = c)),
        ),
        // 8. Icon
        SheetSection(
          label: 'Icon',
          child: IconPicker(
            iconKeys: AppIcons.autoPayIcons,
            selected: _icon,
            color: _color,
            onChanged: (k) => setState(() => _icon = k),
          ),
        ),
      ],
    );
  }

  Widget _recurrenceDetail() {
    switch (_repeat) {
      case RepeatType.none:
        return SheetSection(
          label: 'Date',
          child: _tappableRow(Icons.calendar_today_rounded,
              Formatters.dayMonthYear(_startDate), () => _pickDate()),
        );
      case RepeatType.daily:
        return SheetSection(
          label: 'Start date',
          child: _tappableRow(Icons.calendar_today_rounded,
              Formatters.dayMonthYear(_startDate), () => _pickDate()),
        );
      case RepeatType.weekly:
        return SheetSection(
          label: 'Days',
          hint: '*select 1+',
          child: WeekdayPicker(
            selected: _weekdays,
            onChanged: (s) => setState(() {
              _weekdays
                ..clear()
                ..addAll(s);
            }),
          ),
        );
      case RepeatType.monthly:
        return SheetSection(
          label: 'Day & start month',
          child: _tappableRow(
            Icons.event_repeat_rounded,
            'Day $_dayOfMonth · from ${_shortMonths[_monthOfYear - 1]}',
            () async {
              final r = await showDayMonthWheel(context,
                  initialDay: _dayOfMonth, initialMonth: _monthOfYear);
              if (r != null) {
                setState(() {
                  _dayOfMonth = r.day;
                  _monthOfYear = r.month;
                });
              }
            },
          ),
        );
      case RepeatType.yearly:
        return SheetSection(
          label: 'Month & start year',
          child: _tappableRow(
            Icons.event_rounded,
            '${_shortMonths[_monthOfYear - 1]} $_yearValue',
            () async {
              final r = await showMonthYearRecurrence(context,
                  initialMonth: _monthOfYear, initialYear: _yearValue);
              if (r != null) {
                setState(() {
                  _monthOfYear = r.month;
                  _yearValue = r.year;
                });
              }
            },
          ),
        );
    }
  }

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate.isBefore(DateTime(today.year, today.month, today.day))
          ? today
          : _startDate,
      firstDate: DateTime(today.year, today.month, today.day), // no past dates
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Widget _tappableRow(IconData icon, String label, VoidCallback onTap) {
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
            Icon(icon, size: 20),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _flowOption(FlowType flow, String label, Color color) {
    final selected = _flow == flow;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _flow = flow),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.15)
                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: selected ? color : Colors.transparent, width: 1.6),
          ),
          child: Text(label,
              style: TextStyle(
                  fontWeight: FontWeight.w600, color: selected ? color : null)),
        ),
      ),
    );
  }

  String _repeatLabel(RepeatType r) => switch (r) {
        RepeatType.none => 'One-time',
        RepeatType.daily => 'Daily',
        RepeatType.weekly => 'Weekly',
        RepeatType.monthly => 'Monthly',
        RepeatType.yearly => 'Yearly',
      };

  TimeOfDay _timeFromMinutes(int m) => TimeOfDay(hour: m ~/ 60, minute: m % 60);
  String _formatMinutes(int m) =>
      _timeFromMinutes(m).format(context);

  Future<void> _save() async {
    final notifier = ref.read(appProvider.notifier);
    final now = DateTime.now();
    // One-time/daily use the picked date; others anchor to now.
    final startDate =
        (_repeat == RepeatType.none || _repeat == RepeatType.daily)
            ? _startDate
            : DateTime(now.year, now.month, now.day);

    final autoPay = (widget.existing ??
            AutoPay(
              id: notifier.newId(),
              name: '',
              amount: 0,
              colorValue: _color,
              iconKey: _icon,
              startDate: startDate,
            ))
        .copyWith(
      name: _nameCtrl.text.trim(),
      amount: _amount,
      colorValue: _color,
      iconKey: _icon,
      startDate: startDate,
      repeat: _repeat,
      flow: _flow,
      weekdays: _weekdays.toList()..sort(),
      dayOfMonth: _dayOfMonth,
      monthOfYear: _monthOfYear,
      yearValue: _yearValue,
      categoryIds: _flow == FlowType.expense ? _categoryIds.toList() : const [],
      paymentModeId: _flow == FlowType.expense ? _paymentModeId : null,
      accountId: _flow == FlowType.income ? _accountId : null,
      notifyEnabled: _notify,
      notifyMinutes: _notify ? _notifyMinutes : null,
      clearNotifyMinutes: !_notify,
    );
    await notifier.upsertAutoPay(autoPay);
    if (mounted) Navigator.pop(context);
  }
}
