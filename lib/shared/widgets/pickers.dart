import 'package:flutter/material.dart';

import '../../core/icons/icon_registry.dart';
import '../../core/theme/app_colors.dart';

/// Horizontal/wrapped swatch picker.
class ColorPicker extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onChanged;
  const ColorPicker({super.key, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final c in AppColors.palette)
          GestureDetector(
            onTap: () => onChanged(c.toARGB32()),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: c,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected == c.toARGB32()
                      ? Colors.white
                      : Colors.transparent,
                  width: 3,
                ),
                boxShadow: selected == c.toARGB32()
                    ? [
                        BoxShadow(
                          color: c.withValues(alpha: 0.6),
                          blurRadius: 10,
                          spreadRadius: 1,
                        )
                      ]
                    : null,
              ),
              child: selected == c.toARGB32()
                  ? const Icon(Icons.check, color: Colors.white, size: 20)
                  : null,
            ),
          ),
      ],
    );
  }
}

/// Grid of selectable icons (by string key).
class IconPicker extends StatelessWidget {
  final List<String> iconKeys;
  final String selected;
  final int color;
  final ValueChanged<String> onChanged;
  const IconPicker({
    super.key,
    required this.iconKeys,
    required this.selected,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tint = Color(color);
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final key in iconKeys)
          GestureDetector(
            onTap: () => onChanged(key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: selected == key
                    ? tint.withValues(alpha: 0.18)
                    : Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected == key ? tint : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Icon(AppIcons.of(key),
                  color: selected == key ? tint : null, size: 24),
            ),
          ),
      ],
    );
  }
}
