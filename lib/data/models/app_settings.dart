import 'package:flutter/material.dart';

/// App-wide preferences. Stored as a single JSON record.
class AppSettings {
  final ThemeMode themeMode;
  final String currencySymbol;
  final bool showCurrencySymbol;

  /// When true, swipe directions are swapped: right = Edit, left = Delete.
  /// Default (false): right = Delete, left = Edit.
  final bool swapSwipeActions;

  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.currencySymbol = '₹',
    this.showCurrencySymbol = true,
    this.swapSwipeActions = false,
  });

  /// Symbol to actually render (empty when the user hides it).
  String get effectiveSymbol => showCurrencySymbol ? currencySymbol : '';

  AppSettings copyWith({
    ThemeMode? themeMode,
    String? currencySymbol,
    bool? showCurrencySymbol,
    bool? swapSwipeActions,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      showCurrencySymbol: showCurrencySymbol ?? this.showCurrencySymbol,
      swapSwipeActions: swapSwipeActions ?? this.swapSwipeActions,
    );
  }

  Map<String, dynamic> toJson() => {
        'themeMode': themeMode.name,
        'currencySymbol': currencySymbol,
        'showCurrencySymbol': showCurrencySymbol,
        'swapSwipeActions': swapSwipeActions,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        themeMode: ThemeMode.values.firstWhere(
          (m) => m.name == json['themeMode'],
          orElse: () => ThemeMode.system,
        ),
        currencySymbol: json['currencySymbol'] as String? ?? '₹',
        showCurrencySymbol: json['showCurrencySymbol'] as bool? ?? true,
        swapSwipeActions: json['swapSwipeActions'] as bool? ?? false,
      );
}
