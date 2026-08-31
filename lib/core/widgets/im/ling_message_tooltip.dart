import 'package:flutter/material.dart';

import 'package:nudgee/app/theme/app_colors.dart';
import 'package:nudgee/core/constants/app_constants.dart';

/// An action that appears in [LingMessageTooltip].
class LingMessageTooltipAction {
  /// Unique key identifying this action.
  final String key;

  /// Display label.
  final String label;

  /// Icon for the action.
  final IconData icon;

  /// Icon/text color. Defaults to theme onSurface; use [AppColors.error]
  /// for destructive actions like delete.
  final Color? color;

  /// Callback when the action is tapped.
  final VoidCallback? onTap;

  const LingMessageTooltipAction({
    required this.key,
    required this.label,
    required this.icon,
    this.color,
    this.onTap,
  });

  // ── Built-in actions ────────────────────────────────────────────────────

  static LingMessageTooltipAction reply({VoidCallback? onTap}) =>
      LingMessageTooltipAction(
        key: 'reply',
        label: '回复',
        icon: Icons.reply,
        onTap: onTap,
      );

  static LingMessageTooltipAction copy({VoidCallback? onTap}) =>
      LingMessageTooltipAction(
        key: 'copy',
        label: '复制',
        icon: Icons.content_copy,
        onTap: onTap,
      );

  static LingMessageTooltipAction forward({VoidCallback? onTap}) =>
      LingMessageTooltipAction(
        key: 'forward',
        label: '转发',
        icon: Icons.shortcut,
        onTap: onTap,
      );

  static LingMessageTooltipAction multiSelect({VoidCallback? onTap}) =>
      LingMessageTooltipAction(
        key: 'multiSelect',
        label: '多选',
        icon: Icons.checklist,
        onTap: onTap,
      );

  static LingMessageTooltipAction recall({VoidCallback? onTap}) =>
      LingMessageTooltipAction(
        key: 'recall',
        label: '撤回',
        icon: Icons.undo,
        onTap: onTap,
      );

  static LingMessageTooltipAction delete({VoidCallback? onTap}) =>
      LingMessageTooltipAction(
        key: 'delete',
        label: '删除',
        icon: Icons.delete_outline,
        color: AppColors.error,
        onTap: onTap,
      );

  static LingMessageTooltipAction more({VoidCallback? onTap}) =>
      LingMessageTooltipAction(
        key: 'more',
        label: '更多',
        icon: Icons.more_horiz,
        onTap: onTap,
      );
}

/// Default set of actions shown when [actions] is not provided.
List<LingMessageTooltipAction> _defaultActions({
  bool canRecall = false,
  bool canDelete = true,
}) {
  return [
    LingMessageTooltipAction.reply(),
    LingMessageTooltipAction.copy(),
    LingMessageTooltipAction.forward(),
    LingMessageTooltipAction.multiSelect(),
    if (canRecall) LingMessageTooltipAction.recall(),
    if (canDelete) LingMessageTooltipAction.delete(),
    LingMessageTooltipAction.more(),
  ];
}

/// A long-press message action menu, presented as a modal bottom sheet.
///
/// Inspired by Tencent TUIKit's `TIMUIKitMessageTooltip`. Each action has an
/// icon, label, and optional color (destructive actions use red). Pass a
/// custom [actions] list or rely on the defaults.
class LingMessageTooltip extends StatelessWidget {
  /// Actions to display. When null, a default set is used.
  final List<LingMessageTooltipAction>? actions;

  /// Whether the recall action should appear in the default set.
  final bool canRecall;

  /// Whether the delete action should appear in the default set.
  final bool canDelete;

  const LingMessageTooltip({
    super.key,
    this.actions,
    this.canRecall = false,
    this.canDelete = true,
  });

  /// Show the tooltip as a modal bottom sheet.
  static Future<void> show(
    BuildContext context, {
    List<LingMessageTooltipAction>? actions,
    bool canRecall = false,
    bool canDelete = true,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppConstants.radiusXl),
        ),
      ),
      builder: (_) => LingMessageTooltip(
        actions: actions,
        canRecall: canRecall,
        canDelete: canDelete,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = actions ??
        _defaultActions(canRecall: canRecall, canDelete: canDelete);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppConstants.spacingSm,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppConstants.spacingMd),
              decoration: BoxDecoration(
                color: theme.colorScheme.outline.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spacingSm,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: 1,
                mainAxisSpacing: AppConstants.spacingSm,
                crossAxisSpacing: AppConstants.spacingSm,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final action = items[index];
                return _TooltipItem(
                  action: action,
                  onTap: () {
                    Navigator.of(context).pop();
                    action.onTap?.call();
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TooltipItem extends StatelessWidget {
  final LingMessageTooltipAction action;
  final VoidCallback onTap;

  const _TooltipItem({required this.action, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = action.color ?? theme.colorScheme.onSurface;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppConstants.radiusMd),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Icon(action.icon, color: color, size: 22),
          ),
          const SizedBox(height: 6),
          Text(
            action.label,
            style: theme.textTheme.labelSmall?.copyWith(color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
