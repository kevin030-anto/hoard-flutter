import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Per-tab reset tokens. Bumping a tab's token re-keys its screen so local
/// widget state (scroll position, expanded rows, inner tab) rebuilds fresh.
final navResetProvider =
    NotifierProvider<NavResetNotifier, List<int>>(NavResetNotifier.new);

class NavResetNotifier extends Notifier<List<int>> {
  @override
  List<int> build() => List.filled(5, 0);

  void bump(int index) {
    final next = [...state];
    next[index]++;
    state = next;
  }
}
