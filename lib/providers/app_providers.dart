import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/models/account.dart';
import '../data/models/app_settings.dart';
import '../data/models/app_tag.dart';
import '../data/models/app_transaction.dart';
import '../data/models/auto_pay.dart';
import '../data/models/category.dart';
import '../data/models/enums.dart';
import '../data/models/payment_mode.dart';
import '../data/models/pending_item.dart';
import '../data/images/image_store.dart';
import '../data/notifications/autopay_scheduler.dart';
import '../data/repositories/app_data.dart';
import '../data/repositories/autopay_engine.dart';
import '../data/repositories/hive_boxes.dart';

/// Injected in main() via ProviderScope override once boxes are opened.
final hiveBoxesProvider = Provider<HiveBoxes>(
  (ref) => throw UnimplementedError('hiveBoxesProvider must be overridden'),
);

/// Single source of truth for all app data.
final appProvider =
    NotifierProvider<AppNotifier, AppData>(AppNotifier.new);

const _uuid = Uuid();

class AppNotifier extends Notifier<AppData> {
  late final HiveBoxes _b;

  @override
  AppData build() {
    _b = ref.read(hiveBoxesProvider);
    return _load();
  }

  String newId() => _uuid.v4();

  // ---------------------------------------------------------------- load
  AppData _load() {
    List<T> readAll<T>(box, T Function(Map<String, dynamic>) from) =>
        (box.values as Iterable<String>)
            .map((s) => from(jsonDecode(s) as Map<String, dynamic>))
            .toList();

    final txns = readAll(_b.transactions, AppTransaction.fromJson)
      ..sort((a, b) => b.date.compareTo(a.date));

    final settingsRaw = _b.settings.get('app');
    final settings = settingsRaw == null
        ? const AppSettings()
        : AppSettings.fromJson(jsonDecode(settingsRaw) as Map<String, dynamic>);

    final accounts = readAll(_b.accounts, Account.fromJson)
      ..sort((a, b) => a.order.compareTo(b.order));
    final paymentModes = readAll(_b.paymentModes, PaymentMode.fromJson)
      ..sort((a, b) => a.order.compareTo(b.order));
    final categories = readAll(_b.categories, Category.fromJson)
      ..sort((a, b) => a.order.compareTo(b.order));
    final tags = readAll(_b.tags, AppTag.fromJson)
      ..sort((a, b) => a.order.compareTo(b.order));

    return AppData(
      accounts: accounts,
      paymentModes: paymentModes,
      categories: categories,
      tags: tags,
      transactions: txns,
      pending: readAll(_b.pending, PendingItem.fromJson),
      autoPays: readAll(_b.autoPays, AutoPay.fromJson),
      settings: settings,
    );
  }

  void reload() => state = _load();

  // ---------------------------------------------------------------- balance
  Future<void> _adjustAccount(String? accountId, double delta) async {
    if (accountId == null) return;
    final raw = _b.accounts.get(accountId);
    if (raw == null) return;
    final acc = Account.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    await _b.accounts
        .put(accountId, jsonEncode(acc.copyWith(balance: acc.balance + delta).toJson()));
  }

  /// Applies (sign +1) or reverses (sign -1) a transaction's effect on balances.
  Future<void> _applyTxnEffect(AppTransaction t, {required int sign}) async {
    final amt = t.amount * sign;
    switch (t.type) {
      case TxnType.expense:
        await _adjustAccount(t.accountId, -amt);
        break;
      case TxnType.income:
        await _adjustAccount(t.accountId, amt);
        break;
      case TxnType.transfer:
        await _adjustAccount(t.fromAccountId, -amt);
        await _adjustAccount(t.toAccountId, amt);
        break;
    }
  }

  // ---------------------------------------------------------------- txns
  Future<AppTransaction> addTransaction(AppTransaction t) async {
    await _b.transactions.put(t.id, jsonEncode(t.toJson()));
    await _applyTxnEffect(t, sign: 1);
    reload();
    return t;
  }

  Future<void> updateTransaction(AppTransaction updated) async {
    final oldRaw = _b.transactions.get(updated.id);
    if (oldRaw != null) {
      final old =
          AppTransaction.fromJson(jsonDecode(oldRaw) as Map<String, dynamic>);
      await _applyTxnEffect(old, sign: -1);
    }
    await _b.transactions.put(updated.id, jsonEncode(updated.toJson()));
    await _applyTxnEffect(updated, sign: 1);
    reload();
  }

  Future<void> deleteTransaction(String id) async {
    final raw = _b.transactions.get(id);
    if (raw != null) {
      final t = AppTransaction.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      await _applyTxnEffect(t, sign: -1);
      for (final path in t.imagePaths) {
        await ImageStore.remove(path);
      }
      await _b.transactions.delete(id);
    }
    reload();
  }

  // ---------------------------------------------------------------- accounts
  Future<void> upsertAccount(Account a) async {
    await _b.accounts.put(a.id, jsonEncode(a.toJson()));
    reload();
  }

  Future<void> deleteAccount(String id) async {
    await _b.accounts.delete(id);
    reload();
  }

  // ------------------------------------------------------------ payment modes
  Future<void> upsertPaymentMode(PaymentMode p) async {
    await _b.paymentModes.put(p.id, jsonEncode(p.toJson()));
    reload();
  }

  Future<void> deletePaymentMode(String id) async {
    await _b.paymentModes.delete(id);
    reload();
  }

  // ---------------------------------------------------------------- categories
  Future<void> upsertCategory(Category c) async {
    await _b.categories.put(c.id, jsonEncode(c.toJson()));
    reload();
  }

  Future<void> deleteCategory(String id) async {
    await _b.categories.delete(id);
    reload();
  }

  // ---------------------------------------------------------------- tags
  Future<AppTag> upsertTag(AppTag t) async {
    await _b.tags.put(t.id, jsonEncode(t.toJson()));
    reload();
    return t;
  }

  Future<void> deleteTag(String id) async {
    await _b.tags.delete(id);
    reload();
  }

  // ---------------------------------------------------------------- reorder
  Future<void> _reorder(
    box,
    List<String> orderedIds,
    Map<String, dynamic> Function(Map<String, dynamic> json, int order) apply,
  ) async {
    for (var i = 0; i < orderedIds.length; i++) {
      final raw = box.get(orderedIds[i]);
      if (raw == null) continue;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      await box.put(orderedIds[i], jsonEncode(apply(json, i)));
    }
    reload();
  }

  Future<void> reorderAccounts(List<String> orderedIds) => _reorder(
      _b.accounts,
      orderedIds,
      (j, i) => Account.fromJson(j).copyWith(order: i).toJson());

  Future<void> reorderPaymentModes(List<String> orderedIds) => _reorder(
      _b.paymentModes,
      orderedIds,
      (j, i) => PaymentMode.fromJson(j).copyWith(order: i).toJson());

  Future<void> reorderCategories(List<String> orderedIds) => _reorder(
      _b.categories,
      orderedIds,
      (j, i) => Category.fromJson(j).copyWith(order: i).toJson());

  Future<void> reorderTags(List<String> orderedIds) => _reorder(_b.tags,
      orderedIds, (j, i) => AppTag.fromJson(j).copyWith(order: i).toJson());

  // -------------------------------------------------------- auto-pay CRUD
  Future<void> upsertAutoPay(AutoPay a) async {
    await _b.autoPays.put(a.id, jsonEncode(a.toJson()));
    reload();
    AutoPayScheduler.rescheduleAll(state.autoPays);
  }

  Future<void> deleteAutoPay(String id) async {
    await _b.autoPays.delete(id);
    reload();
    AutoPayScheduler.rescheduleAll(state.autoPays);
  }

  // ---------------------------------------------------------------- pending
  Future<void> upsertPending(PendingItem p) async {
    await _b.pending.put(p.id, jsonEncode(p.toJson()));
    reload();
  }

  Future<void> deletePending(String id) async {
    await _b.pending.delete(id);
    reload();
  }

  /// Marks a pending item done. For toPay/toReceive this also posts the linked
  /// transaction (expense/income) to the register.
  Future<void> completePending(
    PendingItem item, {
    String? paymentModeId,
    String? accountId,
    DateTime? date,
  }) async {
    final when = date ?? DateTime.now();
    if (item.kind == PendingKind.todo) {
      await upsertPending(
          item.copyWith(status: PendingStatus.done, doneDate: when));
      return;
    }
    final txn = AppTransaction(
      id: newId(),
      type: item.kind == PendingKind.toPay ? TxnType.expense : TxnType.income,
      amount: item.amount ?? 0,
      date: when,
      categoryIds: item.categoryIds,
      paymentModeId: paymentModeId,
      accountId: accountId,
      note: item.note,
      tagIds: item.tagIds,
      source: TxnSource.pending,
      linkRefId: item.id,
    );
    await addTransaction(txn);
    await upsertPending(item.copyWith(
      status: PendingStatus.done,
      doneDate: when,
      paymentModeId: paymentModeId,
      accountId: accountId,
      createdTxnId: txn.id,
    ));
  }

  /// Reverts a completed pending item back to pending, deleting any spawned txn.
  Future<void> undoPending(PendingItem item) async {
    if (item.createdTxnId != null) {
      await deleteTransaction(item.createdTxnId!);
    }
    await upsertPending(item.copyWith(
      status: PendingStatus.pending,
      doneDate: null,
      createdTxnId: null,
    ));
  }

  // ---------------------------------------------------------------- auto-pay
  /// Posts any auto-pay occurrences due on/before today (shared engine, also
  /// used by the background alarm). Idempotent via [AutoPay.lastRunDate].
  Future<List<AutoPay>> processDueAutoPays() async {
    final fired = await AutoPayEngine.run(
      autoPays: _b.autoPays,
      transactions: _b.transactions,
      accounts: _b.accounts,
      paymentModes: _b.paymentModes,
      newId: newId,
    );
    reload();
    return fired;
  }

  // ---------------------------------------------------------------- settings
  Future<void> updateSettings(AppSettings s) async {
    await _b.settings.put('app', jsonEncode(s.toJson()));
    reload();
  }

  // ---------------------------------------------------------------- backup
  /// Snapshot of the selected data sets as raw JSON strings. [parts] may contain
  /// any of: logs, accounts, paymentModes, categories, autoPays, tags. Settings
  /// are always included. Pass null/empty for a full backup.
  Map<String, dynamic> exportData([Set<String>? parts]) {
    Map<String, String> dump(box) => {
          for (final k in (box.keys as Iterable)) k.toString(): box.get(k) as String,
        };
    final all = parts == null || parts.isEmpty;
    final boxes = <String, dynamic>{
      BoxNames.settings: dump(_b.settings),
    };
    if (all || parts.contains('logs')) {
      boxes[BoxNames.transactions] = dump(_b.transactions);
      boxes[BoxNames.pending] = dump(_b.pending);
    }
    if (all || parts.contains('accounts')) {
      boxes[BoxNames.accounts] = dump(_b.accounts);
    }
    if (all || parts.contains('paymentModes')) {
      boxes[BoxNames.paymentModes] = dump(_b.paymentModes);
    }
    if (all || parts.contains('categories')) {
      boxes[BoxNames.categories] = dump(_b.categories);
    }
    if (all || parts.contains('autoPays')) {
      boxes[BoxNames.autoPays] = dump(_b.autoPays);
    }
    if (all || parts.contains('tags')) {
      boxes[BoxNames.tags] = dump(_b.tags);
    }
    return {
      'app': 'FinFlow',
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'boxes': boxes,
    };
  }

  /// Restores a backup, replacing **only the boxes present in the file** (so a
  /// partial backup leaves untouched data intact). Throws on an invalid file.
  Future<void> importData(Map<String, dynamic> json) async {
    final boxes = json['boxes'];
    if (json['app'] != 'FinFlow' || boxes is! Map) {
      throw const FormatException('Not a valid FinFlow backup file.');
    }
    Future<void> restore(box, String name) async {
      final m = boxes[name];
      if (m is! Map) return; // absent → leave existing data untouched
      await box.clear();
      for (final e in m.entries) {
        await box.put(e.key, e.value as String);
      }
    }

    await restore(_b.accounts, BoxNames.accounts);
    await restore(_b.paymentModes, BoxNames.paymentModes);
    await restore(_b.categories, BoxNames.categories);
    await restore(_b.tags, BoxNames.tags);
    await restore(_b.transactions, BoxNames.transactions);
    await restore(_b.pending, BoxNames.pending);
    await restore(_b.autoPays, BoxNames.autoPays);
    await restore(_b.settings, BoxNames.settings);
    reload();
  }

  // ---------------------------------------------------------------- bulk delete
  Future<void> deleteAllIncome() async {
    final ids = state.transactions
        .where((t) => t.type == TxnType.income)
        .map((t) => t.id)
        .toList();
    for (final id in ids) {
      await deleteTransaction(id);
    }
  }

  Future<void> deleteAllExpenses() async {
    final ids = state.transactions
        .where((t) => t.type == TxnType.expense)
        .map((t) => t.id)
        .toList();
    for (final id in ids) {
      await deleteTransaction(id);
    }
  }

  Future<void> deleteAllCategories() async {
    await _b.categories.clear();
    reload();
  }

  Future<void> deleteAllTags() async {
    await _b.tags.clear();
    reload();
  }

  /// Wipes everything — transactions, accounts, categories, tags, etc.
  Future<void> deleteAllData() async {
    await Future.wait([
      _b.accounts.clear(),
      _b.paymentModes.clear(),
      _b.categories.clear(),
      _b.tags.clear(),
      _b.transactions.clear(),
      _b.pending.clear(),
      _b.autoPays.clear(),
      _b.settings.clear(),
    ]);
    reload();
  }
}
