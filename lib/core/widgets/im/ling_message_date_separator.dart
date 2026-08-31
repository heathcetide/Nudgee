import 'package:flutter/material.dart';

import 'package:nudgee/core/constants/app_constants.dart';

/// A date separator for message lists.
///
/// Displays a centered date label with horizontal lines on both sides.
/// Smart formatting:
/// - Today → "今天"
/// - Yesterday → "昨天"
/// - This year → "MM月dd日"
/// - Previous years → "yyyy年MM月dd日"
class LingMessageDateSeparator extends StatelessWidget {
  /// The date to display.
  final DateTime date;

  const LingMessageDateSeparator({
    super.key,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppConstants.spacingSm,
        horizontal: AppConstants.spacingLg,
      ),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              height: 1,
              color: theme.dividerColor,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spacingSm,
            ),
            child: Text(
              _formatDate(date),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Divider(
              height: 1,
              color: theme.dividerColor,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(d.year, d.month, d.day);
    final diff = today.difference(target).inDays;

    if (diff == 0) return '今天';
    if (diff == 1) return '昨天';

    String two(int n) => n.toString().padLeft(2, '0');
    if (d.year == now.year) {
      return '${two(d.month)}月${two(d.day)}日';
    }
    return '${d.year}年${two(d.month)}月${two(d.day)}日';
  }
}
