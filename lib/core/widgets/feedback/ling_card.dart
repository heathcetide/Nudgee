import 'package:flutter/material.dart';

/// A styled card with optional title, subtitle, and trailing action.
class LingCard extends StatelessWidget {
  final Widget? child;
  final String? title;
  final String? subtitle;
  final Widget? trailing;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final VoidCallback? onTap;
  final Color? color;
  final double? elevation;
  final bool bordered;

  const LingCard({
    super.key,
    this.child,
    this.title,
    this.subtitle,
    this.trailing,
    this.padding,
    this.margin,
    this.onTap,
    this.color,
    this.elevation,
    this.bordered = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: color,
      elevation: elevation ?? 0,
      margin: margin ?? EdgeInsets.zero,
      shape: bordered
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            )
          : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: padding ?? const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title != null || trailing != null) ...[
                Row(
                  children: [
                    if (title != null)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title!, style: theme.textTheme.titleMedium),
                            if (subtitle != null)
                              Text(subtitle!, style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              )),
                          ],
                        ),
                      ),
                    if (trailing != null) trailing!,
                  ],
                ),
                if (child != null) ...[
                  const SizedBox(height: 12),
                  child!,
                ],
              ] else
                child ?? const SizedBox.shrink(),
            ],
          ),
        ),
      ),
    );
  }
}
