import 'enums.dart';

/// A recurring income/expense that auto-posts to the register on its due dates.
/// `lastRunDate` makes posting idempotent; `notifyEnabled` + `notifyMinutes`
/// drive the exact-time reminder / background auto-add.
class AutoPay {
  final String id;
  final String name;
  final double amount;
  final int colorValue;
  final String iconKey;
  final DateTime startDate; // anchor for one-time / daily / weekly
  final RepeatType repeat;
  final FlowType flow;
  final List<String> categoryIds; // expense flow
  final String? paymentModeId; // expense flow
  final String? accountId; // income flow
  final DateTime? lastRunDate;
  final bool notifyEnabled;

  // Recurrence details
  final List<int> weekdays; // weekly: 1=Mon..7=Sun
  final int dayOfMonth; // monthly: day of month it recurs (1..31, clamped)
  final int monthOfYear; // monthly: start month / yearly: month it runs
  final int yearValue; // yearly: the year it starts
  final int? notifyMinutes; // minutes since midnight for reminder/auto-add

  AutoPay({
    required this.id,
    required this.name,
    required this.amount,
    required this.colorValue,
    required this.iconKey,
    required this.startDate,
    this.repeat = RepeatType.none,
    this.flow = FlowType.expense,
    this.categoryIds = const [],
    this.paymentModeId,
    this.accountId,
    this.lastRunDate,
    this.notifyEnabled = true,
    this.weekdays = const [],
    this.dayOfMonth = 1,
    this.monthOfYear = 1,
    int? yearValue,
    this.notifyMinutes,
  }) : yearValue = yearValue ?? startDate.year;

  AutoPay copyWith({
    String? name,
    double? amount,
    int? colorValue,
    String? iconKey,
    DateTime? startDate,
    RepeatType? repeat,
    FlowType? flow,
    List<String>? categoryIds,
    String? paymentModeId,
    String? accountId,
    DateTime? lastRunDate,
    bool? notifyEnabled,
    List<int>? weekdays,
    int? dayOfMonth,
    int? monthOfYear,
    int? yearValue,
    int? notifyMinutes,
    bool clearNotifyMinutes = false,
  }) {
    return AutoPay(
      id: id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      colorValue: colorValue ?? this.colorValue,
      iconKey: iconKey ?? this.iconKey,
      startDate: startDate ?? this.startDate,
      repeat: repeat ?? this.repeat,
      flow: flow ?? this.flow,
      categoryIds: categoryIds ?? this.categoryIds,
      paymentModeId: paymentModeId ?? this.paymentModeId,
      accountId: accountId ?? this.accountId,
      lastRunDate: lastRunDate ?? this.lastRunDate,
      notifyEnabled: notifyEnabled ?? this.notifyEnabled,
      weekdays: weekdays ?? this.weekdays,
      dayOfMonth: dayOfMonth ?? this.dayOfMonth,
      monthOfYear: monthOfYear ?? this.monthOfYear,
      yearValue: yearValue ?? this.yearValue,
      notifyMinutes:
          clearNotifyMinutes ? null : (notifyMinutes ?? this.notifyMinutes),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'amount': amount,
        'colorValue': colorValue,
        'iconKey': iconKey,
        'startDate': startDate.toIso8601String(),
        'repeat': repeat.name,
        'flow': flow.name,
        'categoryIds': categoryIds,
        'paymentModeId': paymentModeId,
        'accountId': accountId,
        'lastRunDate': lastRunDate?.toIso8601String(),
        'notifyEnabled': notifyEnabled,
        'weekdays': weekdays,
        'dayOfMonth': dayOfMonth,
        'monthOfYear': monthOfYear,
        'yearValue': yearValue,
        'notifyMinutes': notifyMinutes,
      };

  factory AutoPay.fromJson(Map<String, dynamic> json) => AutoPay(
        id: json['id'] as String,
        name: json['name'] as String,
        amount: (json['amount'] as num).toDouble(),
        colorValue: (json['colorValue'] as num).toInt(),
        iconKey: json['iconKey'] as String? ?? 'autopay',
        startDate: DateTime.parse(json['startDate'] as String),
        repeat: enumFromName(
            RepeatType.values, json['repeat'] as String?, RepeatType.none),
        flow: enumFromName(
            FlowType.values, json['flow'] as String?, FlowType.expense),
        categoryIds: (json['categoryIds'] as List?)?.cast<String>() ?? const [],
        paymentModeId: json['paymentModeId'] as String?,
        accountId: json['accountId'] as String?,
        lastRunDate: json['lastRunDate'] == null
            ? null
            : DateTime.parse(json['lastRunDate'] as String),
        notifyEnabled: json['notifyEnabled'] as bool? ?? true,
        weekdays: (json['weekdays'] as List?)?.cast<int>() ?? const [],
        dayOfMonth: (json['dayOfMonth'] as num?)?.toInt() ?? 1,
        monthOfYear: (json['monthOfYear'] as num?)?.toInt() ?? 1,
        yearValue: (json['yearValue'] as num?)?.toInt(),
        notifyMinutes: (json['notifyMinutes'] as num?)?.toInt(),
      );
}
