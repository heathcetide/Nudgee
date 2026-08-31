import 'package:flutter/material.dart';

import 'package:nudgee/app/theme/app_colors.dart';
import 'package:nudgee/core/constants/app_constants.dart';
import 'package:nudgee/core/models/im/im.dart';

/// A user online-status indicator.
///
/// Renders a small dot with an optional text label.
/// - online: green
/// - offline: gray
/// - away: orange
/// - busy: red
/// - invisible: transparent with a border
class LingOnlineStatus extends StatelessWidget {
  /// The user status to display.
  final LingUserStatus status;

  /// Whether to show the status label next to the dot.
  final bool showLabel;

  /// Diameter of the status dot. Defaults to 8.
  final double size;

  const LingOnlineStatus({
    super.key,
    required this.status,
    this.showLabel = false,
    this.size = 8,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _color;
    final isTransparent = color == Colors.transparent;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: isTransparent
                ? Border.all(
                    color: theme.colorScheme.outline,
                    width: 1,
                  )
                : null,
          ),
        ),
        if (showLabel) ...[
          const SizedBox(width: AppConstants.spacingXs),
          Text(
            _label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  Color get _color {
    switch (status) {
      case LingUserStatus.online:
        return AppColors.success;
      case LingUserStatus.offline:
        return Colors.grey;
      case LingUserStatus.away:
        return AppColors.warning;
      case LingUserStatus.busy:
        return AppColors.error;
      case LingUserStatus.invisible:
        return Colors.transparent;
    }
  }

  String get _label {
    switch (status) {
      case LingUserStatus.online:
        return '在线';
      case LingUserStatus.offline:
        return '离线';
      case LingUserStatus.away:
        return '离开';
      case LingUserStatus.busy:
        return '忙碌';
      case LingUserStatus.invisible:
        return '隐身';
    }
  }
}
