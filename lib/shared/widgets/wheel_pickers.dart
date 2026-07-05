import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Reusable spinner-style pickers (month/year, year, time) plus a weekday
/// selector, matching the reference spinner look.

const _months = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];
const _monthsShort = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

// ------------------------------------------------------------------ low-level
class WheelColumn extends StatefulWidget {
  final List<String> items;
  final int initialIndex;
  final ValueChanged<int> onChanged;
  final double width;
  const WheelColumn({
    super.key,
    required this.items,
    required this.initialIndex,
    required this.onChanged,
    this.width = 80,
  });

  @override
  State<WheelColumn> createState() => _WheelColumnState();
}

class _WheelColumnState extends State<WheelColumn> {
  late FixedExtentScrollController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = FixedExtentScrollController(initialItem: widget.initialIndex);
  }

  @override
  void didUpdateWidget(covariant WheelColumn old) {
    super.didUpdateWidget(old);
    if (widget.initialIndex != _ctrl.selectedItem) {
      _ctrl.jumpToItem(widget.initialIndex);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return SizedBox(
      width: widget.width,
      height: 180,
      child: ListWheelScrollView.useDelegate(
        controller: _ctrl,
        itemExtent: 44,
        physics: const FixedExtentScrollPhysics(),
        perspective: 0.004,
        onSelectedItemChanged: widget.onChanged,
        childDelegate: ListWheelChildBuilderDelegate(
          childCount: widget.items.length,
          builder: (context, i) {
            if (i < 0 || i >= widget.items.length) return null;
            return Center(
              child: Text(
                widget.items[i],
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: onSurface),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SpinnerFrame extends StatelessWidget {
  final List<Widget> children;
  const _SpinnerFrame({required this.children});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          height: 46,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: children),
      ],
    );
  }
}

Widget _sheetShell(BuildContext context,
    {required String title, required Widget body, required VoidCallback onDone}) {
  return Container(
    decoration: BoxDecoration(
      color: Theme.of(context).scaffoldBackgroundColor,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
    ),
    padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: 16 + MediaQuery.of(context).padding.bottom),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 42,
          height: 5,
          decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(height: 12),
        Text(title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        body,
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(onPressed: onDone, child: const Text('Done')),
        ),
      ],
    ),
  );
}

// ------------------------------------------------------------- month + year
class MonthYearSelection {
  final DateTime? month; // first day of the month
  final DateTimeRange? range;
  const MonthYearSelection.single(this.month) : range = null;
  const MonthYearSelection.ranged(this.range) : month = null;
  bool get isRange => range != null;
}

DateTime _clampToCurrent(int year, int month0) {
  final now = DateTime.now();
  var y = year, m = month0 + 1;
  if (y > now.year || (y == now.year && m > now.month)) {
    y = now.year;
    m = now.month;
  }
  return DateTime(y, m, 1);
}

DateTime _lastDayOfMonth(DateTime d) => DateTime(d.year, d.month + 1, 0);

Future<MonthYearSelection?> showMonthYearPicker(
  BuildContext context, {
  DateTime? initialMonth,
  DateTimeRange? initialRange,
  bool allowRange = true,
}) {
  return showModalBottomSheet<MonthYearSelection>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _MonthYearSheet(
      initialMonth: initialMonth,
      initialRange: initialRange,
      allowRange: allowRange,
    ),
  );
}

class _MonthYearSheet extends StatefulWidget {
  final DateTime? initialMonth;
  final DateTimeRange? initialRange;
  final bool allowRange;
  const _MonthYearSheet(
      {this.initialMonth, this.initialRange, required this.allowRange});

  @override
  State<_MonthYearSheet> createState() => _MonthYearSheetState();
}

class _MonthYearSheetState extends State<_MonthYearSheet> {
  final List<int> _years =
      [for (var y = 2015; y <= DateTime.now().year; y++) y];

  late bool _rangeMode;
  int _side = 0; // which range side is being edited (0=From, 1=To)
  // single / range-start
  late int _m1, _y1;
  // range-end
  late int _m2, _y2;

  @override
  void initState() {
    super.initState();
    _rangeMode = widget.initialRange != null;
    final base = widget.initialMonth ?? DateTime.now();
    _m1 = (widget.initialRange?.start ?? base).month - 1;
    _y1 = (widget.initialRange?.start ?? base).year;
    _m2 = (widget.initialRange?.end ?? base).month - 1;
    _y2 = (widget.initialRange?.end ?? base).year;
  }

  int _yearIndex(int y) {
    final i = _years.indexOf(y);
    return i < 0 ? _years.length - 1 : i;
  }

  Widget _monthYearRow(int month0, int year, void Function(int m, int y) set) {
    return _SpinnerFrame(
      children: [
        WheelColumn(
          items: _monthsShort,
          initialIndex: month0,
          width: 90,
          onChanged: (i) => set(i, year),
        ),
        WheelColumn(
          items: _years.map((e) => '$e').toList(),
          initialIndex: _yearIndex(year),
          width: 90,
          onChanged: (i) => set(month0, _years[i]),
        ),
      ],
    );
  }

  void _done() {
    if (_rangeMode) {
      var start = _clampToCurrent(_y1, _m1);
      var end = _clampToCurrent(_y2, _m2);
      if (end.isBefore(start)) {
        final t = start;
        start = end;
        end = t;
      }
      Navigator.pop(context,
          MonthYearSelection.ranged(DateTimeRange(start: start, end: _lastDayOfMonth(end))));
    } else {
      Navigator.pop(context, MonthYearSelection.single(_clampToCurrent(_y1, _m1)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return _sheetShell(
      context,
      title: _rangeMode ? 'Pick a date range' : 'Pick month & year',
      onDone: _done,
      body: Column(
        children: [
          if (widget.allowRange)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Month')),
                  ButtonSegment(value: true, label: Text('Range')),
                ],
                selected: {_rangeMode},
                onSelectionChanged: (s) => setState(() => _rangeMode = s.first),
              ),
            ),
          if (!_rangeMode)
            _monthYearRow(_m1, _y1, (m, y) => setState(() {
                  _m1 = m;
                  _y1 = y;
                }))
          else ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  _sideChip('From', _m1, _y1, _side == 0,
                      () => setState(() => _side = 0)),
                  const SizedBox(width: 10),
                  _sideChip('To', _m2, _y2, _side == 1,
                      () => setState(() => _side = 1)),
                ],
              ),
            ),
            if (_side == 0)
              _monthYearRow(_m1, _y1, (m, y) => setState(() {
                    _m1 = m;
                    _y1 = y;
                  }))
            else
              _monthYearRow(_m2, _y2, (m, y) => setState(() {
                    _m2 = m;
                    _y2 = y;
                  })),
          ],
        ],
      ),
    );
  }

  Widget _sideChip(
      String label, int month0, int year, bool selected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.15)
                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: selected ? AppColors.primary : Colors.transparent,
                width: 1.6),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      color: selected ? AppColors.primary : Colors.grey)),
              const SizedBox(height: 2),
              Text('${_monthsShort[month0]} $year',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: selected ? AppColors.primary : null)),
            ],
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------------- year
Future<int?> showYearWheel(BuildContext context,
    {required int initialYear, int spanForward = 30}) {
  final now = DateTime.now().year;
  final years = [for (var y = now; y <= now + spanForward; y++) y];
  var sel = initialYear < now ? now : initialYear;
  return showModalBottomSheet<int>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => _sheetShell(
        ctx,
        title: 'Pick a year',
        onDone: () => Navigator.pop(ctx, sel),
        body: _SpinnerFrame(children: [
          WheelColumn(
            items: years.map((e) => '$e').toList(),
            initialIndex: years.indexOf(sel).clamp(0, years.length - 1),
            width: 120,
            onChanged: (i) => sel = years[i],
          ),
        ]),
      ),
    ),
  );
}

// -------------------------------------------------------------------- time
Future<TimeOfDay?> showTimeWheel(BuildContext context,
    {required TimeOfDay initial}) {
  var hour12 = initial.hourOfPeriod == 0 ? 12 : initial.hourOfPeriod;
  var minute = initial.minute;
  var isPm = initial.period == DayPeriod.pm;
  final hours = [for (var h = 1; h <= 12; h++) h.toString().padLeft(2, '0')];
  final minutes = [for (var m = 0; m < 60; m++) m.toString().padLeft(2, '0')];

  return showModalBottomSheet<TimeOfDay>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => _sheetShell(
        ctx,
        title: 'Pick a time',
        onDone: () {
          final h24 = (hour12 % 12) + (isPm ? 12 : 0);
          Navigator.pop(ctx, TimeOfDay(hour: h24, minute: minute));
        },
        body: _SpinnerFrame(children: [
          WheelColumn(
            items: hours,
            initialIndex: hour12 - 1,
            width: 64,
            onChanged: (i) => hour12 = i + 1,
          ),
          WheelColumn(
            items: minutes,
            initialIndex: minute,
            width: 64,
            onChanged: (i) => minute = i,
          ),
          WheelColumn(
            items: const ['AM', 'PM'],
            initialIndex: isPm ? 1 : 0,
            width: 64,
            onChanged: (i) => isPm = i == 1,
          ),
        ]),
      ),
    ),
  );
}

/// Day + Month wheel (for Monthly auto-pay).
Future<({int day, int month})?> showDayMonthWheel(BuildContext context,
    {int initialDay = 1, int initialMonth = 1}) {
  var day = initialDay.clamp(1, 31);
  var month = initialMonth.clamp(1, 12);
  final days = [for (var d = 1; d <= 31; d++) d.toString().padLeft(2, '0')];
  return showModalBottomSheet<({int day, int month})>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _sheetShell(
      ctx,
      title: 'Pick day & month',
      onDone: () => Navigator.pop(ctx, (day: day, month: month)),
      body: _SpinnerFrame(children: [
        WheelColumn(
            items: days,
            initialIndex: day - 1,
            width: 80,
            onChanged: (i) => day = i + 1),
        WheelColumn(
            items: _monthsShort,
            initialIndex: month - 1,
            width: 90,
            onChanged: (i) => month = i + 1),
      ]),
    ),
  );
}

/// Month + Year wheel (for Yearly auto-pay). Years = current..+30.
Future<({int month, int year})?> showMonthYearRecurrence(BuildContext context,
    {int initialMonth = 1, required int initialYear}) {
  final nowY = DateTime.now().year;
  final years = [for (var y = nowY; y <= nowY + 30; y++) y];
  var month = initialMonth.clamp(1, 12);
  var year = initialYear < nowY ? nowY : initialYear;
  return showModalBottomSheet<({int month, int year})>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _sheetShell(
      ctx,
      title: 'Pick month & year',
      onDone: () => Navigator.pop(ctx, (month: month, year: year)),
      body: _SpinnerFrame(children: [
        WheelColumn(
            items: _monthsShort,
            initialIndex: month - 1,
            width: 90,
            onChanged: (i) => month = i + 1),
        WheelColumn(
            items: years.map((e) => '$e').toList(),
            initialIndex: years.indexOf(year).clamp(0, years.length - 1),
            width: 90,
            onChanged: (i) => year = years[i]),
      ]),
    ),
  );
}

String monthName(int month1) => _months[month1 - 1];
String monthShort(int month1) => _monthsShort[month1 - 1];

// ---------------------------------------------------------------- weekdays
class WeekdayPicker extends StatelessWidget {
  final Set<int> selected; // 1=Mon .. 7=Sun
  final ValueChanged<Set<int>> onChanged;
  const WeekdayPicker({super.key, required this.selected, required this.onChanged});

  static const _labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var d = 1; d <= 7; d++)
          GestureDetector(
            onTap: () {
              final next = {...selected};
              if (!next.remove(d)) next.add(d);
              onChanged(next);
            },
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected.contains(d)
                    ? AppColors.primary
                    : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                    color: selected.contains(d)
                        ? AppColors.primary
                        : Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.3)),
              ),
              child: Text(_labels[d - 1],
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: selected.contains(d)
                          ? Colors.white
                          : Theme.of(context).colorScheme.onSurface)),
            ),
          ),
      ],
    );
  }
}
