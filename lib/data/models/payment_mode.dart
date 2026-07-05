import 'enums.dart';

/// A way to pay/receive money (Cash, GPay-Bank1, BHIM, Paytm...). Each mode is
/// linked to one [Account]; choosing it in a transaction debits/credits that
/// account. `brandIconKey` selects the brand glyph (gpay/bhim/paytm/upi/cash...).
class PaymentMode {
  final String id;
  final String name;
  final PaymentModeType type;
  final String linkedAccountId;
  final String brandIconKey;

  /// Sort position in the Pay Modes list (set by drag-reorder).
  final int order;

  const PaymentMode({
    required this.id,
    required this.name,
    required this.type,
    required this.linkedAccountId,
    required this.brandIconKey,
    this.order = 0,
  });

  PaymentMode copyWith({
    String? name,
    PaymentModeType? type,
    String? linkedAccountId,
    String? brandIconKey,
    int? order,
  }) {
    return PaymentMode(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      linkedAccountId: linkedAccountId ?? this.linkedAccountId,
      brandIconKey: brandIconKey ?? this.brandIconKey,
      order: order ?? this.order,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'linkedAccountId': linkedAccountId,
        'brandIconKey': brandIconKey,
        'order': order,
      };

  factory PaymentMode.fromJson(Map<String, dynamic> json) => PaymentMode(
        id: json['id'] as String,
        name: json['name'] as String,
        type: enumFromName(PaymentModeType.values, json['type'] as String?,
            PaymentModeType.digital),
        linkedAccountId: json['linkedAccountId'] as String? ?? '',
        brandIconKey: json['brandIconKey'] as String? ?? 'upi',
        order: (json['order'] as num?)?.toInt() ?? 0,
      );
}
