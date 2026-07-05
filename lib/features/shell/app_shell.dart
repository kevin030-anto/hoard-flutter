import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/analysis_providers.dart';
import '../../providers/derived_providers.dart';
import '../../providers/nav_providers.dart';

/// Persistent scaffold with the 5-tab animated bottom navigation bar.
class AppShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;
  const AppShell({super.key, required this.navigationShell});

  void _go(WidgetRef ref, int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
    // Reset the tapped page to its start state.
    ref.read(navResetProvider.notifier).bump(index);
    switch (index) {
      case 0:
        ref.invalidate(homeViewProvider);
        break;
      case 3:
        ref.invalidate(analysisStateProvider);
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: _BottomBar(
        currentIndex: navigationShell.currentIndex,
        onTap: (i) => _go(ref, i),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _BottomBar({required this.currentIndex, required this.onTap});

  static const _items = [
    (_NavSpec(Icons.home_rounded, Icons.home_outlined, 'Home')),
    (_NavSpec(Icons.assignment_rounded, Icons.assignment_outlined, 'Pending')),
    (_NavSpec(Icons.category_rounded, Icons.category_outlined, 'Categories')),
    (_NavSpec(Icons.bar_chart_rounded, Icons.bar_chart_outlined, 'Analysis')),
    (_NavSpec(Icons.settings_rounded, Icons.settings_outlined, 'Settings')),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (var i = 0; i < _items.length; i++)
                _NavButton(
                  spec: _items[i],
                  selected: i == currentIndex,
                  onTap: () => onTap(i),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavSpec {
  final IconData active;
  final IconData inactive;
  final String label;
  const _NavSpec(this.active, this.inactive, this.label);
}

class _NavButton extends StatelessWidget {
  final _NavSpec spec;
  final bool selected;
  final VoidCallback onTap;
  const _NavButton(
      {required this.spec, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? AppColors.primary
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45);
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              duration: const Duration(milliseconds: 220),
              scale: selected ? 1.15 : 1.0,
              child: Icon(selected ? spec.active : spec.inactive, color: color),
            ),
            const SizedBox(height: 3),
            Text(
              spec.label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
