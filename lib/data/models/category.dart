import 'enums.dart';

/// A spending/earning category (Breakfast, Shopping, Salary...). `kind` limits
/// where it appears (expense, income, or both).
class Category {
  final String id;
  final String name;
  final int colorValue;
  final String iconKey;
  final CategoryKind kind;

  /// Sort position (set by drag-reorder / the Sort button).
  final int order;

  /// When the category was created — used by the New/Old sort options.
  final DateTime createdAt;

  Category({
    required this.id,
    required this.name,
    required this.colorValue,
    required this.iconKey,
    this.kind = CategoryKind.expense,
    this.order = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Category copyWith({
    String? name,
    int? colorValue,
    String? iconKey,
    CategoryKind? kind,
    int? order,
    DateTime? createdAt,
  }) {
    return Category(
      id: id,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
      iconKey: iconKey ?? this.iconKey,
      kind: kind ?? this.kind,
      order: order ?? this.order,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'colorValue': colorValue,
        'iconKey': iconKey,
        'kind': kind.name,
        'order': order,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: json['id'] as String,
        name: json['name'] as String,
        colorValue: (json['colorValue'] as num).toInt(),
        iconKey: json['iconKey'] as String? ?? 'category',
        kind: enumFromName(
            CategoryKind.values, json['kind'] as String?, CategoryKind.expense),
        order: (json['order'] as num?)?.toInt() ?? 0,
        createdAt: json['createdAt'] == null
            ? DateTime.fromMillisecondsSinceEpoch(0)
            : DateTime.parse(json['createdAt'] as String),
      );
}
