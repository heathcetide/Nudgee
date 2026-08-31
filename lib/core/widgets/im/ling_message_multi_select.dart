import 'package:flutter/material.dart';

import 'package:nudgee/app/theme/app_colors.dart';
import 'package:nudgee/core/constants/app_constants.dart';

/// An action button shown in [LingMessageMultiSelect].
class LingMultiSelectAction {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  const LingMultiSelectAction({
    required this.label,
    required this.icon,
    this.onTap,
  });
}

/// A bottom action bar shown in multi-select mode.
///
/// Displays the number of selected messages and a row of action buttons
/// (forward, delete, favorite by default). Each button has an icon + label.
class LingMessageMultiSelect extends StatelessWidget {
  /// Number of currently selected messages.
  final int selectedCount;

  /// Actions to display. Defaults to forward / favorite / delete.
  final List<LingMultiSelectAction>? actions;

  /// Called when the close button is tapped (exits multi-select mode).
  final VoidCallback? onClose;

  const LingMessageMultiSelect({
    super.key,
    required this.selectedCount,
    this.actions,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = actions ??
        [
          const LingMultiSelectAction(label: '转发', icon: Icons.shortcut),
          const LingMultiSelectAction(label: '收藏', icon: Icons.star_outline),
          LingMultiSelectAction(
            label: '删除',
            icon: Icons.delete_outline,
            onTap: null,
          ),
        ];

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: theme.dividerColor,
              width: 0.5,
            ),
          ),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacingSm,
          vertical: AppConstants.spacingSm,
        ),
        child: Row(
          children: [
            // Close
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: onClose,
              tooltip: '退出多选',
            ),
            // Count
            Text(
              '已选 $selectedCount',
              style: theme.textTheme.titleSmall,
            ),
            const Spacer(),
            // Actions
            ...items.map((a) => _ActionButton(action: a)),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final LingMultiSelectAction action;

  const _ActionButton({required this.action});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDelete = action.label == '删除';
    final color = isDelete ? AppColors.error : theme.colorScheme.onSurface;

    return InkWell(
      onTap: action.onTap,
      borderRadius: BorderRadius.circular(AppConstants.radiusMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacingMd,
          vertical: AppConstants.spacingSm,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(action.icon, color: color, size: 22),
            const SizedBox(height: 2),
            Text(
              action.label,
              style: theme.textTheme.labelSmall?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
