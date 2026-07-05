import 'package:intl/intl.dart';

/// Currency + date formatting helpers. Currency symbol is injected so it can be
/// changed from Settings later.
class Formatters {
  Formatters._();

  static final NumberFormat _amount = NumberFormat('#,##0.##', 'en_IN');
  static final NumberFormat _amountWhole = NumberFormat('#,##0', 'en_IN');

  static String money(num value, {String symbol = '₹', bool sign = false}) {
    final abs = value.abs();
    final formatted =
        abs == abs.roundToDouble() ? _amountWhole.format(abs) : _amount.format(abs);
    final prefix = sign ? (value < 0 ? '-' : '+') : (value < 0 ? '-' : '');
    return '$prefix$symbol$formatted';
  }

  static String dayMonthYear(DateTime d) => DateFormat('dd MMM yyyy').format(d);
  static String weekday(DateTime d) => DateFormat('EEE, dd MMM yyyy').format(d);
  static String weekdayName(DateTime d) => DateFormat('EEEE').format(d);
  static String monthYear(DateTime d) => DateFormat('MMMM yyyy').format(d);
  static String monthShortYear(DateTime d) => DateFormat('MMM yyyy').format(d);
  static String shortDate(DateTime d) => DateFormat('dd/MM/yyyy').format(d);
  static String dayLabel(DateTime d) => DateFormat('d').format(d);
}
