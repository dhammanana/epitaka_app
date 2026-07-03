import 'package:flutter/material.dart';

/// A circular color swatch that indicates selection with a white border, a
/// check icon, and a subtle glow.
///
/// [size] controls the diameter (default 40). [iconSize] controls the check
/// icon when selected. [glowRadius] controls the shadow spread.
class ColorSwatch extends StatelessWidget {
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;
  final double size;
  final double iconSize;
  final double glowRadius;

  const ColorSwatch({
    super.key,
    required this.color,
    required this.isSelected,
    required this.onTap,
    this.size = 40,
    this.iconSize = 16,
    this.glowRadius = 6,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color:
                  isSelected ? color.withValues(alpha: 0.4) : Colors.transparent,
              blurRadius: glowRadius,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: isSelected
            ? Icon(Icons.check, color: Colors.white, size: iconSize)
            : null,
      ),
    );
  }
}
