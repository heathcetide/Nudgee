import 'package:flutter/material.dart';

import 'package:nudgee/core/constants/app_constants.dart';
import 'package:nudgee/core/models/im/im.dart';
import 'package:nudgee/core/widgets/feedback/ling_avatar.dart';

/// A reply-quote card shown above a message bubble or the input field.
///
/// Displays the original sender's avatar, name, and a single-line preview
/// of the original message content, plus an optional close button.
class LingMessageReply extends StatelessWidget {
  /// The reply quote metadata. When `null`, nothing is rendered.
  final LingReplyQuote? replyQuote;

  /// Display name of the original sender.
  final String authorName;

  /// Called when the close button is tapped.
  final VoidCallback? onClose;

  const LingMessageReply({
    super.key,
    required this.replyQuote,
    required this.authorName,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    if (replyQuote == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final quote = replyQuote!;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingMd,
        vertical: AppConstants.spacingSm,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.6),
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
      ),
      child: Row(
        children: [
          // Accent bar
          Container(
            width: 3,
            height: 32,
            margin: const EdgeInsets.only(right: AppConstants.spacingSm),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Avatar
          LingAvatar(
            name: authorName,
            size: LingAvatarSize.xs,
            showRing: false,
          ),
          const SizedBox(width: AppConstants.spacingSm),
          // Name + preview
          Expanded(
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
                Text(
                  quote.preview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          // Close button
          if (onClose != null)
            IconButton(
              icon: const Icon(Icons.close, size: 16),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 28,
                minHeight: 28,
              ),
              color: theme.colorScheme.onSurfaceVariant,
              onPressed: onClose,
            ),
        ],
      ),
    );
  }
}
