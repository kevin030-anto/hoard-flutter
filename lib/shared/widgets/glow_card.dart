import 'package:flutter/material.dart';

/// A card with a soft colored glow — used on the Pending page to signal item
/// type (orange = to pay, red = to receive, blue = to-do, green = done).
class GlowCard extends StatelessWidget {
  final Color glow;
  final Widget child;
  final VoidCallback? onTap;

  const GlowCard({
    super.key,
    required this.glow,
    required this.child,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: glow.withValues(alpha: 0.55), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: glow.withValues(alpha: 0.28),
            blurRadius: 18,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(padding: const EdgeInsets.all(16), child: child),
        ),
      ),
    );
  }
}
