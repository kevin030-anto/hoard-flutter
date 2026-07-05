import 'enums.dart';

/// The single unified register entry — income, expense, OR transfer.
///
/// For income/expense: [paymentModeId] + [accountId] identify where money moved.
/// For transfer: [fromAccountId] is debited and [toAccountId] is credited; it is
/// one record (no payment mode), shown as "From X → ₹n → To Y".
class AppTransaction {
  final String id;
  final TxnType type;
  final double amount;
  final DateTime date;
  final List<String> categoryIds;
  final String? paymentModeId;
  final String? accountId;
  final String? fromAccountId;
  final String? toAccountId;
  final String note;
  final List<String> tagIds;
  final TxnSource source;
  final String? linkRefId; // pending item / auto-pay that produced this
  final List<String> imagePaths; // receipt image file paths (max 3)

  const AppTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.date,
    this.categoryIds = const [],
    this.paymentModeId,
    this.accountId,
    this.fromAccountId,
    this.toAccountId,
    this.note = '',
    this.tagIds = const [],
    this.source = TxnSource.manual,
    this.linkRefId,
    this.imagePaths = const [],
  });

  AppTransaction copyWith({
    TxnType? type,
    double? amount,
    DateTime? date,
    List<String>? categoryIds,
    String? paymentModeId,
    String? accountId,
    String? fromAccountId,
    String? toAccountId,
    String? note,
    List<String>? tagIds,
    TxnSource? source,
    String? linkRefId,
    List<String>? imagePaths,
  }) {
    return AppTransaction(
      id: id,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      categoryIds: categoryIds ?? this.categoryIds,
      paymentModeId: paymentModeId ?? this.paymentModeId,
      accountId: accountId ?? this.accountId,
      fromAccountId: fromAccountId ?? this.fromAccountId,
      toAccountId: toAccountId ?? this.toAccountId,
      note: note ?? this.note,
      tagIds: tagIds ?? this.tagIds,
      source: source ?? this.source,
      linkRefId: linkRefId ?? this.linkRefId,
      imagePaths: imagePaths ?? this.imagePaths,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'amount': amount,
        'date': date.toIso8601String(),
        'categoryIds': categoryIds,
        'paymentModeId': paymentModeId,
        'accountId': accountId,
        'fromAccountId': fromAccountId,
        'toAccountId': toAccountId,
        'note': note,
        'tagIds': tagIds,
        'source': source.name,
        'linkRefId': linkRefId,
        'imagePaths': imagePaths,
      };

  factory AppTransaction.fromJson(Map<String, dynamic> json) => AppTransaction(
        id: json['id'] as String,
        type: enumFromName(TxnType.values, json['type'] as String?,
            TxnType.expense),
        amount: (json['amount'] as num).toDouble(),
        date: DateTime.parse(json['date'] as String),
        categoryIds: (json['categoryIds'] as List?)?.cast<String>() ?? const [],
        paymentModeId: json['paymentModeId'] as String?,
        accountId: json['accountId'] as String?,
        fromAccountId: json['fromAccountId'] as String?,
        toAccountId: json['toAccountId'] as String?,
        note: json['note'] as String? ?? '',
        tagIds: (json['tagIds'] as List?)?.cast<String>() ?? const [],
        source: enumFromName(
            TxnSource.values, json['source'] as String?, TxnSource.manual),
        linkRefId: json['linkRefId'] as String?,
        imagePaths: (json['imagePaths'] as List?)?.cast<String>() ?? const [],
      );
}
