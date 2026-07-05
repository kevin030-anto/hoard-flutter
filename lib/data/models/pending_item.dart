import 'enums.dart';

/// An item on the Pending page: money you owe (toPay), money owed to you
/// (toReceive), or a to-do. Completing a toPay/toReceive spawns a transaction
/// (linked back via the produced txn's linkRefId).
class PendingItem {
  final String id;
  final PendingKind kind;
  final String title;
  final double? amount;
  final List<String> categoryIds;
  final List<String> tagIds;
  final DateTime date;
  final String note;
  final PendingStatus status;
  final DateTime? doneDate;
  final String? paymentModeId; // chosen at completion (toPay/toReceive)
  final String? accountId;
  final String? createdTxnId;

  const PendingItem({
    required this.id,
    required this.kind,
    required this.title,
    this.amount,
    this.categoryIds = const [],
    this.tagIds = const [],
    required this.date,
    this.note = '',
    this.status = PendingStatus.pending,
    this.doneDate,
    this.paymentModeId,
    this.accountId,
    this.createdTxnId,
  });

  bool get isDone => status == PendingStatus.done;

  PendingItem copyWith({
    PendingKind? kind,
    String? title,
    double? amount,
    List<String>? categoryIds,
    List<String>? tagIds,
    DateTime? date,
    String? note,
    PendingStatus? status,
    DateTime? doneDate,
    String? paymentModeId,
    String? accountId,
    String? createdTxnId,
  }) {
    return PendingItem(
      id: id,
      kind: kind ?? this.kind,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      categoryIds: categoryIds ?? this.categoryIds,
      tagIds: tagIds ?? this.tagIds,
      date: date ?? this.date,
      note: note ?? this.note,
      status: status ?? this.status,
      doneDate: doneDate ?? this.doneDate,
      paymentModeId: paymentModeId ?? this.paymentModeId,
      accountId: accountId ?? this.accountId,
      createdTxnId: createdTxnId ?? this.createdTxnId,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'title': title,
        'amount': amount,
        'categoryIds': categoryIds,
        'tagIds': tagIds,
        'date': date.toIso8601String(),
        'note': note,
        'status': status.name,
        'doneDate': doneDate?.toIso8601String(),
        'paymentModeId': paymentModeId,
        'accountId': accountId,
        'createdTxnId': createdTxnId,
      };

  factory PendingItem.fromJson(Map<String, dynamic> json) => PendingItem(
        id: json['id'] as String,
        kind: enumFromName(
            PendingKind.values, json['kind'] as String?, PendingKind.todo),
        title: json['title'] as String? ?? '',
        amount: (json['amount'] as num?)?.toDouble(),
        categoryIds: (json['categoryIds'] as List?)?.cast<String>() ?? const [],
        tagIds: (json['tagIds'] as List?)?.cast<String>() ?? const [],
        date: DateTime.parse(json['date'] as String),
        note: json['note'] as String? ?? '',
        status: enumFromName(PendingStatus.values, json['status'] as String?,
            PendingStatus.pending),
        doneDate: json['doneDate'] == null
            ? null
            : DateTime.parse(json['doneDate'] as String),
        paymentModeId: json['paymentModeId'] as String?,
        accountId: json['accountId'] as String?,
        createdTxnId: json['createdTxnId'] as String?,
      );
}
