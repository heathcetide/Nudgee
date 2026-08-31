import 'package:flutter/material.dart';

/// Button variant enum.
enum LingButtonVariant {
  filled,
  outlined,
  text,
  tonal,
}

/// Button size enum.
enum LingButtonSize {
  small,
  medium,
  large,
}

/// A unified button component with consistent styling across the app.
///
/// Replaces [ElevatedButton], [OutlinedButton], [TextButton], and
/// [FilledButton] with a single API.
class LingButton extends StatelessWidget {
  final String? label;
  final Widget? child;
  final IconData? icon;
  final IconData? trailingIcon;
  final VoidCallback? onPressed;
  final LingButtonVariant variant;
  final LingButtonSize size;
  final bool loading;
  final bool expanded;
  final Color? foregroundColor;
  final Color? backgroundColor;

  const LingButton({
    super.key,
    this.label,
    this.child,
    this.icon,
    this.trailingIcon,
    this.onPressed,
    this.variant = LingButtonVariant.filled,
    this.size = LingButtonSize.medium,
    this.loading = false,
    this.expanded = false,
    this.foregroundColor,
    this.backgroundColor,
  }) : assert(label != null || child != null, 'Either label or child must be provided');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDisabled = onPressed == null && !loading;

    Widget content = child ??
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null && !loading) ...[
              Icon(icon, size: _iconSize),
              const SizedBox(width: 8),
            ],
            if (loading)
              SizedBox(
                width: _iconSize,
                height: _iconSize,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _foregroundColor(theme),
                ),
              )
            else
              Text(label!, style: _textStyle(theme)),
            if (trailingIcon != null && !loading) ...[
              const SizedBox(width: 8),
              Icon(trailingIcon, size: _iconSize),
            ],
          ],
        );

    if (expanded) {
      content = Center(child: content);
    }

    final onPressedCallback = loading || isDisabled ? null : onPressed;

    switch (variant) {
      case LingButtonVariant.filled:
        return FilledButton(
          onPressed: onPressedCallback,
          style: _filledStyle(theme),
          child: content,
        );
      case LingButtonVariant.tonal:
        return FilledButton.tonal(
          onPressed: onPressedCallback,
          style: _tonalStyle(theme),
          child: content,
        );
      case LingButtonVariant.outlined:
        return OutlinedButton(
          onPressed: onPressedCallback,
          style: _outlinedStyle(theme),
          child: content,
        );
      case LingButtonVariant.text:
        return TextButton(
          onPressed: onPressedCallback,
          style: _textButtonStyle(theme),
          child: content,
        );
    }
  }

  // ── Styles ───────────────────────────────────────────────────────────

  ButtonStyle _filledStyle(ThemeData theme) => FilledButton.styleFrom(
        minimumSize: _minimumSize,
        padding: _padding,
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
      );

  ButtonStyle _tonalStyle(ThemeData theme) => FilledButton.styleFrom(
        minimumSize: _minimumSize,
        padding: _padding,
        foregroundColor: foregroundColor,
      );

  ButtonStyle _outlinedStyle(ThemeData theme) => OutlinedButton.styleFrom(
        minimumSize: _minimumSize,
        padding: _padding,
        foregroundColor: foregroundColor ?? theme.colorScheme.primary,
      );

  ButtonStyle _textButtonStyle(ThemeData theme) => TextButton.styleFrom(
        minimumSize: _minimumSize,
        padding: _padding,
        foregroundColor: foregroundColor ?? theme.colorScheme.primary,
      );

  // ── Size helpers ─────────────────────────────────────────────────────

  Size get _minimumSize {
    switch (size) {
      case LingButtonSize.small:
        return const Size(64, 32);
      case LingButtonSize.medium:
        return const Size(72, 44);
      case LingButtonSize.large:
        return const Size(88, 52);
    }
  }

  EdgeInsetsGeometry get _padding {
    switch (size) {
      case LingButtonSize.small:
        return const EdgeInsets.symmetric(horizontal: 12, vertical: 6);
      case LingButtonSize.medium:
        return const EdgeInsets.symmetric(horizontal: 20, vertical: 12);
      case LingButtonSize.large:
        return const EdgeInsets.symmetric(horizontal: 28, vertical: 16);
    }
  }

  double get _iconSize {
    switch (size) {
      case LingButtonSize.small:
        return 16;
      case LingButtonSize.medium:
        return 20;
      case LingButtonSize.large:
        return 24;
    }
  }

  TextStyle _textStyle(ThemeData theme) {
    switch (size) {
      case LingButtonSize.small:
        return theme.textTheme.labelMedium ?? const TextStyle();
      case LingButtonSize.medium:
        return theme.textTheme.labelLarge ?? const TextStyle();
      case LingButtonSize.large:
        return theme.textTheme.titleMedium ?? const TextStyle();
    }
  }

  Color _foregroundColor(ThemeData theme) =>
      foregroundColor ?? (variant == LingButtonVariant.filled ? theme.colorScheme.onPrimary : theme.colorScheme.primary);
}
