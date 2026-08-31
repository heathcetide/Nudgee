import 'package:flutter/material.dart';

import 'package:nudgee/core/constants/app_constants.dart';
import 'package:nudgee/core/models/im/im.dart';

/// An in-bubble quote block showing a referenced message.
///
/// Displays a vertical accent bar, the original sender's name, and the
/// original message content (up to 3 lines). Tapping the block invokes
/// [onTap] to jump to the original message.
class LingMessageQuote extends StatelessWidget {
  /// The reply quote metadata.
  final LingReplyQuote quote;

  /// Display name of the original sender.
  final String authorName;

  /// Called when the quote block is tapped.
  final VoidCallback? onTap;

  const LingMessageQuote({
    super.key,
    required this.quote,
    required this.authorName,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacingSm,
          vertical: AppConstants.spacingXs + 2,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
          borderRadius: BorderRadius.circular(AppConstants.radiusSm),
        ),
        child: IntrinsicWidth(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Accent bar
              Container(
                width: 3,
                margin: const EdgeInsets.only(right: AppConstants.spacingSm),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Name + content
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      authorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      quote.preview,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
