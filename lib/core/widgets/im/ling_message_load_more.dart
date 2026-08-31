import 'package:flutter/material.dart';

import 'package:nudgee/core/constants/app_constants.dart';

/// A "load more" indicator shown at the top of a message list.
///
/// Two states:
/// - idle: shows "上拉加载更多"
/// - loading: shows a spinning circle + "加载中..."
class LingMessageLoadMore extends StatelessWidget {
  /// Whether the indicator is currently loading.
  final bool isLoading;

  /// Called when the user pulls up to request more messages.
  final VoidCallback onLoadMore;

  const LingMessageLoadMore({
    super.key,
    this.isLoading = false,
    required this.onLoadMore,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppConstants.spacingSm,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: AppConstants.spacingSm),
            Text(
              '加载中...',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: onLoadMore,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppConstants.spacingSm,
        ),
        child: Center(
          child: Text(
            '上拉加载更多',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
