import 'package:flutter/material.dart';

import '../../core/icons/icon_registry.dart';

/// Rounded tile showing a category/account icon tinted by its color.
class IconAvatar extends StatelessWidget {
  final String iconKey;
  final int colorValue;
  final double size;

  const IconAvatar({
    super.key,
    required this.iconKey,
    required this.colorValue,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color(colorValue);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(AppIcons.of(iconKey), color: color, size: size * 0.5),
    );
  }
}
