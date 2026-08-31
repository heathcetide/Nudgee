import 'package:flutter/material.dart';

import 'package:nudgee/core/constants/app_constants.dart';

/// A banner shown above the input field when editing a sent message.
///
/// Displays a vertical accent bar on the left, an "编辑中" label, a preview
/// of the original message text, and a cancel button on the right. The
/// background uses `theme.colorScheme.primary` at 5% opacity.
class LingMessageEdit extends StatelessWidget {
  /// The original message text being edited.
  final String originalText;

  /// Called when the cancel button is tapped.
  final VoidCallback onCancel;

  /// Label shown next to the accent bar. Defaults to "编辑中".
  final String label;

  const LingMessageEdit({
    super.key,
    required this.originalText,
    required this.onCancel,
    this.label = '编辑中',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.05),
        border: Border(
          top: BorderSide(color: theme.dividerColor, width: 0.5),
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingMd,
        vertical: AppConstants.spacingSm,
      ),
      child: Row(
        children: [
          // Left accent bar
          Container(
            width: 3,
            height: 28,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: AppConstants.spacingSm),
          // Label + preview
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  originalText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          // Cancel button
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: onCancel,
            tooltip: '取消编辑',
            color: theme.colorScheme.onSurfaceVariant,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
