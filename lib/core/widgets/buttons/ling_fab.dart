import 'package:flutter/material.dart';

/// FAB size preset.
enum LingFabSize {
  small(40),
  regular(56),
  large(96);

  final double value;
  const LingFabSize(this.value);
}

/// A customizable floating action button.
///
/// Supports:
/// - Small, regular, and large sizes.
/// - Extended mode (icon + label).
/// - Gradient background.
/// - Custom elevation and shape.
class LingFab extends StatelessWidget {
  final IconData? icon;
  final String? label;
  final VoidCallback? onPressed;
  final LingFabSize size;
  final Color? color;
  final Gradient? gradient;
  final Color? foregroundColor;
  final double elevation;
  final ShapeBorder shape;
  final bool mini;
  final bool extended;
  final Widget? customIcon;
  final String? heroTag;

  const LingFab({
    super.key,
    this.icon,
    this.label,
    this.onPressed,
    this.size = LingFabSize.regular,
    this.color,
    this.gradient,
    this.foregroundColor,
    this.elevation = 6,
    this.shape = const CircleBorder(),
    this.mini = false,
    this.extended = false,
    this.customIcon,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = color ?? theme.colorScheme.primary;
    final fgColor = foregroundColor ?? theme.colorScheme.onPrimary;

    if (extended && label != null) {
      return FloatingActionButton.extended(
        onPressed: onPressed,
        heroTag: heroTag,
        icon: customIcon ?? (icon != null ? Icon(icon) : null),
        label: Text(label!),
        backgroundColor: bgColor,
        foregroundColor: fgColor,
        elevation: elevation,
        shape: shape is CircleBorder ? StadiumBorder() : shape,
      );
    }

    final fab = FloatingActionButton(
      onPressed: onPressed,
      heroTag: heroTag,
      backgroundColor: gradient != null ? Colors.transparent : bgColor,
      foregroundColor: fgColor,
      elevation: elevation,
      mini: mini,
      shape: shape,
      child: gradient != null
          ? Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(gradient: gradient, shape: BoxShape.circle),
              child: Center(child: customIcon ?? Icon(icon)),
            )
          : customIcon ?? Icon(icon),
    );

    if (size == LingFabSize.small || mini) {
      return SizedBox(width: LingFabSize.small.value, height: LingFabSize.small.value, child: fab);
    }
    if (size == LingFabSize.large) {
      return SizedBox(width: LingFabSize.large.value, height: LingFabSize.large.value, child: fab);
    }
    return fab;
  }
}
