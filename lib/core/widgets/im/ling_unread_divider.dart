import 'package:flutter/material.dart';

import 'package:nudgee/app/theme/app_colors.dart';
import 'package:nudgee/core/constants/app_constants.dart';

/// An "unread messages" divider for message lists.
///
/// Displays a centered "以下 N 条未读消息" label with horizontal lines on
/// both sides, on a lightly highlighted background.
class LingUnreadDivider extends StatelessWidget {
  /// Number of unread messages below this divider.
  final int count;

  const LingUnreadDivider({
    super.key,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      color: AppColors.error.withOpacity(0.05),
      padding: const EdgeInsets.symmetric(
        vertical: AppConstants.spacingXs + 2,
        horizontal: AppConstants.spacingLg,
      ),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              height: 1,
              color: AppColors.error.withOpacity(0.3),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spacingSm,
            ),
            child: Text(
              '以下 $count 条未读消息',
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.error,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Divider(
              height: 1,
              color: AppColors.error.withOpacity(0.3),
            ),
          ),
        ],
      ),
    );
  }
}
