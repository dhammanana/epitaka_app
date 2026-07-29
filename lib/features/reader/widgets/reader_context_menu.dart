// lib/features/reader/widgets/reader_context_menu.dart
//
// Reusable context menu button widget. The full context menu toolbar is
// built by [ReaderCopyService.buildContextMenu] in the service layer.

import 'package:flutter/material.dart';

/// Button used inside the custom copy context menu.
/// Shows a hover highlight and a ripple effect on tap.
class ContextMenuButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final ColorScheme colors;

  const ContextMenuButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    required this.colors,
  });

  @override
  State<ContextMenuButton> createState() => _ContextMenuButtonState();
}

class _ContextMenuButtonState extends State<ContextMenuButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final bgColor = _isPressed
        ? widget.colors.primary.withValues(alpha: 0.2)
        : _isHovered
            ? widget.colors.surfaceContainerHighest
            : Colors.transparent;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() {
        _isHovered = false;
        _isPressed = false;
      }),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: () {
          widget.onTap();
          Future.delayed(const Duration(milliseconds: 150), () {
            if (mounted) setState(() => _isPressed = false);
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.icon,
                  size: 16,
                  color: _isHovered
                      ? widget.colors.primary
                      : widget.colors.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 13,
                    color: _isHovered
                        ? widget.colors.onSurface
                        : widget.colors.onSurfaceVariant,
                    fontWeight: _isHovered ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
