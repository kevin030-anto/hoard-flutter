import 'package:flutter/material.dart';

/// Maps stable string keys (stored in models / backups) to [IconData]. Keeping
/// keys as strings keeps the data layer free of Flutter types and makes backups
/// portable. Add new icons here; never renumber existing keys.
class AppIcons {
  AppIcons._();

  static const IconData _fallback = Icons.label_rounded;

  static const Map<String, IconData> _map = {
    // Accounts
    'bank': Icons.account_balance_rounded,
    'cash': Icons.payments_rounded,
    'wallet': Icons.account_balance_wallet_rounded,
    'card': Icons.credit_card_rounded,
    'savings': Icons.savings_rounded,
    // Payment brand glyphs (representative Material icons; SVG brands optional)
    'upi': Icons.qr_code_rounded,
    'gpay': Icons.g_mobiledata_rounded,
    'phonepe': Icons.phone_android_rounded,
    'paytm': Icons.account_balance_wallet_rounded,
    'bhim': Icons.account_balance_rounded,
    'amazonpay': Icons.shopping_cart_rounded,
    'banktransfer': Icons.swap_horiz_rounded,
    // Categories / daily use
    'food': Icons.restaurant_rounded,
    'breakfast': Icons.free_breakfast_rounded,
    'lunch': Icons.lunch_dining_rounded,
    'dinner': Icons.dinner_dining_rounded,
    'snacks': Icons.fastfood_rounded,
    'tea': Icons.coffee_rounded,
    'juice': Icons.local_drink_rounded,
    'shopping': Icons.shopping_bag_rounded,
    'grocery': Icons.local_grocery_store_rounded,
    'transport': Icons.directions_car_rounded,
    'bus': Icons.directions_bus_rounded,
    'train': Icons.train_rounded,
    'flight': Icons.flight_rounded,
    'fuel': Icons.local_gas_station_rounded,
    'entertainment': Icons.movie_rounded,
    'health': Icons.local_hospital_rounded,
    'education': Icons.school_rounded,
    'rent': Icons.home_rounded,
    'salary': Icons.work_rounded,
    'gift': Icons.card_giftcard_rounded,
    'bills': Icons.receipt_long_rounded,
    'mobile': Icons.smartphone_rounded,
    'internet': Icons.wifi_rounded,
    'investment': Icons.trending_up_rounded,
    'pet': Icons.pets_rounded,
    'fitness': Icons.fitness_center_rounded,
    'beauty': Icons.spa_rounded,
    'travel': Icons.luggage_rounded,
    'category': Icons.category_rounded,
    'autopay': Icons.autorenew_rounded,
    'repeat': Icons.repeat_rounded,
    'star': Icons.star_rounded,
    'heart': Icons.favorite_rounded,
  };

  static IconData of(String key) => _map[key] ?? _fallback;

  /// Keys offered in the icon picker, grouped for a tidy UI.
  static const List<String> accountIcons = [
    'bank', 'cash', 'wallet', 'card', 'savings',
  ];

  static const List<String> paymentIcons = [
    'cash', 'upi', 'gpay', 'phonepe', 'paytm', 'bhim', 'amazonpay',
    'banktransfer', 'card',
  ];

  static const List<String> categoryIcons = [
    'food', 'breakfast', 'lunch', 'dinner', 'snacks', 'tea', 'juice',
    'shopping', 'grocery', 'transport', 'bus', 'train', 'flight', 'fuel',
    'entertainment', 'health', 'education', 'rent', 'salary', 'gift', 'bills',
    'mobile', 'internet', 'investment', 'pet', 'fitness', 'beauty', 'travel',
    'star', 'heart', 'category',
  ];

  static const List<String> autoPayIcons = [
    'autopay', 'repeat', 'rent', 'salary', 'bills', 'investment', 'mobile',
    'internet', 'card', 'savings',
  ];
}
