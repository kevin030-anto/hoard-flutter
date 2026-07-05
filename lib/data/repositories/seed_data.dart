import 'dart:convert';

import '../models/account.dart';
import '../models/app_tag.dart';
import '../models/category.dart';
import '../models/enums.dart';
import '../models/payment_mode.dart';
import 'hive_boxes.dart';

/// Writes a sensible starter set on first launch so the app is usable
/// immediately (mirrors the reference app's defaults).
class SeedData {
  static Future<void> seedIfEmpty(HiveBoxes boxes) async {
    if (!boxes.isEmpty) return;

    final cash = Account(
      id: 'seed-cash-1',
      name: 'Cash',
      type: AccountType.cash,
      colorValue: 0xFF64748B,
      iconKey: 'cash',
      balance: 0,
    );
    final bank1 = Account(
      id: 'seed-bank-1',
      name: 'Bank 1',
      type: AccountType.bank,
      colorValue: 0xFF6C5CE7,
      iconKey: 'bank',
      balance: 0,
    );
    final bank2 = Account(
      id: 'seed-bank-2',
      name: 'Bank 2',
      type: AccountType.bank,
      colorValue: 0xFF06B6D4,
      iconKey: 'bank',
      balance: 0,
    );
    for (final a in [cash, bank1, bank2]) {
      await boxes.accounts.put(a.id, jsonEncode(a.toJson()));
    }

    final modes = [
      PaymentMode(
          id: 'seed-pm-cash',
          name: 'Cash',
          type: PaymentModeType.cash,
          linkedAccountId: cash.id,
          brandIconKey: 'cash'),
      PaymentMode(
          id: 'seed-pm-gpay',
          name: 'Google Pay',
          type: PaymentModeType.digital,
          linkedAccountId: bank1.id,
          brandIconKey: 'gpay'),
      PaymentMode(
          id: 'seed-pm-bhim',
          name: 'BHIM UPI',
          type: PaymentModeType.digital,
          linkedAccountId: bank1.id,
          brandIconKey: 'bhim'),
      PaymentMode(
          id: 'seed-pm-transfer',
          name: 'Bank Transfer',
          type: PaymentModeType.digital,
          linkedAccountId: bank1.id,
          brandIconKey: 'banktransfer'),
    ];
    for (final m in modes) {
      await boxes.paymentModes.put(m.id, jsonEncode(m.toJson()));
    }

    final cats = <Category>[
      _cat('Breakfast', 0xFFF43F5E, 'breakfast'),
      _cat('Lunch', 0xFFF59E0B, 'lunch'),
      _cat('Dinner', 0xFF8B5CF6, 'dinner'),
      _cat('Snacks', 0xFF84CC16, 'snacks'),
      _cat('Tea/Coffee', 0xFF92857A, 'tea'),
      _cat('Shopping', 0xFF6C5CE7, 'shopping'),
      _cat('Grocery', 0xFFEC4899, 'grocery'),
      _cat('Transport', 0xFF22C55E, 'transport'),
      _cat('Entertainment', 0xFFF59E0B, 'entertainment'),
      _cat('Health', 0xFF14B8A6, 'health'),
      _cat('Education', 0xFFF97316, 'education'),
      _cat('Rent', 0xFF10B981, 'rent'),
      _cat('Bills', 0xFF0EA5E9, 'bills'),
      _cat('Salary', 0xFF22C55E, 'salary', kind: CategoryKind.income),
    ];
    for (final c in cats) {
      await boxes.categories.put(c.id, jsonEncode(c.toJson()));
    }

    final tags = [
      AppTag(id: 'seed-tag-savings', name: 'savings'),
      AppTag(id: 'seed-tag-travel', name: 'travel'),
      AppTag(id: 'seed-tag-work', name: 'work'),
    ];
    for (final t in tags) {
      await boxes.tags.put(t.id, jsonEncode(t.toJson()));
    }
  }

  static Category _cat(String name, int color, String icon,
          {CategoryKind kind = CategoryKind.expense}) =>
      Category(
        id: 'seed-cat-${name.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '')}',
        name: name,
        colorValue: color,
        iconKey: icon,
        kind: kind,
      );
}
