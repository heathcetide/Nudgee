import 'package:flutter/material.dart';

/// A single list row with leading icon/avatar, title, subtitle, and trailing widget.
///
/// Follows Material 3 list item conventions with consistent spacing.
class LingListItem extends StatelessWidget {
  final Widget? leading;
  final IconData? leadingIcon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool enabled;
  final bool dense;
  final LingListItemVariant variant;

  const LingListItem({
    super.key,
    this.leading,
    this.leadingIcon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.enabled = true,
    this.dense = false,
    this.variant = LingListItemVariant.standard,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final leadingWidget = leading ??
        (leadingIcon != null
            ? Icon(leadingIcon, color: theme.colorScheme.onSurfaceVariant, size: 22)
            : null);

    return ListTile(
      leading: leadingWidget,
      title: Text(
        title,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: enabled ? null : theme.colorScheme.onSurfaceVariant,
          fontWeight: variant == LingListItemVariant.emphasized ? FontWeight.w600 : null,
        ),
      ),
      subtitle: subtitle != null
          ? Text(subtitle!, style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ))
          : null,
      trailing: trailing,
      onTap: enabled ? onTap : null,
      dense: dense,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}

/// A section header for grouping list items.
class LingListSection extends StatelessWidget {
  final String? title;
  final String? trailingText;
  final VoidCallback? onTrailingTap;
  final List<Widget> children;
  final bool showDivider;

  const LingListSection({
    super.key,
    this.title,
    this.trailingText,
    this.onTrailingTap,
    required this.children,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null || trailingText != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                if (title != null)
                  Expanded(
                    child: Text(
                      title!,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                if (trailingText != null)
                  GestureDetector(
                    onTap: onTrailingTap,
                    child: Text(
                      trailingText!,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 0),
          child: Column(
            children: [
              for (int i = 0; i < children.length; i++) ...[
                children[i],
                if (showDivider && i < children.length - 1)
                  const Divider(height: 1, indent: 16),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

enum LingListItemVariant { standard, emphasized }
