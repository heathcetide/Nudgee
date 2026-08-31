import 'package:flutter/material.dart';

/// A styled divider with optional label in the center.
class LingDivider extends StatelessWidget {
  final String? label;
  final double indent;
  final double endIndent;
  final double thickness;
  final Color? color;

  const LingDivider({
    super.key,
    this.label,
    this.indent = 16,
    this.endIndent = 16,
    this.thickness = 1,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dividerColor = color ?? theme.colorScheme.outlineVariant;

    if (label == null) {
      return Divider(
        indent: indent,
        endIndent: endIndent,
        thickness: thickness,
        color: dividerColor,
      );
    }

    return Row(
      children: [
        Expanded(
          child: Divider(indent: indent, thickness: thickness, color: dividerColor),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label!,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        Expanded(
          child: Divider(endIndent: endIndent, thickness: thickness, color: dividerColor),
        ),
      ],
    );
  }
}

/// A vertical divider.
class LingVerticalDivider extends StatelessWidget {
  final double indent;
  final double endIndent;
  final double thickness;
  final Color? color;

  const LingVerticalDivider({
    super.key,
    this.indent = 0,
    this.endIndent = 0,
    this.thickness = 1,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return VerticalDivider(
      indent: indent,
      endIndent: endIndent,
      thickness: thickness,
      color: color ?? theme.colorScheme.outlineVariant,
    );
  }
}
