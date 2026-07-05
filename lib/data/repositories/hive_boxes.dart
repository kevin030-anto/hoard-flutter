import 'package:hive_ce_flutter/hive_flutter.dart';

/// Box names. Each entity box stores `id -> jsonEncode(model.toJson())` as a
/// String value, which avoids Hive type adapters entirely and makes
/// backup/restore a straight dump/load.
class BoxNames {
  BoxNames._();
  static const accounts = 'accounts';
  static const paymentModes = 'payment_modes';
  static const categories = 'categories';
  static const tags = 'tags';
  static const transactions = 'transactions';
  static const pending = 'pending';
  static const autoPays = 'autopays';
  static const settings = 'settings';

  static const all = [
    accounts,
    paymentModes,
    categories,
    tags,
    transactions,
    pending,
    autoPays,
    settings,
  ];
}

/// Holds the opened boxes so they can be injected via Riverpod.
class HiveBoxes {
  final Box<String> accounts;
  final Box<String> paymentModes;
  final Box<String> categories;
  final Box<String> tags;
  final Box<String> transactions;
  final Box<String> pending;
  final Box<String> autoPays;
  final Box<String> settings;

  const HiveBoxes({
    required this.accounts,
    required this.paymentModes,
    required this.categories,
    required this.tags,
    required this.transactions,
    required this.pending,
    required this.autoPays,
    required this.settings,
  });

  static Future<HiveBoxes> open() async {
    await Hive.initFlutter();
    final results = await Future.wait(
      BoxNames.all.map((n) => Hive.openBox<String>(n)),
    );
    final byName = {
      for (var i = 0; i < BoxNames.all.length; i++) BoxNames.all[i]: results[i],
    };
    return HiveBoxes(
      accounts: byName[BoxNames.accounts]!,
      paymentModes: byName[BoxNames.paymentModes]!,
      categories: byName[BoxNames.categories]!,
      tags: byName[BoxNames.tags]!,
      transactions: byName[BoxNames.transactions]!,
      pending: byName[BoxNames.pending]!,
      autoPays: byName[BoxNames.autoPays]!,
      settings: byName[BoxNames.settings]!,
    );
  }

  bool get isEmpty =>
      accounts.isEmpty &&
      categories.isEmpty &&
      paymentModes.isEmpty &&
      transactions.isEmpty;
}
