import 'package:flutter/material.dart';

/// Brand palette for FinFlow. Indigo/violet gradient accent (matching the
/// reference design), plus semantic colors for income/expense/transfer and the
/// Pending-page glows.
class AppColors {
  AppColors._();

  // Brand
  static const Color primary = Color(0xFF6C5CE7); // indigo-violet
  static const Color primaryDark = Color(0xFF5648C7);
  static const Color primaryLight = Color(0xFF8E7BFF);
  static const Color accent = Color(0xFF00D2A8); // teal accent

  static const LinearGradient brandGradient = LinearGradient(
    colors: [Color(0xFF7B6CF6), Color(0xFF5B7BFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Semantic
  static const Color income = Color(0xFF22C55E);
  static const Color expense = Color(0xFFF43F5E);
  static const Color transfer = Color(0xFF3B82F6);
  static const Color savings = Color(0xFF14B8A6);

  // Pending glows
  static const Color glowToPay = Color(0xFFF59E0B); // orange — you owe
  static const Color glowToReceive = Color(0xFFEF4444); // red — owed to you
  static const Color glowTodo = Color(0xFF3B82F6); // blue — to-do
  static const Color glowDone = Color(0xFF22C55E); // green — completed

  // Light surfaces
  static const Color lightBg = Color(0xFFF4F5FB);
  static const Color lightCard = Color(0xFFFFFFFF);

  // Dark surfaces
  static const Color darkBg = Color(0xFF14141C);
  static const Color darkCard = Color(0xFF1F1F2B);

  /// Palette offered in the color pickers.
  static const List<Color> palette = [
    Color(0xFF6C5CE7),
    Color(0xFF5B7BFF),
    Color(0xFF22C55E),
    Color(0xFF14B8A6),
    Color(0xFFF59E0B),
    Color(0xFFF43F5E),
    Color(0xFFEF4444),
    Color(0xFFEC4899),
    Color(0xFF8B5CF6),
    Color(0xFF06B6D4),
    Color(0xFF84CC16),
    Color(0xFFF97316),
    Color(0xFF0EA5E9),
    Color(0xFFA855F7),
    Color(0xFF64748B),
    Color(0xFF10B981),
  ];
}
