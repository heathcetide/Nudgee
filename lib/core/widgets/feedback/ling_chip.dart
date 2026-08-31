import 'package:flutter/material.dart';

/// Chip variant.
enum LingChipVariant {
  filled,
  outlined,
  tonal,
}

/// A compact tag/chip element for labels, filters, and selections.
class LingChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final IconData? deleteIcon;
  final LingChipVariant variant;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final Color? color;

  const LingChip({
    super.key,
    required this.label,
    this.icon,
    this.deleteIcon,
    this.variant = LingChipVariant.filled,
    this.selected = false,
    this.onTap,
    this.onDelete,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chipColor = color ?? theme.colorScheme.primary;

    switch (variant) {
      case LingChipVariant.filled:
        return _buildChip(theme, chipColor, theme.colorScheme.onPrimary);
      case LingChipVariant.tonal:
        return _buildChip(theme, chipColor.withOpacity(0.12), chipColor);
      case LingChipVariant.outlined:
        return _buildOutlinedChip(theme, chipColor);
    }
  }

  Widget _buildChip(ThemeData theme, Color bg, Color fg) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 6),
            ],
            Text(label, style: theme.textTheme.labelMedium?.copyWith(color: fg)),
            if (onDelete != null) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onDelete,
                child: Icon(deleteIcon ?? Icons.close, size: 16, color: fg),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOutlinedChip(ThemeData theme, Color chipColor) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: chipColor, width: 1.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: chipColor),
              const SizedBox(width: 6),
            ],
            Text(label, style: theme.textTheme.labelMedium?.copyWith(color: chipColor)),
            if (onDelete != null) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onDelete,
                child: Icon(deleteIcon ?? Icons.close, size: 16, color: chipColor),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A wrap layout for displaying multiple chips.
class LingChipGroup extends StatelessWidget {
  final List<LingChip> chips;
  final double spacing;
  final double runSpacing;

  const LingChipGroup({
    super.key,
    required this.chips,
    this.spacing = 8,
    this.runSpacing = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: spacing,
      runSpacing: runSpacing,
      children: chips,
    );
  }
}
