import 'package:flutter/material.dart';

/// A circular icon button commonly used in call controls (mute, camera, etc.).
///
/// Supports active/inactive states with color changes.
class LingIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final bool active;
  final double size;
  final Color? activeColor;
  final Color? inactiveColor;
  final Color? iconColor;
  final String? tooltip;

  const LingIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.active = false,
    this.size = 48,
    this.activeColor,
    this.inactiveColor,
    this.iconColor,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = active
        ? (activeColor ?? theme.colorScheme.primary)
        : (inactiveColor ?? theme.colorScheme.surfaceContainerHighest);
    final fgColor = iconColor ?? (active ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface);

    final button = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: fgColor, size: size * 0.45),
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        constraints: BoxConstraints.tightFor(width: size, height: size),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}
