import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class FabAction {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const FabAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}

/// A speed-dial FAB. When opened it inserts a **full-screen** dimmed barrier via
/// an [OverlayEntry] (so the scrim covers the whole page, not just the FAB box)
/// and reveals labeled actions anchored bottom-right.
class ExpandingFab extends StatefulWidget {
  final List<FabAction> actions;
  const ExpandingFab({super.key, required this.actions});

  @override
  State<ExpandingFab> createState() => _ExpandingFabState();
}

class _ExpandingFabState extends State<ExpandingFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
  );
  OverlayEntry? _entry;

  bool get _open => _entry != null;

  void _toggle() => _open ? _close() : _openMenu();

  void _openMenu() {
    _entry = OverlayEntry(builder: _buildOverlay);
    Overlay.of(context).insert(_entry!);
    _ctrl.forward();
    setState(() {});
  }

  Future<void> _close() async {
    await _ctrl.reverse();
    _entry?.remove();
    _entry = null;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _entry?.remove();
    _ctrl.dispose();
    super.dispose();
  }

  Widget _buildOverlay(BuildContext context) {
    final media = MediaQuery.of(context);
    return Stack(
      children: [
        // Full-screen dimmed barrier.
        Positioned.fill(
          child: GestureDetector(
            onTap: _close,
            child: FadeTransition(
              opacity: _ctrl,
              child: Container(color: Colors.black.withValues(alpha: 0.45)),
            ),
          ),
        ),
        // Actions anchored bottom-right, just above the FAB.
        Positioned(
          right: 16,
          bottom: media.padding.bottom + 80,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < widget.actions.length; i++)
                _MiniAction(
                  action: widget.actions[i],
                  animation: CurvedAnimation(
                    parent: _ctrl,
                    curve: Interval(i / widget.actions.length, 1,
                        curve: Curves.easeOutBack),
                  ),
                  onTap: () {
                    _close();
                    widget.actions[i].onTap();
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      backgroundColor: AppColors.primary,
      onPressed: _toggle,
      child: AnimatedRotation(
        turns: _open ? 0.125 : 0,
        duration: const Duration(milliseconds: 240),
        child: Icon(_open ? Icons.close : Icons.add,
            size: 30, color: Colors.white),
      ),
    );
  }
}

class _MiniAction extends StatelessWidget {
  final FabAction action;
  final Animation<double> animation;
  final VoidCallback onTap;
  const _MiniAction(
      {required this.action, required this.animation, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: animation,
      alignment: Alignment.centerRight,
      child: FadeTransition(
        opacity: animation,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 8)
                  ],
                ),
                child: Text(action.label,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 12),
              FloatingActionButton.small(
                heroTag: action.label,
                backgroundColor: action.color,
                onPressed: onTap,
                child: Icon(action.icon, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
