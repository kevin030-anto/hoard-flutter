import 'dart:io';

import 'package:finflow/data/models/account.dart';
import 'package:finflow/data/models/app_transaction.dart';
import 'package:finflow/data/models/auto_pay.dart';
import 'package:finflow/data/models/enums.dart';
import 'package:finflow/data/models/payment_mode.dart';
import 'package:finflow/data/models/pending_item.dart';
import 'package:finflow/data/repositories/hive_boxes.dart';
import 'package:finflow/providers/app_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

Future<HiveBoxes> _openTempBoxes() async {
  final dir = await Directory.systemTemp.createTemp('finflow_test');
  Hive.init(dir.path);
  final boxes = await Future.wait(
    BoxNames.all.map((n) => Hive.openBox<String>('${n}_${dir.path.hashCode}')),
  );
  return HiveBoxes(
    accounts: boxes[0],
    paymentModes: boxes[1],
    categories: boxes[2],
    tags: boxes[3],
    transactions: boxes[4],
    pending: boxes[5],
    autoPays: boxes[6],
    settings: boxes[7],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late AppNotifier notifier;

  setUp(() async {
    final boxes = await _openTempBoxes();
    container = ProviderContainer(
      overrides: [hiveBoxesProvider.overrideWithValue(boxes)],
    );
    notifier = container.read(appProvider.notifier);
  });

  tearDown(() async {
    container.dispose();
    await Hive.deleteFromDisk();
  });

  Account makeAccount(String id, double balance) => Account(
        id: id,
        name: id,
        type: AccountType.bank,
        colorValue: 0xFF000000,
        iconKey: 'bank',
        balance: balance,
      );

  test('expense debits its account', () async {
    await notifier.upsertAccount(makeAccount('a1', 1000));
    await notifier.addTransaction(AppTransaction(
      id: 't1',
      type: TxnType.expense,
      amount: 300,
      date: DateTime.now(),
      accountId: 'a1',
    ));
    expect(container.read(appProvider).accountById('a1')!.balance, 700);
  });

  test('income credits its account', () async {
    await notifier.upsertAccount(makeAccount('a1', 1000));
    await notifier.addTransaction(AppTransaction(
      id: 't1',
      type: TxnType.income,
      amount: 500,
      date: DateTime.now(),
      accountId: 'a1',
    ));
    expect(container.read(appProvider).accountById('a1')!.balance, 1500);
  });

  test('transfer moves money between accounts in one record', () async {
    await notifier.upsertAccount(makeAccount('a1', 1000));
    await notifier.upsertAccount(makeAccount('a2', 200));
    await notifier.addTransaction(AppTransaction(
      id: 't1',
      type: TxnType.transfer,
      amount: 300,
      date: DateTime.now(),
      fromAccountId: 'a1',
      toAccountId: 'a2',
    ));
    final data = container.read(appProvider);
    expect(data.accountById('a1')!.balance, 700);
    expect(data.accountById('a2')!.balance, 500);
    expect(data.transactions.length, 1);
  });

  test('editing an expense amount adjusts balance correctly', () async {
    await notifier.upsertAccount(makeAccount('a1', 1000));
    final t = AppTransaction(
      id: 't1',
      type: TxnType.expense,
      amount: 300,
      date: DateTime.now(),
      accountId: 'a1',
    );
    await notifier.addTransaction(t);
    await notifier.updateTransaction(t.copyWith(amount: 500));
    expect(container.read(appProvider).accountById('a1')!.balance, 500);
  });

  test('deleting a transaction restores balance', () async {
    await notifier.upsertAccount(makeAccount('a1', 1000));
    await notifier.addTransaction(AppTransaction(
      id: 't1',
      type: TxnType.expense,
      amount: 300,
      date: DateTime.now(),
      accountId: 'a1',
    ));
    await notifier.deleteTransaction('t1');
    expect(container.read(appProvider).accountById('a1')!.balance, 1000);
  });

  test('completing a "to receive" posts income and credits account', () async {
    await notifier.upsertAccount(makeAccount('a1', 1000));
    final item = PendingItem(
      id: 'p1',
      kind: PendingKind.toReceive,
      title: 'Chandan',
      amount: 159,
      date: DateTime.now(),
    );
    await notifier.upsertPending(item);
    await notifier.completePending(item, accountId: 'a1', date: DateTime.now());

    final data = container.read(appProvider);
    expect(data.accountById('a1')!.balance, 1159);
    expect(data.transactions.length, 1);
    expect(data.transactions.first.type, TxnType.income);
    expect(data.pending.first.isDone, true);
  });

  test('export then import restores all data', () async {
    await notifier.upsertAccount(makeAccount('a1', 1000));
    await notifier.addTransaction(AppTransaction(
      id: 't1',
      type: TxnType.expense,
      amount: 300,
      date: DateTime.now(),
      accountId: 'a1',
    ));
    final snapshot = notifier.exportData();

    await notifier.deleteAllData();
    expect(container.read(appProvider).accounts, isEmpty);
    expect(container.read(appProvider).transactions, isEmpty);

    await notifier.importData(snapshot);
    final data = container.read(appProvider);
    expect(data.accounts.length, 1);
    expect(data.accountById('a1')!.balance, 700);
    expect(data.transactions.length, 1);
  });

  test('deleteAllExpenses keeps income and restores their balance', () async {
    await notifier.upsertAccount(makeAccount('a1', 1000));
    await notifier.addTransaction(AppTransaction(
      id: 'exp',
      type: TxnType.expense,
      amount: 300,
      date: DateTime.now(),
      accountId: 'a1',
    ));
    await notifier.addTransaction(AppTransaction(
      id: 'inc',
      type: TxnType.income,
      amount: 200,
      date: DateTime.now(),
      accountId: 'a1',
    ));
    await notifier.deleteAllExpenses();
    final data = container.read(appProvider);
    expect(data.transactions.length, 1);
    expect(data.transactions.first.type, TxnType.income);
    // 1000 - 300 + 200 = 900, then deleting expense adds 300 back => 1200
    expect(data.accountById('a1')!.balance, 1200);
  });

  test('reorderAccounts persists order and _load returns sorted', () async {
    await notifier.upsertAccount(makeAccount('a1', 0));
    await notifier.upsertAccount(makeAccount('a2', 0));
    await notifier.upsertAccount(makeAccount('a3', 0));

    await notifier.reorderAccounts(['a3', 'a1', 'a2']);

    final ids =
        container.read(appProvider).accounts.map((a) => a.id).toList();
    expect(ids, ['a3', 'a1', 'a2']);
    expect(container.read(appProvider).accountById('a3')!.order, 0);
    expect(container.read(appProvider).accountById('a2')!.order, 2);
  });

  test('shownBalance sums only accounts flagged showOnHome', () async {
    await notifier.upsertAccount(makeAccount('a1', 1000));
    await notifier
        .upsertAccount(makeAccount('a2', 500).copyWith(showOnHome: false));
    final data = container.read(appProvider);
    expect(data.shownBalance, 1000);
    expect(data.totalBalance, 1500);
  });

  test('paymentModeLabel formats as "Name (Account)"', () async {
    await notifier.upsertAccount(makeAccount('SBI', 0));
    const mode = PaymentMode(
      id: 'pm1',
      name: 'UPI 3',
      type: PaymentModeType.digital,
      linkedAccountId: 'SBI',
      brandIconKey: 'upi',
    );
    await notifier.upsertPaymentMode(mode);
    expect(container.read(appProvider).paymentModeLabel(mode), 'UPI 3 (SBI)');
  });

  test('one-time auto-pay posts once when due and is idempotent', () async {
    await notifier.upsertAccount(makeAccount('a1', 1000));
    await notifier.upsertAutoPay(AutoPay(
      id: 'ap1',
      name: 'Bonus',
      amount: 500,
      colorValue: 0xFF000000,
      iconKey: 'salary',
      startDate: DateTime.now(),
      repeat: RepeatType.none,
      flow: FlowType.income, // income credits a1 directly
      accountId: 'a1',
    ));

    final fired = await notifier.processDueAutoPays();
    expect(fired.length, 1);
    expect(container.read(appProvider).transactions.length, 1);
    expect(container.read(appProvider).accountById('a1')!.balance, 1500);

    // Running again the same day must not double-post.
    final firedAgain = await notifier.processDueAutoPays();
    expect(firedAgain, isEmpty);
    expect(container.read(appProvider).transactions.length, 1);
  });

  test('deleteAllCategories / deleteAllTags clear only their box', () async {
    await notifier.upsertAccount(makeAccount('a1', 100));
    await notifier.deleteAllCategories();
    await notifier.deleteAllTags();
    final data = container.read(appProvider);
    expect(data.categories, isEmpty);
    expect(data.tags, isEmpty);
    expect(data.accounts.length, 1); // untouched
  });

  test('partial backup exports only selected boxes and restores in place',
      () async {
    await notifier.upsertAccount(makeAccount('a1', 1000));
    await notifier.addTransaction(AppTransaction(
      id: 't1',
      type: TxnType.expense,
      amount: 300,
      date: DateTime.now(),
      accountId: 'a1',
    ));

    // Back up only accounts.
    final backup = notifier.exportData({'accounts'});
    final boxes = backup['boxes'] as Map;
    expect(boxes.containsKey('accounts'), true);
    expect(boxes.containsKey('transactions'), false);

    // Mutate the account, then restore the partial backup.
    await notifier.upsertAccount(
        container.read(appProvider).accountById('a1')!.copyWith(balance: 5));
    await notifier.importData(backup);

    final data = container.read(appProvider);
    expect(data.accountById('a1')!.balance, 700); // accounts restored
    expect(data.transactions.length, 1); // transactions left intact
  });

  test('undo completed pending removes txn and restores balance', () async {
    await notifier.upsertAccount(makeAccount('a1', 1000));
    final item = PendingItem(
      id: 'p1',
      kind: PendingKind.toPay,
      title: 'Rent',
      amount: 500,
      date: DateTime.now(),
    );
    await notifier.upsertPending(item);
    await notifier.completePending(item, accountId: 'a1', date: DateTime.now());
    expect(container.read(appProvider).accountById('a1')!.balance, 500);

    final done = container.read(appProvider).pending.first;
    await notifier.undoPending(done);

    final data = container.read(appProvider);
    expect(data.accountById('a1')!.balance, 1000);
    expect(data.transactions, isEmpty);
    expect(data.pending.first.isDone, false);
  });
}
