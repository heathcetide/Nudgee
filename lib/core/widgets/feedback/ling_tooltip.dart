import 'package:flutter/material.dart';

/// Tooltip variant.
enum LingTooltipVariant {
  dark,
  light,
  colored,
}

/// A styled tooltip that appears on long-press or tap.
///
/// More customizable than the built-in [Tooltip]:
/// - Supports dark, light, and colored variants.
/// - Supports custom icon and rich content.
/// - Configurable show duration and trigger mode.
class LingTooltip extends StatelessWidget {
  final String message;
  final Widget? child;
  final LingTooltipVariant variant;
  final Color? color;
  final IconData? icon;
  final double? width;
  final bool showOnTap;
  final Duration showDuration;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;

  const LingTooltip({
    super.key,
    required this.message,
    this.child,
    this.variant = LingTooltipVariant.dark,
    this.color,
    this.icon,
    this.width,
    this.showOnTap = false,
    this.showDuration = const Duration(seconds: 2),
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = _colors(theme);

    return Tooltip(
      message: message,
      triggerMode: showOnTap ? TooltipTriggerMode.tap : TooltipTriggerMode.longPress,
      showDuration: showDuration,
      textStyle: TextStyle(color: colors.foreground, fontSize: 12),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      preferBelow: true,
      child: child ?? Icon(icon ?? Icons.info_outline, size: 16, color: colors.background),
    );
  }

  _TooltipColors _colors(ThemeData theme) {
    switch (variant) {
      case LingTooltipVariant.dark:
        return _TooltipColors(background: Colors.grey[900]!, foreground: Colors.white);
      case LingTooltipVariant.light:
        return _TooltipColors(background: Colors.white, foreground: Colors.grey[900]!);
      case LingTooltipVariant.colored:
        return _TooltipColors(
          background: color ?? theme.colorScheme.primary,
          foreground: theme.colorScheme.onPrimary,
        );
    }
  }
}

class _TooltipColors {
  final Color background;
  final Color foreground;
  _TooltipColors({required this.background, required this.foreground});
}
