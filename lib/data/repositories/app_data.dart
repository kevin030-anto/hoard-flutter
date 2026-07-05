import '../models/account.dart';
import '../models/app_settings.dart';
import '../models/app_tag.dart';
import '../models/app_transaction.dart';
import '../models/auto_pay.dart';
import '../models/category.dart';
import '../models/payment_mode.dart';
import '../models/pending_item.dart';

/// Immutable snapshot of all app data. Rebuilt whenever anything changes so
/// Riverpod consumers update reactively. Lookups are O(n) but n is tiny for a
/// personal finance app.
class AppData {
  final List<Account> accounts;
  final List<PaymentMode> paymentModes;
  final List<Category> categories;
  final List<AppTag> tags;
  final List<AppTransaction> transactions; // newest first
  final List<PendingItem> pending;
  final List<AutoPay> autoPays;
  final AppSettings settings;

  const AppData({
    required this.accounts,
    required this.paymentModes,
    required this.categories,
    required this.tags,
    required this.transactions,
    required this.pending,
    required this.autoPays,
    required this.settings,
  });

  static const empty = AppData(
    accounts: [],
    paymentModes: [],
    categories: [],
    tags: [],
    transactions: [],
    pending: [],
    autoPays: [],
    settings: AppSettings(),
  );

  Account? accountById(String? id) =>
      id == null ? null : accounts.where((a) => a.id == id).firstOrNull;
  PaymentMode? paymentModeById(String? id) =>
      id == null ? null : paymentModes.where((p) => p.id == id).firstOrNull;
  Category? categoryById(String? id) =>
      id == null ? null : categories.where((c) => c.id == id).firstOrNull;
  AppTag? tagById(String? id) =>
      id == null ? null : tags.where((t) => t.id == id).firstOrNull;

  List<Category> categoriesByIds(List<String> ids) =>
      ids.map(categoryById).whereType<Category>().toList();
  List<AppTag> tagsByIds(List<String> ids) =>
      ids.map(tagById).whereType<AppTag>().toList();

  double get totalBalance =>
      accounts.fold(0.0, (sum, a) => sum + a.balance);

  /// Accounts the user chose to show on Home.
  List<Account> get homeAccounts =>
      accounts.where((a) => a.showOnHome).toList();

  /// Balance shown on Home = sum of the shown accounts only.
  double get shownBalance =>
      homeAccounts.fold(0.0, (sum, a) => sum + a.balance);

  bool tagIdIsSavings(String id) => tagById(id)?.isSavings ?? false;

  // Next sort position for a newly created entity (append to end).
  static int _nextOrder(Iterable<int> orders) {
    var max = -1;
    for (final o in orders) {
      if (o > max) max = o;
    }
    return max + 1;
  }

  int get nextAccountOrder => _nextOrder(accounts.map((a) => a.order));
  int get nextPaymentModeOrder =>
      _nextOrder(paymentModes.map((p) => p.order));
  int get nextCategoryOrder => _nextOrder(categories.map((c) => c.order));
  int get nextTagOrder => _nextOrder(tags.map((t) => t.order));

  /// Display label for a payment mode: "Name (LinkedAccount)".
  String paymentModeLabel(PaymentMode mode) {
    final account = accountById(mode.linkedAccountId);
    return account == null ? mode.name : '${mode.name} (${account.name})';
  }

  String? paymentModeLabelById(String? id) {
    final mode = paymentModeById(id);
    return mode == null ? null : paymentModeLabel(mode);
  }

  /// A payment mode is tinted with its linked account's color.
  int paymentModeColor(PaymentMode mode, int fallback) =>
      accountById(mode.linkedAccountId)?.colorValue ?? fallback;
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}
