import 'enums.dart';

/// A balance bucket — either cash or a bank account. Lives under
/// Categories → Accounts and (up to 4) on the Home header.
class Account {
  final String id;
  final String name;
  final AccountType type;
  final int colorValue;
  final String iconKey;
  final double balance;

  /// Whether this account's card (and balance) appears on the Home screen.
  final bool showOnHome;

  /// Sort position in the Accounts list (set by drag-reorder).
  final int order;

  const Account({
    required this.id,
    required this.name,
    required this.type,
    required this.colorValue,
    required this.iconKey,
    this.balance = 0,
    this.showOnHome = true,
    this.order = 0,
  });

  Account copyWith({
    String? name,
    AccountType? type,
    int? colorValue,
    String? iconKey,
    double? balance,
    bool? showOnHome,
    int? order,
  }) {
    return Account(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      colorValue: colorValue ?? this.colorValue,
      iconKey: iconKey ?? this.iconKey,
      balance: balance ?? this.balance,
      showOnHome: showOnHome ?? this.showOnHome,
      order: order ?? this.order,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'colorValue': colorValue,
        'iconKey': iconKey,
        'balance': balance,
        'showOnHome': showOnHome,
        'order': order,
      };

  factory Account.fromJson(Map<String, dynamic> json) => Account(
        id: json['id'] as String,
        name: json['name'] as String,
        type: enumFromName(AccountType.values, json['type'] as String?,
            AccountType.bank),
        colorValue: (json['colorValue'] as num).toInt(),
        iconKey: json['iconKey'] as String? ?? 'bank',
        balance: (json['balance'] as num?)?.toDouble() ?? 0,
        showOnHome: json['showOnHome'] as bool? ?? true,
        order: (json['order'] as num?)?.toInt() ?? 0,
      );
}
