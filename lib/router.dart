import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/analysis/analysis_screen.dart';
import 'features/categories/categories_screen.dart';
import 'features/home/home_screen.dart';
import 'features/pending/pending_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/shell/app_shell.dart';
import 'providers/nav_providers.dart';

/// Re-keys a screen by its tab index so a bottom-nav tap resets its state.
Widget _resettable(int tabIndex, Widget child) {
  return Consumer(
    builder: (context, ref, _) => KeyedSubtree(
      key: ValueKey(ref.watch(navResetProvider)[tabIndex]),
      child: child,
    ),
  );
}

final rootNavigatorKey = GlobalKey<NavigatorState>();

final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/home',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          AppShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => _resettable(0, const HomeScreen()),
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/pending',
            builder: (context, state) => _resettable(1, const PendingScreen()),
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/categories',
            builder: (context, state) =>
                _resettable(2, const CategoriesScreen()),
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/analysis',
            builder: (context, state) =>
                _resettable(3, const AnalysisScreen()),
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/settings',
            builder: (context, state) =>
                _resettable(4, const SettingsScreen()),
          ),
        ]),
      ],
    ),
  ],
);
