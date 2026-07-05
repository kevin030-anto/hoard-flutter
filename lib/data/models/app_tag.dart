/// A hashtag-style label attached to transactions/pending items. A tag named
/// "savings" (case-insensitive) flags a transaction as savings in Analysis.
class AppTag {
  final String id;
  final String name;

  /// Sort position (set by drag-reorder / the Sort button).
  final int order;

  /// When the tag was created — used by the New/Old sort options.
  final DateTime createdAt;

  AppTag({
    required this.id,
    required this.name,
    this.order = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  AppTag copyWith({String? name, int? order, DateTime? createdAt}) => AppTag(
        id: id,
        name: name ?? this.name,
        order: order ?? this.order,
        createdAt: createdAt ?? this.createdAt,
      );

  bool get isSavings => name.toLowerCase() == 'savings';

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'order': order,
        'createdAt': createdAt.toIso8601String(),
      };

  factory AppTag.fromJson(Map<String, dynamic> json) => AppTag(
        id: json['id'] as String,
        name: json['name'] as String,
        order: (json['order'] as num?)?.toInt() ?? 0,
        createdAt: json['createdAt'] == null
            ? DateTime.fromMillisecondsSinceEpoch(0)
            : DateTime.parse(json['createdAt'] as String),
      );
}
